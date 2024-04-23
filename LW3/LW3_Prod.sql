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


CREATE OR REPLACE FUNCTION func1
RETURN Number IS
BEGIN
  RETURN 1;
END;
/

CREATE OR REPLACE PROCEDURE proc1
IS
BEGIN
   BEGIN
    DBMS_OUTPUT.PUT_LINE(1);
   END;
END;
/