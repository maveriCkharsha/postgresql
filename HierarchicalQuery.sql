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
15	C2   	13	B3   
16	D1   	15	C2   
17	E1   	11	B1   
18	E2   	11	B1   
