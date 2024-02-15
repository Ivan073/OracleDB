-- #1
create Table MyTable(
    id number,
    val number
)


-- #2
DECLARE
  random NUMBER;
BEGIN
  FOR i IN 1..10000 LOOP
    random := TRUNC(DBMS_RANDOM.VALUE(1, 101)); -- [1,100]

    INSERT INTO MyTable (val) VALUES (random);
  END LOOP;
END;


-- #3
CREATE OR REPLACE FUNCTION compare_even_odd_count RETURN VARCHAR IS
  odds NUMBER;
  evens NUMBER;
BEGIN
    
  SELECT COUNT(CASE WHEN MOD(val, 2) = 0 THEN 1 END) AS even_count,
         COUNT(CASE WHEN MOD(val, 2) = 1 THEN 0 END) AS odd_count
  INTO evens, odds
  FROM   MyTable;
  
  IF evens < odds THEN
    return 'TRUE';
  ELSIF evens > odds THEN
    return 'FALSE';
  ELSE
    return 'EQUAL';
  END IF;
END;


select compare_even_odd_count() FROM DUAL;








select * FROM MyTable
ORDER BY VAL DESC

TRUNCATE TABLE MyTable