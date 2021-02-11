-- #1. USE PL/PGSQL FUNCTIONS FOR SIMPLE SQL STATEMENTS

1- CREATE OR REPLACE FUNCTION hemisphere_sql (character varying)
    RETURNS character varying     LANGUAGE sql 
    AS $$
    SELECT
        CASE WHEN $1 IN ('UK', 'Germany', 'Japan', 'US', 'China', 'Canada', 'Russia', 'France') THEN
            'North'
        WHEN $1 IN ('South Africa', 'Australia', 'Chile') THEN
            'South'
        ELSE
            'unknown'
        END
$$;

2- CREATE OR REPLACE FUNCTION hemisphere_plpgsql (character varying)
    RETURNS character varying   LANGUAGE plpgsql
    AS $$
DECLARE
    result character varying;
BEGIN
    result:= (
        SELECT
            CASE WHEN $1 IN ('UK', 'Germany', 'Japan', 'US', 'China', 'Canada', 'Russia', 'France') THEN
                'North'
            WHEN $1 IN ('South Africa', 'Australia', 'Chile') THEN
                'South'
            ELSE
                'unknown'
            END);
    RETURN result;
END;
$$;

1- EXPLAIN (ANALYZE,VERBOSE ) SELECT hemisphere_sql(country) FROM customers;

Seq Scan on public.customers  (cost=0.00..963.00 rows=20000 width=32) (actual time=0.039..29.309 rows=20000 loops=1)
   Output: CASE WHEN ((country)::text = ANY ('{UK,Germany,Japan,US,China,Canada,Russia,France}'::text[])) THEN 'North'::text WHEN ((country)::text = ANY ('{"South Africa",Australia,Chile}'::text[])) THEN 'South'::text ELSE 'unknown'::text END
 Planning Time: 0.458 ms
 Execution Time: 32.306 ms

2-EXPLAIN (ANALYZE,VERBOSE ) SELECT hemisphere_plpgsql(country) FROM customers;

 Seq Scan on public.customers  (cost=0.00..5688.00 rows=20000 width=32) (actual time=0.654..174.685 rows=20000 loops=1)
   Output: hemisphere_plpgsql(country)
 Planning Time: 0.082 ms
 Execution Time: 175.972 ms 



-- #2. UNNECESSARY USAGE OF SELECT INTO CLAUSE

1- CREATE OR REPLACE FUNCTION simple ()  RETURNS void
    AS $$
DECLARE
    s int DEFAULT 0;
BEGIN
    FOR i IN 1..10000 LOOP
        s := s + 1;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

2- CREATE OR REPLACE FUNCTION using_select ()  RETURNS void
    AS $$
DECLARE
    s int DEFAULT 0;
BEGIN
    FOR i IN 1..10000 LOOP
        SELECT s + 1 INTO s;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

1-SELECT simple();
 Time: 16.980 ms
2-SELECT using_select();
Time: 86.931 ms


-- #3. OVERUSING THE HIGH-LEVEL PROGRAMMING CODING STYLE FOR SQL ACTIVITIES


1- CREATE OR REPLACE  FUNCTION oldest_orders_by_customer (int) RETURNS SETOF t_oldest_orders_by_customer  AS $$
 DECLARE
    c customers;
    result record;
 BEGIN 
	 FOR c IN SELECT * FROM customers c2 WHERE age > $1    loop
	     SELECT c.firstname,o.orderid, o.orderdate , o.totalamount into result
              FROM orders o 
              WHERE o.customerid = c.customerid
              ORDER BY o.orderdate DESC
              LIMIT 1;
         IF result is not null THEN       
             RETURN NEXT result;   
         END IF;   
     END LOOP;
    RETURN;
 END;
 $$
 LANGUAGE plpgsql;


2- CREATE OR REPLACE  FUNCTION oldest_orders_by_customer_lateral (int) RETURNS SETOF t_oldest_orders_by_customer  AS  $$
 BEGIN 
	RETURN QUERY SELECT customer_sub.firstname  , o_sub.*
       FROM (SELECT * FROM customers c2 WHERE age > $1) customer_sub,
       LATERAL (SELECT o.orderid, o.orderdate , o.totalamount 
                FROM orders o 
                WHERE o.customerid = customer_sub.customerid
                ORDER BY o.orderdate DESC
                LIMIT 1) o_sub;
 END;
 $$
 LANGUAGE plpgsql;

 
1- SELECT * FROM oldest_orders_by_customer(80);
Time: 89.296 ms

2- SELECT * FROM oldest_orders_by_customer_lateral(80);
Time: 45.230 ms



-- #4. USE PARALLEL SAFE WHENEVER POSSIBLE

-- When is it safe to use PARALLEL in a function? As long as your code does not perform the following, you should be ready to use it:

-- Writes to the database.
-- Access sequences.
-- Change the transaction state.
-- Makes persistent changes to settings.
-- Access temporary tables.
-- Use cursors.
-- Defines prepared statements

1- CREATE OR REPLACE FUNCTION pair_div_4 (i int) RETURNS boolean
    AS $$
BEGIN
    IF $1%2 = 0 AND $1%4 = 0 THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

2- CREATE OR REPLACE FUNCTION pair_div_4_ps (i int) RETURNS boolean
    AS $$
BEGIN
    IF $1%2 = 0 AND $1%4 = 0 THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END;
$$
LANGUAGE plpgsql
PARALLEL SAFE;


1- EXPLAIN ANALYZE  SELECT * from trade where pair_div_4 (id);

 Seq Scan on trade  (cost=0.00..448684.86 rows=563520 width=16) (actual time=0.323..2459.553 rows=422640 loops=1)
   Filter: pair_div_4(id)
   Rows Removed by Filter: 1267921
 Planning Time: 0.070 ms
 Execution Time: 2471.796 ms


2- explain analyze  select * from trade where pair_div_4_ps (id);

 Gather  (cost=1000.00..249635.11 rows=563520 width=16) (actual time=0.883..1386.856 rows=422640 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on trade  (cost=0.00..192283.11 rows=234800 width=16) (actual time=0.868..1301.220 rows=140880 loops=3)
         Filter: pair_div_4_ps(id)
         Rows Removed by Filter: 422640
 Planning Time: 0.138 ms
 Execution Time: 1405.412 ms



 -- #5. USE IMMUTABLE WHEN IT IS POSSIBLE

-- You cannot modify the database (state) and always returns the same result for the same argument values;

-- Do not search in the databases or use information that is not directly present in its argument list values.

1- CREATE OR REPLACE FUNCTION get_date (date) RETURNS int
    AS $$
DECLARE
    i int;
    result int:= 0;
BEGIN
   RETURN extract (day from $1);
END;
$$
LANGUAGE plpgsql;


2- CREATE OR REPLACE FUNCTION get_date_i (date) RETURNS int
    AS $$
DECLARE
    i int;
    result int:= 0;
BEGIN
   RETURN extract (day from $1);
END;
$$
LANGUAGE plpgsql IMMUTABLE;


1- SELECT 1  from trade where id=get_date(current_date);
 Time: 2557.521 ms (00:02.558)
2- SELECT 1  from trade where id=get_date_i(current_date);;
 Time: 2208.848 ms (00:02.209)



-- #5 MONITORING PERFORMANCE OF FUNCTIONS

-- PostgreSQL allows the user to track the performance of functions in the database. For example, we can see the performance stats using the view pg_stat_user_functions, 
-- as long as you configure the parameter named track_functions, that allows tracking function call counts and time spent. To simplify the configuration we can leverage the option
-- that gives us postgresqlcon.nf to share a configuration file, download it and apply it to your server. Specifically, to track function performance, select the download format
-- alter_system, apply the modification to your server, and reload the configuration using select pg_reload_conf(). This allows us to detect which functions are working as expected or are slow.



select schemaname||'.'||funcname func_name, calls, total_time, round((total_time/calls)::numeric,2) as mean_time, self_time   from pg_catalog.pg_stat_user_functions;


         func_name         | calls | total_time | mean_time | self_time 
---------------------------+-------+------------+-----------+-----------
 public.f_plpgsql          |     2 |     93.908 |     46.95 |    93.908
 public.auditoria_clientes |  2684 |    593.705 |      0.22 |   593.705
 public.prc_clientes       |     2 |      1.447 |      0.72 |     0.387
 public.max_pro_min        |     3 |      1.589 |      0.53 |     1.589
 public.registro_ddl       |    17 |     39.217 |      2.31 |    39.217
 public.registro_ddl_drop  |     2 |    422.386 |    211.19 |   422.386


-- calls: Number of times this function has been called

-- total_time: Time(ms) spent in this function and all other functions called by it inside their code

-- mean_time: AVG Time(ms) spent in this function and all other functions called by it inside their code

-- self_time: Time(ms) spent in this function itself, without including other functions called by it