-- #1. high level metrics - cache and index ratio

-- The first thing you're going to want to look at is your cache hit ratio and index hit ratio. Your cache hit ratio is going to give the percentage of time your data is served 
-- from within memory vs. having to go to disk. Generally serving data from memory vs. disk is going to orders of magnitude faster, thus the more you can serve from memory the better. 
-- For a typical web application making a lot of short requests I'm going to target > 99% here. 

SELECT
  'index hit rate' AS name,
  (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read),0) AS ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT
 'table hit rate' AS name,
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read),0) AS ratio
FROM pg_statio_user_tables;


-- If the above results is something like 80% or 90%, the solution is simple: get your database more memory by upgrading to the next step up. 

-- #2 . Look at the indexes and how often they're used.
SELECT relname,
   CASE idx_scan
     WHEN 0 THEN 'Insufficient data'
     ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
   END percent_of_times_index_used,
   n_live_tup rows_in_table
 FROM
   pg_stat_user_tables
 ORDER BY
   n_live_tup DESC;


-- #3. Cleaning up unused indexes

SELECT
  schemaname || '.' || relname AS table,
  indexrelname AS index,
  pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
  idx_scan as index_scans
FROM pg_stat_user_indexes ui
JOIN pg_index i ON ui.indexrelid = i.indexrelid
WHERE NOT indisunique AND idx_scan < 50 AND pg_relation_size(relid) > 5 * 8192
ORDER BY pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) DESC NULLS FIRST,
pg_relation_size(i.indexrelid) DESC;


-- OR

SELECT
    relname,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelname::regclass)) as size
FROM
    pg_stat_all_indexes
WHERE
    schemaname = 'public'
    AND indexrelname NOT LIKE 'pg_toast_%'
    AND idx_scan = 0
    AND idx_tup_read = 0
    AND idx_tup_fetch = 0
ORDER BY
    pg_relation_size(indexrelname::regclass) DESC;




-- #4. reset stats of a table

-- Find table oid by name
SELECT oid FROM pg_class c WHERE relname = 'table_name';
-- Reset counts for all indexes of table
SELECT pg_stat_reset_single_table_counters(14662536);


-- #5. To clear BLOAT 

REINDEX INDEX index_name;  -- locks index while rebuilding

REINDEX INDEX CONCURRENTLY index_name; -- doesn't lock    


-- #6. VACCUM, but locks 

VACUUM FULL table_name;

-- Rebuilding tables are not ideal unless you can afford downtime. 
-- One popular solution for rebuilding tables and indexes without downtime is the pg_repack extension.

CREATE EXTENSION pg_repack;

-- To "repack" a table along with its indexes, issue the following command from the console:

$ pg_repack -k --table table_name db_name

-- #7. Partial Indexes

-- Find indexed columns with high NULL_FRAC for Partial Indexes

SELECT
    c.oid,
    c.relname AS index,
    pg_size_pretty(pg_relation_size(c.oid)) AS index_size,
    i.indisunique AS unique,
    a.attname AS indexed_column,
    CASE s.null_frac
        WHEN 0 THEN ''
        ELSE to_char(s.null_frac * 100, '999.00%')
    END AS null_frac,
    pg_size_pretty((pg_relation_size(c.oid) * s.null_frac)::bigint) AS expected_saving
    -- Uncomment to include the index definition
    --, ixs.indexdef

FROM
    pg_class c
    JOIN pg_index i ON i.indexrelid = c.oid
    JOIN pg_attribute a ON a.attrelid = c.oid
    JOIN pg_class c_table ON c_table.oid = i.indrelid
    JOIN pg_indexes ixs ON c.relname = ixs.indexname
    LEFT JOIN pg_stats s ON s.tablename = c_table.relname AND a.attname = s.attname

WHERE
    -- Primary key cannot be partial
    NOT i.indisprimary

    -- Exclude already partial indexes
    AND i.indpred IS NULL

    -- Exclude composite indexes
    AND array_length(i.indkey, 1) = 1

    -- Larger than 10MB
    AND pg_relation_size(c.oid) > 10 * 1024 ^ 2

ORDER BY
    pg_relation_size(c.oid) * s.null_frac DESC;



CREATE INDEX transaction_cancelled_by_part_ix ON transactions(cancelled_by_user_id)
WHERE cancelled_by_user_id IS NOT NULL;






-- Finally, Dig into query performance with pg_stat_statements Ex:

SELECT 
  (total_time / 1000 / 60) as total_minutes, 
  (total_time/calls) as average_time, 
  query 
FROM pg_stat_statements 
ORDER BY 1 DESC 
LIMIT 50;