--table checks
DROP TABLE TestTable1;
CREATE TABLE TestTable1(
    id number
);
DROP TABLE TestTable3;
CREATE TABLE TestTable3(
    id number,
    id2 number
);

DROP TABLE TestTable6;
CREATE TABLE TestTable6(
    id number unique,
    id2 number unique
);

DROP FUNCTION func1;
CREATE OR REPLACE FUNCTION func1
RETURN Number IS
BEGIN
  RETURN 1;
END;
/

DROP PROCEDURE proc1;
CREATE OR REPLACE PROCEDURE proc1
IS
BEGIN
   BEGIN
    DBMS_OUTPUT.PUT_LINE(1);
   END;
END;
/



CREATE INDEX table1_index ON TestTable1 (id);






DROP TABLE TESTTABLE2;





