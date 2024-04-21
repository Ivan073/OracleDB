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