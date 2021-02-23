CREATE TABLE AccountBalance
(
	TransactionDate date
	,AccName text,
	,Type text
	,Amount int
);
 
INSERT INTO AccountBalance
VALUES
('2017-01-01','Anvesh','CR',60000)
,('2017-02-01','Anvesh','DB',8000)
,('2017-03-01','Anvesh','CR',8000)
,('2017-04-01','Anvesh','DB',5000)
,('2017-01-01','Nupur','CR',10000)
,('2017-02-02','Nupur','CR',8000)
,('2017-03-03','Nupur','DB',8000);


WITH cte AS (
SELECT 
	*, CASE true 
   		WHEN type = 'DB' THEN amount * -1
		ELSE amount 
	   END as finalAmount 
FROM accountbalance a2 
)
SELECT 
	*, 
	SUM(finalAmount) OVER (PARTITION BY accname ORDER BY accname, transactiondate )
FROM cte;




2017-01-01	Anvesh	CR	60000	60000	60000
2017-02-01	Anvesh	DB	8000	-8000	52000
2017-03-01	Anvesh	CR	8000	8000	60000
2017-04-01	Anvesh	DB	5000	-5000	55000
2017-01-01	Nupur	CR	10000	10000	10000
2017-02-02	Nupur	CR	8000	8000	18000
2017-03-03	Nupur	DB	8000	-8000	10000