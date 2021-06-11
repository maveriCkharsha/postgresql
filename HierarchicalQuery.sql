create table dummy_table( emp_no int, ename char(5), job char(9), manager_no int );

insert into dummy_table values(10, 'A1', 'CEO',null);
insert into dummy_table values(11, 'B1', 'VP', 10);
insert into dummy_table values(12, 'B2', 'VP', 10);
insert into dummy_table values(13, 'B3', 'VP', 10);
insert into dummy_table values(14, 'C1', 'DIRECTOR', 13);
insert into dummy_table values(15, 'C2', 'DIRECTOR', 13);
insert into dummy_table values(16, 'D1', 'MANAGER', 15);
insert into dummy_table values(17 ,'E1', 'ENGINEER', 11);
insert into dummy_table values(18, 'E2', 'ENGINEER', 11);


SELECT * FROM dummy_table;

-- with empno and manager no
/*
-- to remember :
1. Write first SELECT to get one higher record using NULL 
2. COPY the same SELECT from the step 1 (w/0 WHERE clause) and INNER JOIN with CTE
3. as CTE has first record - need to start with that emp id - meaning - cte.empno 
	and then recurse it with normal table manager records  - maintable.manager_no
*/

WITH RECURSIVE cte AS (
SELECT 
	emp_no,
	ename,
	manager_no,
	1 as level
FROM 
	dummy_table
WHERE manager_no IS NULL 
UNION ALL
SELECT 
	t.emp_no,
	t.ename,
	t.manager_no,
	level + 1
FROM 
	dummy_table t
	INNER JOIN cte c
		ON c.emp_no = t.manager_no
)
SELECT * 
FROM cte
ORDER BY 1;

emp_no,ename,manager_no,"level"
10	A1   		1
11	B1   	10	2
12	B2   	10	2
13	B3   	10	2
14	C1   	13	3
15	C2   	13	3
16	D1   	15	4
17	E1   	11	3
18	E2   	11	3


-- with ename and manager name 

WITH RECURSIVE cte AS (
SELECT 
	emp_no,
	ename,
	manager_no,
	1 as level
FROM 
	dummy_table
WHERE manager_no IS NULL 
UNION ALL
SELECT 
	t.emp_no,
	t.ename,
	t.manager_no,
	level + 1
FROM 
	dummy_table t
	INNER JOIN cte c
		ON c.emp_no = t.manager_no
)
SELECT 
	cte.emp_no, cte.ename, cte.manager_no, x.ename as manager_name
FROM cte 
	LEFT JOIN dummy_table x 
		ON cte.manager_no = x.emp_no
ORDER BY 1;

emp_no,ename,manager_no,manager_name
10	A1   		
11	B1   	10	A1   
12	B2   	10	A1   
13	B3   	10	A1   
14	C1   	13	B3  


CREATE TABLE bst (n int, p int);

INSERT INTO bst VALUES (1,2), (3,2), (6,8), (9,8), (2,5), (8,5), (5, null);

WITH RECURSIVE cte AS (
	SELECT 
		n,
		p,
		0 as level
	FROM bst
	WHERE p ISNULL
	UNION ALL 
	SELECT 
		t.n,
		t.p,
		level + 1
	FROM bst t 
		JOIN cte ON cte.n = t.p
)
SELECT 
	n,CASE 
		WHEN level = 0 THEN 'Root'
		WHEN level = (SELECT level FROM cte ORDER BY level DESC limit 1) THEN 'Leaf'
		ELSE 'Inner'
	END
FROM cte ORDER BY n;

|n  |case |
|---|-----|
|1  |Leaf |
|2  |Inner|
|3  |Leaf |
|5  |Root |
|6  |Leaf |
|8  |Inner|
|9  |Leaf |


REATE TABLE employees (
   id serial PRIMARY KEY,
   name varchar(255) NOT NULL,
   salary integer,
   job varchar(255),
   manager_id int,
   FOREIGN KEY (manager_id) REFERENCES employees (id) ON DELETE CASCADE
);

INSERT INTO employees (
    id,
    name,
    manager_id,
    salary,
    job
)
VALUES
    (1,  'John', NULL, 10000, 'CEO'),
    (2,  'Ben', 5, 1400, 'Junior Developer'),
    (3,  'Barry', 5, 500, 'Intern'),
    (4,  'George', 5, 1800, 'Developer'),
    (5,  'James', 7, 3000, 'Manager'),
    (6,  'Steven', 7, 2400, 'DevOps Engineer'),
    (7,  'Alice', 1, 4200, 'VP'),
    (8,  'Jerry', 1, 3500, 'Manager'),
    (9,  'Adam', 8, 2000, 'Data Analyst'),
    (10, 'Grace', 8, 2500, 'Developer');
   
   
    
-- to check from certain level 		
WITH RECURSIVE cte AS (
	SELECT 
		id, 
		name, 
		manager_id,
		1 as level
	FROM employees
	WHERE id = 7
	UNION ALL
	SELECT
		e.id,
		e.name,
		e.manager_id,
		level + 1
	FROM employees e
		JOIN cte ON e.manager_id = cte.id
)
SELECT * FROM cte;

|id |name  |manager_id|level|
|---|------|----------|-----|
|7  |Alice |1         |1    |
|5  |James |7         |2    |
|6  |Steven|7         |2    |
|2  |Ben   |5         |3    |
|3  |Barry |5         |3    |
|4  |George|5         |3    |


-- to check from CEO level 		
WITH RECURSIVE cte AS (
	SELECT 
		id, 
		name, 
		manager_id,
		1 as level
	FROM employees
	WHERE manager_id ISNULL
	UNION ALL
	SELECT
		e.id,
		e.name,
		e.manager_id,
		level + 1
	FROM employees e
		JOIN cte ON e.manager_id = cte.id
)
SELECT * FROM cte;


|id |name  |manager_id|level|
|---|------|----------|-----|
|1  |John  |          |1    |
|7  |Alice |1         |2    |
|8  |Jerry |1         |2    |
|5  |James |7         |3    |
|6  |Steven|7         |3    |
|9  |Adam  |8         |3    |
|10 |Grace |8         |3    |
|2  |Ben   |5         |4    |
|3  |Barry |5         |4    |
|4  |George|5         |4    |


--  job progression

WITH RECURSIVE cte AS (
	SELECT 
		id, 
		name,
		manager_id,
		job,
		0 as level
	FROM employees
	WHERE name = 'George'
	UNION ALL
	SELECT 
		e.id,
		e.name,
		e.manager_id,
		e.job,
		level + 1
	FROM employees e
		JOIN cte ON e.id = cte.manager_id
)
SELECT STRING_AGG(job, '-> ' ORDER BY level) FROM cte;

|string_agg                    |
|------------------------------|
|Developer-> Manager-> VP-> CEO|






 
15	C2   	13	B3   
16	D1   	15	C2   
17	E1   	11	B1   
18	E2   	11	B1   
