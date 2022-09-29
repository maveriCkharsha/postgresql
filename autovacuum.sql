WITH rel_set AS
(
    SELECT
        oid,
        CASE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)::BIGINT
        END AS rel_av_vac_threshold,
        CASE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_scale_factor=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_scale_factor=', 2), ',', 1)::NUMERIC
        END AS rel_av_vac_scale_factor
    FROM pg_class
) 
SELECT
    PSUT.relname,
    to_char(PSUT.last_vacuum, 'YYYY-MM-DD HH24:MI')     AS last_vacuum,
    to_char(PSUT.last_autovacuum, 'YYYY-MM-DD HH24:MI') AS last_autovacuum,
    to_char(C.reltuples, '9G999G999G999')               AS n_tup,
    to_char(PSUT.n_dead_tup, '9G999G999G999')           AS dead_tup,
    to_char(coalesce(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + coalesce(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples, '9G999G999G999') AS av_threshold,
    CASE
        WHEN (coalesce(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + coalesce(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples) < PSUT.n_dead_tup
        THEN '*'
    ELSE ''
    END AS expect_av
FROM
    pg_stat_user_tables PSUT
    JOIN pg_class C
        ON PSUT.relid = C.oid
    JOIN rel_set RS
        ON PSUT.relid = RS.oid
ORDER BY C.reltuples DESC;
