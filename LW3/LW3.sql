CREATE USER c##dev IDENTIFIED BY pass; -- schema creation
GRANT ALL PRIVILEGES TO c##dev;
CREATE USER c##prod IDENTIFIED BY pass;
GRANT ALL PRIVILEGES TO c##prod;




CREATE OR REPLACE FUNCTION compare_schemas( -- must be started by SYS, because SYSTEM can't see other users functions (SELECT ANY DICTIONARY privelege)
  dev_schema_name IN VARCHAR2,
  prod_schema_name IN VARCHAR2
) RETURN SYS.ODCIVARCHAR2LIST IS   -- array of strings
  table_names SYS.ODCIVARCHAR2LIST; -- tables to be added
  func_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST(); -- funcs to be added
  proc_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST(); -- procs to be added
  index_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST();
  current_fk_table_names SYS.ODCIVARCHAR2LIST; -- temp for related tables for current table
  i number:=1; -- indexes for loops
  j number:=1;
  k number:=1;
  l number:=1;
  temp_number number;
  creatable boolean:=true; -- temp flag for tables with fks 
  temp varchar2(500); -- temp for names
BEGIN
    --get differing table names
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
    
    
  --sort differing table names
  LOOP -- sorting tables by foreign key (similar to selection sort)
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
  
  
  --get differing func names
  FOR dev_func IN (SELECT object_name, DBMS_METADATA.GET_DDL(object_type, object_name, schema=>dev_schema_name) as ddl_text
                    FROM all_objects
                    WHERE object_type = 'FUNCTION'
                    AND owner = dev_schema_name)
    LOOP
        SELECT COUNT(*) INTO temp_number FROM all_objects  --compared by ddl     
        WHERE owner = prod_schema_name
        AND object_type = 'FUNCTION'
        AND object_name = dev_func.object_name
        AND 
        DBMS_LOB.SUBSTR( --converts clob (large text) to nvarchar to prevent comparing type errors
            REGEXP_REPLACE( --replaces first prod schema mention to dev schema (to make ddl same)
                DBMS_METADATA.GET_DDL(object_type, object_name, schema=>prod_schema_name),
                '(^|[^a-zA-Z_0-9])' || prod_schema_name || '([^a-zA-Z_0-9]|$)', '\1' || dev_schema_name || '\2', 1, 1)
            , 32767, 1)
        = DBMS_LOB.SUBSTR(dev_func.ddl_text, 32767, 1);                  
            
        IF temp_number != 1 THEN
            func_names.EXTEND;
            func_names(func_names.COUNT) := dev_func.object_name;                
        END IF;
    END LOOP;
    
    
    --get differing proc names
  FOR dev_proc IN (SELECT object_name, DBMS_METADATA.GET_DDL(object_type, object_name, schema=>dev_schema_name) as ddl_text
                    FROM all_objects
                    WHERE object_type = 'PROCEDURE'
                    AND owner = dev_schema_name)
    LOOP
        SELECT COUNT(*) INTO temp_number FROM all_objects
        WHERE owner = prod_schema_name
        AND object_type = 'PROCEDURE'
        AND object_name = dev_proc.object_name
        AND 
        DBMS_LOB.SUBSTR( --converts clob (large text) to nvarchar to prevent comparing type errors
            REGEXP_REPLACE( --replaces first prod schema mention to dev schema (to make ddl same)
                DBMS_METADATA.GET_DDL(object_type, object_name, schema=>prod_schema_name),
                '(^|[^a-zA-Z_0-9])' || prod_schema_name || '([^a-zA-Z_0-9]|$)', '\1' || dev_schema_name || '\2', 1, 1)
            , 32767, 1)
        = DBMS_LOB.SUBSTR(dev_proc.ddl_text, 32767, 1);                  
            
        IF temp_number != 1 THEN
            proc_names.EXTEND;
            proc_names(proc_names.COUNT) := dev_proc.object_name;                
        END IF;
    END LOOP;
  
     --get differing index names
    FOR dev_index IN (SELECT object_name, table_name, column_name
                    FROM all_objects
                    JOIN all_ind_columns ON index_name = object_name AND index_owner=owner
                    WHERE object_type = 'INDEX'
                    AND Generated='N' -- generated indexes will always differ as they have unique name (not recorded as not directly created by user)
                    AND owner = dev_schema_name)
     LOOP
        SELECT COUNT(*) INTO temp_number  
                    FROM all_objects
                    JOIN all_ind_columns ON index_name = object_name AND index_owner=owner
                    WHERE object_type = 'INDEX'
                    AND Generated='N' -- generated indexes will always differ as they have unique name (not recorded as not directly created by user)
                    AND owner = prod_schema_name
                    AND object_name = dev_index.object_name -- compared by name/table/column
                    AND table_name = dev_index.table_name
                    AND column_name = dev_index.column_name;
                IF temp_number != 1 THEN
                    index_names.EXTEND;
                    index_names(index_names.COUNT) := dev_index.object_name;                
                END IF;
     END LOOP;
    
  RETURN index_names;
END;
/


/*
 FOR i in 1..table_names.COUNT
    LOOP
      DBMS_OUTPUT.PUT_LINE(table_names(i));
    END LOOP;
*/


SELECT compare_schemas('C##DEV', 'C##PROD') FROM DUAL;


BEGIN
    DBMS_OUTPUT.PUT_LINE('123');
END;


                    
                    
                    
SELECT owner, object_name, DBMS_METADATA.GET_DDL(object_type, object_name, schema=>owner) as ddl_text
                    FROM all_objects
                    WHERE object_type = 'INDEX'
                    AND owner IN ('C##PROD','C##DEV');          
                    
                    
SELECT *
FROM all_objects
WHERE object_type = 'INDEX'
AND GENERATED='N'
AND owner IN ('C##PROD','C##DEV');                     


select * FROM all_indexes
WHERE owner IN ('C##PROD','C##DEV')
AND Generated = 'N';













select * from all_ind_columns;


SELECT owner, object_name, table_name, column_name
                    FROM all_objects
                    JOIN all_ind_columns ON index_name = object_name AND index_owner=owner
                    WHERE object_type = 'INDEX'
                    AND Generated='N' -- generated indexes will always differ as they have unique name (not recorded as not directly created by user)
                    AND owner = 'C##DEV';
                    

SELECT owner, object_name, table_name, column_name
                    FROM all_objects
                    JOIN all_ind_columns ON index_name = object_name
                    WHERE object_type = 'INDEX'
                    AND Generated='N' -- generated indexes will always differ as they have unique name (not recorded as not directly created by user)
                    AND owner = 'C##PROD';
