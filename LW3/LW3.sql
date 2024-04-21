CREATE USER c##dev IDENTIFIED BY pass; -- schema creation
GRANT ALL PRIVILEGES TO c##dev;
CREATE USER c##prod IDENTIFIED BY pass;
GRANT ALL PRIVILEGES TO c##prod;




CREATE OR REPLACE FUNCTION compare_schemas(
  dev_schema_name IN VARCHAR2,
  prod_schema_name IN VARCHAR2
) RETURN SYS.ODCIVARCHAR2LIST IS
  table_names SYS.ODCIVARCHAR2LIST; -- array of strings
  current_fk_table_names SYS.ODCIVARCHAR2LIST; -- will contain related tables for current table
  i number:=1;
  j number:=1;
  k number:=1;
  l number:=1;
  creatable boolean:=true;
  temp varchar2(500);
BEGIN
    SELECT differing_tables BULK COLLECT INTO table_names FROM ( -- names put into separate collection for further sorting
        SELECT table_name AS differing_tables
        FROM all_tables
        WHERE owner = dev_schema_name AND table_name NOT IN ( -- no matching table name
          SELECT table_name
          FROM all_tables
          WHERE owner = prod_schema_name
        )
        UNION 
        SELECT a.table_name AS differing_tables  --table names match, different columns
        FROM all_tables a, all_tables b
        WHERE a.owner = dev_schema_name AND
            b.owner = prod_schema_name AND
            a.table_name = b.table_name AND -- same name
            EXISTS ( -- there are columns that belong to only 1 table or differ in type
                (
                    SELECT column_name, data_type --all columns from dev table
                    FROM all_tab_columns
                    WHERE table_name = a.table_name AND owner = a.owner
                    MINUS
                    SELECT column_name, data_type --all columns from prod table
                    FROM all_tab_columns
                    WHERE table_name = b.table_name AND owner = b.owner
                )
                UNION
                (
                    SELECT column_name, data_type --all columns from prod table
                    FROM all_tab_columns
                    WHERE table_name = b.table_name  AND owner = b.owner
                    MINUS
                    SELECT column_name, data_type --all columns from dev table
                    FROM all_tab_columns
                    WHERE table_name = a.table_name  AND owner = a.owner
                )
            )
    );
    
   
    
  LOOP -- sorting by foreign key (similar to selection sort)
     -- i - index of current element in unsorted part (starts at 1)
     -- j - index of sorted part border
     
    IF i > table_names.COUNT  THEN 
      IF i!=j THEN -- reached end but not all sorted
        DBMS_OUTPUT.PUT_LINE('Discrepant tables have foreign key loop:');
         FOR k in j..table_names.COUNT
         LOOP
           DBMS_OUTPUT.PUT_LINE(table_names(k));
         END LOOP;
      END IF;
      EXIT;
    END IF;
    -- check for tables from foreign key constraints
    
    SELECT -- all foreign key tables for current table
        p.table_name AS referenced_table BULK COLLECT INTO current_fk_table_names -- table of pk for fk
    FROM
        all_constraints f -- table of all constraints
            JOIN
        all_constraints p ON f.r_constraint_name = p.constraint_name -- table of dependant constaraints (for fk: uniq or pk)
    WHERE
        f.constraint_type = 'R' -- foreign key type constraint
        and f.table_name = table_names(i)
        and f.owner = dev_schema_name;
        
     -- check if unsorted tables are in dependencies
    FOR k in j..table_names.COUNT -- index of unsorted
    LOOP 
        FOR l in 1..current_fk_table_names.COUNT -- index of constraint table
        LOOP
            if table_names(k) = current_fk_table_names(l) THEN
                creatable:=false;
                EXIT;
            END IF;
        END LOOP;
        IF creatable=false THEN
            EXIT;
        END IF;
    END LOOP; 
    
    IF creatable THEN --if not limited by remaining tables - swaps with first unsorted and becomes sorted
        temp:=table_names(j);
        table_names(j) := table_names(i);
        table_names(i):=temp;
        i:=j;
        j:=j+1;
    ELSE
        creatable:=true;
    END IF;
    
    i := i + 1;
  END LOOP;  
    
  RETURN table_names;
END;
/


/*
 FOR i in 1..table_names.COUNT
    LOOP
      DBMS_OUTPUT.PUT_LINE(table_names(i));
    END LOOP;
*/



SELECT compare_schemas('C##DEV' , 'C##PROD') FROM DUAL;

SELECT * FROM all_tables
WHERE OWNER = 'C##PROD';
SELECT * FROM all_tables
WHERE OWNER = 'C##DEV';

SELECT * FROM all_procedures
WHERE OWNER = 'C##PROD';
SELECT * FROM all_procedures
WHERE OWNER = 'C##DEV';

select * FROM all_indexes;


select * from all_constraints
WHERE OWNER = 'C##DEV';


    BEGIN
        DBMS_OUTPUT.PUT_LINE('123');
    END;

select * from all_cons_columns