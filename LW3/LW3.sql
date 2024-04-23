CREATE USER c##dev IDENTIFIED BY pass; -- schema creation
GRANT ALL PRIVILEGES TO c##dev;
CREATE USER c##prod IDENTIFIED BY pass;
GRANT ALL PRIVILEGES TO c##prod;




CREATE OR REPLACE FUNCTION compare_schemas( -- must be started by SYS, because SYSTEM can't see other users functions (SELECT ANY DICTIONARY privelege)
  dev_schema_name IN VARCHAR2,
  prod_schema_name IN VARCHAR2
) RETURN nvarchar2 IS

  table_names SYS.ODCIVARCHAR2LIST;  -- (array of strings)    tables to be added/changed
  func_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST(); -- funcs to be added/changed
  proc_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST(); -- procs to be added/changed
  index_names SYS.ODCIVARCHAR2LIST:= SYS.ODCIVARCHAR2LIST(); -- indexes to be added/changed
  
  current_fk_table_names SYS.ODCIVARCHAR2LIST; -- temp for related tables for current table
  i number:=1; -- indexes for loops
  j number:=1;
  k number:=1;
  l number:=1;
  temp_number number;
  creatable boolean:=true; -- temp flag for tables with fks 
  escape_flag boolean:=false;
  temp varchar2(32767); -- temp for names
  
  ddl_comment varchar2(32767):='';
  ddl_drop varchar2(32767):='';
  ddl_output varchar2(32767):='';
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
                    MINUS -- dev only columns
                    SELECT column_name, data_type --all columns from prod table
                    FROM all_tab_columns
                    WHERE table_name = b.table_name AND owner = b.owner
                )
                UNION
                (
                    SELECT column_name, data_type --all columns from prod table
                    FROM all_tab_columns
                    WHERE table_name = b.table_name  AND owner = b.owner
                    MINUS -- prod only columns
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
         ddl_comment:=ddl_comment||'--Discrepant tables have foreign key loop:'||CHR(10);
         FOR k in j..table_names.COUNT
         LOOP
           ddl_comment:=ddl_comment||'--'||table_names(k)||CHR(10);
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
        AND object_name = dev_func.object_name;        
            
        IF temp_number != 1 THEN
            func_names.EXTEND;
            func_names(func_names.COUNT) := dev_func.object_name; 
            
            ddl_output:=ddl_output||DBMS_LOB.SUBSTR(
                REGEXP_REPLACE(
                    dev_func.ddl_text,
                    dev_schema_name, prod_schema_name, 1, 0)
                , 32767, 1)
            ||CHR(10);       
        END IF;
    END LOOP;
    
    
    --get differing proc names
  FOR dev_proc IN (SELECT object_name, DBMS_METADATA.GET_DDL(object_type, object_name, schema=>dev_schema_name) as ddl_text
                    FROM all_objects
                    WHERE object_type = 'PROCEDURE'
                    AND owner = dev_schema_name)
    LOOP
        SELECT COUNT(*) INTO temp_number
        FROM all_objects
        WHERE owner = prod_schema_name
        AND object_type = 'PROCEDURE'
        AND object_name = dev_proc.object_name;
            
        IF temp_number != 1 THEN
            proc_names.EXTEND;
            proc_names(proc_names.COUNT) := dev_proc.object_name;   
            
            ddl_output:=ddl_output||DBMS_LOB.SUBSTR(
                REGEXP_REPLACE(
                    dev_proc.ddl_text,
                    dev_schema_name, prod_schema_name, 1, 0)
                , 32767, 1)||CHR(10);           
        END IF;
    END LOOP;
    
    
     --get ddl for tables
     for k in 1..j-1
     LOOP
        SELECT DBMS_LOB.SUBSTR(REGEXP_REPLACE(DBMS_METADATA.GET_DDL(object_type, object_name, schema=>dev_schema_name),
                            dev_schema_name, prod_schema_name, 1, 0)
                        , 32767, 1) as ddl_text INTO temp
                    FROM all_objects
                    WHERE object_type = 'TABLE'
                    AND owner = dev_schema_name
                    AND object_name = table_names(k);
         ddl_output:=ddl_output||temp||';'||CHR(10);
     END LOOP;
  
     --get differing index names
    FOR dev_index IN (SELECT object_name, table_name, column_name, DBMS_METADATA.GET_DDL(object_type, object_name, schema=>dev_schema_name) as ddl_text
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
                    AND Generated='N'
                    AND owner = prod_schema_name
                    AND object_name = dev_index.object_name -- compared by name/table/column
                    AND table_name = dev_index.table_name
                    AND column_name = dev_index.column_name;
                IF temp_number != 1 THEN
                    index_names.EXTEND;
                    index_names(index_names.COUNT) := dev_index.object_name;
                    ddl_output:=ddl_output||DBMS_LOB.SUBSTR(
                        REGEXP_REPLACE(
                            dev_index.ddl_text,
                            dev_schema_name, prod_schema_name, 1, 0)
                        , 32767, 1)||';'||CHR(10);
                END IF;
     END LOOP;
     
    --drop statements for prod only objects
  FOR prod_object IN (SELECT object_name,object_type
                    FROM all_objects p
                    WHERE object_type IN ('FUNCTION','PROCEDURE','INDEX','TABLE')
                    AND Generated = 'N'
                    AND owner = prod_schema_name
                    AND NOT EXISTS (SELECT object_name,object_type  -- no same dev object
                        FROM all_objects d
                        WHERE d.object_type IN ('FUNCTION','PROCEDURE','INDEX','TABLE')
                        AND d.Generated = 'N'
                        AND d.object_name = p.object_name
                        AND d.owner = dev_schema_name)
                        )
    LOOP
        ddl_drop:=ddl_drop|| 'DROP '|| prod_object.object_type || ' ' || prod_object.object_name || ';' ||CHR(10);
    END LOOP;  
    
  RETURN ddl_comment||ddl_drop || CHR(10) || ddl_output;
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


SELECT *
FROM all_objects
WHERE Generated='N'
AND owner IN ('C##DEV', 'C##PROD');




