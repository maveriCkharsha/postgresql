SELECT schemaname || '.' || relname as tblnam,
    n_dead_tup,
    (n_dead_tup::float / n_live_tup::float) * 100 as pfrag
FROM pg_stat_user_tables
WHERE schemaname = 'public' and n_dead_tup > 0 and n_live_tup > 0 order by pfrag desc;

-- Method1
WITH constants AS (
  SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 4 AS ma
), bloat_info AS (
  SELECT
    ma,bs,schemaname,tablename,
    (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
    (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
  FROM (
    SELECT
      schemaname, tablename, hdr, ma, bs,
      SUM((1-null_frac)*avg_width) AS datawidth,
      MAX(null_frac) AS maxfracsum,
      hdr+(
        SELECT 1+count(*)/8
        FROM pg_stats s2
        WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
      ) AS nullhdr
    FROM pg_stats s, constants
    GROUP BY 1,2,3,4,5
  ) AS foo
), table_bloat AS (
  SELECT
    schemaname, tablename, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta
  FROM bloat_info
  JOIN pg_class cc ON cc.relname = bloat_info.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = bloat_info.schemaname AND nn.nspname <> 'information_schema'
), index_bloat AS (
  SELECT
    schemaname, tablename, bs,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM bloat_info
  JOIN pg_class cc ON cc.relname = bloat_info.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = bloat_info.schemaname AND nn.nspname <> 'information_schema'
  JOIN pg_index i ON indrelid = cc.oid
  JOIN pg_class c2 ON c2.oid = i.indexrelid
)
SELECT
  type, schemaname, object_name, bloat, pg_size_pretty(raw_waste) as waste
FROM
(SELECT
  'table' as type,
  schemaname,
  tablename as object_name,
  ROUND(CASE WHEN otta=0 THEN 0.0 ELSE table_bloat.relpages/otta::numeric END,1) AS bloat,
  CASE WHEN relpages < otta THEN '0' ELSE (bs*(table_bloat.relpages-otta)::bigint)::bigint END AS raw_waste
FROM
  table_bloat
    UNION
SELECT
  'index' as type,
  schemaname,
  tablename || '::' || iname as object_name,
  ROUND(CASE WHEN iotta=0 OR ipages=0 THEN 0.0 ELSE ipages/iotta::numeric END,1) AS bloat,
  CASE WHEN ipages < iotta THEN '0' ELSE (bs*(ipages-iotta))::bigint END AS raw_waste
FROM
  index_bloat) bloat_summary
ORDER BY raw_waste DESC, bloat DESC;

--Method2
-- new table bloat query
-- still needs work; is often off by +/- 20%
WITH constants AS (
    -- define some constants for sizes of things
    -- for reference down the query and easy maintenance
    SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 8 AS ma
),
no_stats AS (
    -- screen out table who have attributes
    -- which dont have stats, such as JSON
    SELECT table_schema, table_name, 
        n_live_tup::numeric as est_rows,
        pg_table_size(relid)::numeric as table_size
    FROM information_schema.columns
        JOIN pg_stat_user_tables as psut
           ON table_schema = psut.schemaname
           AND table_name = psut.relname
        LEFT OUTER JOIN pg_stats
        ON table_schema = pg_stats.schemaname
            AND table_name = pg_stats.tablename
            AND column_name = attname 
    WHERE attname IS NULL
        AND table_schema NOT IN ('pg_catalog', 'information_schema')
    GROUP BY table_schema, table_name, relid, n_live_tup
),
null_headers AS (
    -- calculate null header sizes
    -- omitting tables which dont have complete stats
    -- and attributes which aren't visible
    SELECT
        hdr+1+(sum(case when null_frac <> 0 THEN 1 else 0 END)/8) as nullhdr,
        SUM((1-null_frac)*avg_width) as datawidth,
        MAX(null_frac) as maxfracsum,
        schemaname,
        tablename,
        hdr, ma, bs
    FROM pg_stats CROSS JOIN constants
        LEFT OUTER JOIN no_stats
            ON schemaname = no_stats.table_schema
            AND tablename = no_stats.table_name
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        AND no_stats.table_name IS NULL
        AND EXISTS ( SELECT 1
            FROM information_schema.columns
                WHERE schemaname = columns.table_schema
                    AND tablename = columns.table_name )
    GROUP BY schemaname, tablename, hdr, ma, bs
),
data_headers AS (
    -- estimate header and row size
    SELECT
        ma, bs, hdr, schemaname, tablename,
        (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
        (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM null_headers
),
table_estimates AS (
    -- make estimates of how large the table should be
    -- based on row and page size
    SELECT schemaname, tablename, bs,
        reltuples::numeric as est_rows, relpages * bs as table_bytes,
    CEIL((reltuples*
            (datahdr + nullhdr2 + 4 + ma -
                (CASE WHEN datahdr%ma=0
                    THEN ma ELSE datahdr%ma END)
                )/(bs-20))) * bs AS expected_bytes,
        reltoastrelid
    FROM data_headers
        JOIN pg_class ON tablename = relname
        JOIN pg_namespace ON relnamespace = pg_namespace.oid
            AND schemaname = nspname
    WHERE pg_class.relkind = 'r'
),
estimates_with_toast AS (
    -- add in estimated TOAST table sizes
    -- estimate based on 4 toast tuples per page because we dont have 
    -- anything better.  also append the no_data tables
    SELECT schemaname, tablename, 
        TRUE as can_estimate,
        est_rows,
        table_bytes + ( coalesce(toast.relpages, 0) * bs ) as table_bytes,
        expected_bytes + ( ceil( coalesce(toast.reltuples, 0) / 4 ) * bs ) as expected_bytes
    FROM table_estimates LEFT OUTER JOIN pg_class as toast
        ON table_estimates.reltoastrelid = toast.oid
            AND toast.relkind = 't'
),
table_estimates_plus AS (
-- add some extra metadata to the table data
-- and calculations to be reused
-- including whether we cant estimate it
-- or whether we think it might be compressed
    SELECT current_database() as databasename,
            schemaname, tablename, can_estimate, 
            est_rows,
            CASE WHEN table_bytes > 0
                THEN table_bytes::NUMERIC
                ELSE NULL::NUMERIC END
                AS table_bytes,
            CASE WHEN expected_bytes > 0 
                THEN expected_bytes::NUMERIC
                ELSE NULL::NUMERIC END
                    AS expected_bytes,
            CASE WHEN expected_bytes > 0 AND table_bytes > 0
                AND expected_bytes <= table_bytes
                THEN (table_bytes - expected_bytes)::NUMERIC
                ELSE 0::NUMERIC END AS bloat_bytes
    FROM estimates_with_toast
    UNION ALL
    SELECT current_database() as databasename, 
        table_schema, table_name, FALSE, 
        est_rows, table_size,
        NULL::NUMERIC, NULL::NUMERIC
    FROM no_stats
),
bloat_data AS (
    -- do final math calculations and formatting
    select current_database() as databasename,
        schemaname, tablename, can_estimate, 
        table_bytes, round(table_bytes/(1024^2)::NUMERIC,3) as table_mb,
        expected_bytes, round(expected_bytes/(1024^2)::NUMERIC,3) as expected_mb,
        round(bloat_bytes*100/table_bytes) as pct_bloat,
        round(bloat_bytes/(1024::NUMERIC^2),2) as mb_bloat,
        table_bytes, expected_bytes, est_rows
    FROM table_estimates_plus
)
-- filter output for bloated tables
SELECT databasename, schemaname, tablename,
    can_estimate,
    est_rows,
    pct_bloat, mb_bloat,
    table_mb
FROM bloat_data
-- this where clause defines which tables actually appear
-- in the bloat chart
-- example below filters for tables which are either 50%
-- bloated and more than 20mb in size, or more than 25%
-- bloated and more than 4GB in size
WHERE ( pct_bloat >= 50 AND mb_bloat >= 10 )
    OR ( pct_bloat >= 25 AND mb_bloat >= 1000 )
ORDER BY mb_bloat DESC;

--Method 3
SELECT current_database()                      AS current_db,
       schemaname                              AS schema_name,
       tblname                                 AS table_name,
       (bs * tblpages) / 1024                  AS actual_table_size_kb,
       ((tblpages - est_tblpages) * bs) / 1024 AS wasted_space_kb,
       CASE
           WHEN tblpages > 0 AND tblpages - est_tblpages > 0 THEN 100 * (tblpages - est_tblpages) / tblpages::float
           ELSE 0
           END                                 AS wasted_space_percent,
       fillfactor                              AS table_fill_factor,
       CASE
           WHEN tblpages - est_tblpages_ff > 0 THEN (tblpages - est_tblpages_ff) * bs / 1024
           ELSE 0
           END                                 AS bloat_size_kb,
       CASE
           WHEN tblpages > 0 AND tblpages - est_tblpages_ff > 0 THEN 100 * (tblpages - est_tblpages_ff) / tblpages::float
           ELSE 0
           END                                 AS bloat_size_percent,
       is_na                                   AS has_non_atomic_data_types
FROM (SELECT ceil(reltuples / ((bs - page_hdr) / tpl_size)) + ceil(toasttuples / 4)                      AS est_tblpages,
             ceil(reltuples / ((bs - page_hdr) * fillfactor / (tpl_size * 100))) +
             ceil(toasttuples / 4)                                                                       AS est_tblpages_ff,
             tblpages,
             fillfactor,
             bs,
             schemaname,
             tblname,
             is_na
      FROM (SELECT (4 + tpl_hdr_size + tpl_data_size + (2 * ma)
          - CASE
                WHEN tpl_hdr_size % ma = 0 THEN ma
                ELSE tpl_hdr_size % ma
                        END
          - CASE
                WHEN ceil(tpl_data_size)::int % ma = 0 THEN ma
                ELSE ceil(tpl_data_size)::int % ma
                        END
                       )                    AS tpl_size,
                   (heappages + toastpages) AS tblpages,
                   heappages,
                   toastpages,
                   reltuples,
                   toasttuples,
                   bs,
                   page_hdr,
                   schemaname,
                   tblname,
                   fillfactor,
                   is_na
            FROM (SELECT ns.nspname                                                                 AS schemaname,
                         tbl.relname                                                                AS tblname,
                         tbl.reltuples,
                         tbl.relpages                                                               AS heappages,
                         coalesce(toast.relpages, 0)                                                AS toastpages,
                         coalesce(toast.reltuples, 0)                                               AS toasttuples,
                         coalesce(substring(array_to_string(tbl.reloptions, ' ') FROM 'fillfactor=([0-9]+)')::smallint,
                                  100)                                                              AS fillfactor,
                         current_setting('block_size')::numeric                                     AS bs,
                         CASE
                             WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
                             ELSE 4
                             END                                                                    AS ma,
                         24                                                                         AS page_hdr,
                         23 + CASE
                                  WHEN MAX(coalesce(s.null_frac, 0)) > 0 THEN (7 + count(s.attname)) / 8
                                  ELSE 0::int
                             END
                             + CASE
                                   WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4
                                   ELSE 0
                             END                                                                    AS tpl_hdr_size,
                         sum((1 - coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0))             AS tpl_data_size,
                         bool_or(att.atttypid = 'pg_catalog.name'::regtype)
                             OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
                  FROM pg_attribute AS att
                           JOIN pg_class AS tbl ON att.attrelid = tbl.oid
                           JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
                           LEFT JOIN pg_stats AS s ON s.schemaname = ns.nspname
                      AND s.tablename = tbl.relname AND s.inherited = false AND s.attname = att.attname
                           LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
                  WHERE NOT att.attisdropped
                    AND tbl.relkind in ('r', 'm')
                  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
                  ORDER BY 2, 3) AS subquery1) AS subquery2) AS subquery3
WHERE schemaname = 'public'
ORDER BY schema_name, table_name;
