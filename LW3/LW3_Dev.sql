--table checks
DROP TABLE TestTable1;
CREATE TABLE TestTable1(
    id number
);
DROP TABLE TestTable2;
CREATE TABLE TestTable2(
    id number
);

DROP TABLE TestTable3;
CREATE TABLE TestTable3(
    id number unique
);

DROP TABLE TestTable4;
CREATE TABLE TestTable4(
    id number unique,
    id2 number,
    CONSTRAINT FK_TestTables3_4 FOREIGN KEY (id) REFERENCES TestTable3(id)
);

DROP TABLE TestTable5;
CREATE TABLE TestTable5(
    id number unique,
    CONSTRAINT FK_TestTables4_5 FOREIGN KEY (id) REFERENCES TestTable4(id)
);


--loop constraint

ALTER TABLE TestTable4 DROP CONSTRAINT loop_fk_5_4;

ALTER TABLE TestTable4
ADD CONSTRAINT loop_fk_5_4
FOREIGN KEY (id2)
REFERENCES TestTable5(id);

--procedures/functions

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


--indexes

CREATE INDEX table4_index ON TestTable4 (id2);

CREATE INDEX table1_index ON TestTable1 (id);








--------------------------------------------------------------------------



create or replace function func2(val1 number)
return number
IS
BEGIN
   BEGIN
    DBMS_OUTPUT.PUT_LINE(2);
    return 1;
   END;
END;
/




DROP TABLE T2;
CREATE TABLE T2(
    id number unique,
    val number unique
);


ALTER TABLE T2
ADD CONSTRAINT fk3
FOREIGN KEY (val)
REFERENCES T1(val);

ALTER TABLE T2 DROP CONSTRAINT fk3;


DROP TABLE T1;
CREATE TABLE T1(
    id number unique,
    val number unique,
    CONSTRAINT FK1 FOREIGN KEY (val) REFERENCES T3(val)
);

DROP TABLE T3;
CREATE TABLE T3(
    id number unique,
    val number unique,
    CONSTRAINT FK2 FOREIGN KEY (val) REFERENCES T2(val)
);