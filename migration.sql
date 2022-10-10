--Check the sequences

WITH fq_objects AS (SELECT c.oid,n.nspname || '.' ||c.relname AS fqname ,
                           c.relkind, c.relname AS relation
                    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ),

     sequences AS (SELECT oid,fqname FROM fq_objects WHERE relkind = 'S'),
     tables    AS (SELECT oid, fqname FROM fq_objects WHERE relkind = 'r' )
SELECT
       s.fqname AS sequence,
       '->' as depends,
       t.fqname AS table,
       a.attname AS column
FROM
     pg_depend d JOIN sequences s ON s.oid = d.objid
                 JOIN tables t ON t.oid = d.refobjid
                 JOIN pg_attribute a ON a.attrelid = d.refobjid and a.attnum = d.refobjsubid
WHERE
     d.deptype = 'a' ;
     
     
 -- Enable Triggers for all tables
 
 select c.relname, format('alter table %I %s trigger all;', relname, 'enable') from pg_namespace n
join pg_class c on c.relnamespace = n.oid and c.relhastriggers = true
where n.nspname = 'public';
