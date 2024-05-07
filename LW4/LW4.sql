CREATE DIRECTORY JSON_files AS 'D:\Programming\BSUIR\OracleDB\LW4\JSON';

DROP Table Table1;
CREATE Table Table1(
    id number,
    column1 number,
    column2 number
);

DROP Table Table2;
CREATE Table Table2(
    id number,
    column1 number,
    column2 number
);



CREATE OR REPLACE PROCEDURE read_json_file( -- function for reading file into string
    p_file_name IN VARCHAR2,
    p_json_data OUT CLOB
)
IS
    l_file UTL_FILE.FILE_TYPE;
    l_buffer VARCHAR2(32767);
    l_amount NUMBER := 32767;
BEGIN
    l_file := UTL_FILE.FOPEN('JSON_FILES', p_file_name, 'r');
    LOOP
        UTL_FILE.GET_LINE(l_file, l_buffer, l_amount);
        p_json_data := p_json_data || l_buffer;
    END LOOP;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        UTL_FILE.FCLOSE(l_file);
    WHEN OTHERS THEN
        UTL_FILE.FCLOSE(l_file);
        RAISE;
END;
/



CREATE OR REPLACE FUNCTION parse_json_select(json_str IN VARCHAR2) RETURN SYS_REFCURSOR 
IS
    json_obj JSON_OBJECT_T;
    keys JSON_KEY_LIST;
    key VARCHAR2(100);
    value VARCHAR2(100);
    value_array JSON_ARRAY_T;
    
    action VARCHAR2(100);
    table_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    column_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    where_string VARCHAR2(500);
    
    sql_query VARCHAR2(1000);
    select_cursor SYS_REFCURSOR;
BEGIN
    json_obj := JSON_OBJECT_T(json_str);
    keys := json_obj.get_keys;

    FOR i IN 1..keys.COUNT LOOP  -- getting values into collections
        key := keys(i);
        value := json_obj.get_string(key);
        
        if key = 'action' THEN
            action:=value;
        ELSIF key = 'columns' THEN
            value_array := json_obj.get_array(key);
            FOR i in 0..value_array.get_size()-1 LOOP
              column_list.EXTEND;
              column_list(column_list.LAST) := value_array.get_string(i);
            END LOOP;
        ELSIF key = 'tables' THEN
            value_array := json_obj.get_array(key);
            FOR i in 0..value_array.get_size()-1 LOOP
              table_list.EXTEND;
              table_list(table_list.LAST) := value_array.get_string(i);
            END LOOP;
        ELSIF key = 'where' THEN
            where_string := value;
        END IF;
    END LOOP;

    if action = 'select' THEN                      
        sql_query := 'SELECT ' || column_list(1); 
        FOR i IN 2..column_list.COUNT LOOP
            sql_query := sql_query || ', ' || column_list(i); 
        END LOOP;
        sql_query := sql_query  || ' FROM ' || table_list(1); 
        FOR i IN 2..table_list.COUNT LOOP
            sql_query := sql_query || ', ' || table_list(i); 
        END LOOP;
        
        IF where_string IS NOT NULL THEN
          sql_query := sql_query || ' WHERE ' || where_string; 
        END IF;
        
        DBMS_OUTPUT.PUT_LINE(sql_query);
        OPEN select_cursor FOR sql_query;
        RETURN select_cursor;
    ELSE
      RAISE_APPLICATION_ERROR(-20001, 'UNEXPECTED ACTION');
    END IF;
    
END;
/






CREATE OR REPLACE PROCEDURE parse_json(json_str IN VARCHAR2)
AUTHID CURRENT_USER 
IS
    json_obj JSON_OBJECT_T;
    keys JSON_KEY_LIST;
    key VARCHAR2(100);
    value VARCHAR2(100);
    value_array JSON_ARRAY_T;
    
    action VARCHAR2(100);
    column_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(); -- INSERT/CREATE
    where_string VARCHAR2(500); -- UPDATE/DELETE
    table_name VARCHAR2(100); -- INSERT/UPDATE/DELETE/DROP/CREATE
    values_list JSON_ARRAY_T; -- INSERT
    set_string VARCHAR2(500); -- UPDATE
    type_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();  --CREATE
    pkey VARCHAR2(100); --CREATE
    
    sql_query VARCHAR2(1000);
BEGIN
    json_obj := JSON_OBJECT_T(json_str);
    keys := json_obj.get_keys;

    FOR i IN 1..keys.COUNT LOOP  -- getting values into collections
        key := keys(i);
        value := json_obj.get_string(key);
        
        if key = 'action' THEN
            action:=value;
        ELSIF key = 'columns' THEN
            value_array := json_obj.get_array(key);
            FOR i in 0..value_array.get_size()-1 LOOP
              column_list.EXTEND;
              column_list(column_list.LAST) := value_array.get_string(i);
            END LOOP;
        ELSIF key = 'where' THEN
            where_string := value;
        ELSIF key = 'table' THEN
            table_name := value;
        ELSIF key = 'values' THEN
            values_list := json_obj.get_array(key);
        ELSIF key = 'set' THEN
            set_string:=value;
        ELSIF key = 'types' THEN
            value_array := json_obj.get_array(key);
            FOR i in 0..value_array.get_size()-1 LOOP
              type_list.EXTEND;
              type_list(type_list.LAST) := value_array.get_string(i);
            END LOOP;
        ELSIF key = 'pkey' THEN
            pkey:=value;
        END IF;
    END LOOP;

    --action type
    IF action = 'insert' THEN
        sql_query := 'INSERT ALL' || CHR(10);
        FOR i in 0..values_list.get_size()-1 LOOP
                sql_query := sql_query || 'INTO ' || table_name || ' ('; 
                sql_query := sql_query || column_list(1); 
                FOR k IN 2..column_list.COUNT LOOP
                   sql_query := sql_query || ', ' || column_list(k); 
                END LOOP;           
                sql_query := sql_query || ') VALUES '; 
        
              value_array:=TREAT (values_list.get(i) AS json_array_t);
              sql_query := sql_query || '(';
              sql_query := sql_query || value_array.get_string(0);
              FOR j in 1..value_array.get_size()-1 LOOP
                sql_query := sql_query || ', ' || value_array.get_string(j); 
              END LOOP;
              sql_query := sql_query || ')' || CHR(10);
        END LOOP;
        sql_query :=  sql_query || 'SELECT 1 FROM DUAL';
        
        DBMS_OUTPUT.PUT_LINE(sql_query);
        EXECUTE IMMEDIATE sql_query;
    ELSIF action = 'update' THEN
      sql_query := 'UPDATE ' || table_name || CHR(10);
      sql_query := sql_query || 'SET ' || set_string || CHR(10);
      sql_query := sql_query || 'WHERE ' || where_string;
      DBMS_OUTPUT.PUT_LINE(sql_query);
      EXECUTE IMMEDIATE sql_query;
    ELSIF action = 'delete' THEN
      sql_query := 'DELETE ' || table_name || CHR(10);
      sql_query := sql_query || 'WHERE ' || where_string;
      DBMS_OUTPUT.PUT_LINE(sql_query);
      EXECUTE IMMEDIATE sql_query;
    ELSIF action = 'drop' THEN
      sql_query := 'DROP TABLE ' || table_name;
      DBMS_OUTPUT.PUT_LINE(sql_query);
      EXECUTE IMMEDIATE sql_query;
    ELSIF action = 'create' THEN
      sql_query := 'CREATE TABLE ' || table_name || '(' || CHR(10);
        FOR i IN 1..column_list.COUNT-1 LOOP
              IF column_list(i) = pkey THEN
                 sql_query := sql_query || column_list(i) || ' ' || type_list(i) || ' PRIMARY KEY' || ',' || CHR(10); 
              ELSE
               sql_query := sql_query || column_list(i) || ' ' || type_list(i) || ',' || CHR(10);
              END IF;
        END LOOP;
        IF column_list(column_list.COUNT) = pkey THEN
            sql_query := sql_query || column_list(column_list.COUNT) || ' ' || type_list(column_list.COUNT) || ' PRIMARY KEY' || CHR(10); 
          ELSE
            sql_query := sql_query || column_list(column_list.COUNT) || ' ' || type_list(column_list.COUNT) || CHR(10);
          END IF;
     
      sql_query := sql_query || ')';
      DBMS_OUTPUT.PUT_LINE(sql_query);
      EXECUTE IMMEDIATE sql_query;
      
      IF pkey IS NOT NULL THEN
        sql_query := 'CREATE OR REPLACE TRIGGER ' || table_name || '_increment_pkey' || CHR(10)  ||
            'BEFORE INSERT OR UPDATE ON ' || table_name || CHR(10) ||
            'FOR EACH ROW
            WHEN (NEW.'|| pkey ||' IS NULL)
            DECLARE
                row_count Number;
                max_id ' || table_name || '.'|| pkey ||'%TYPE;
            BEGIN
                SELECT COUNT(*) INTO row_count FROM ' || table_name || ';
                IF (row_count != 0) THEN
                    SELECT Max('|| pkey ||') INTO max_id
                    FROM ' || table_name || ';
                    :NEW.'|| pkey ||' := max_id + 1;
                ELSE
                    :NEW.'|| pkey ||' := 1;
                END IF;
            END;';
        DBMS_OUTPUT.PUT_LINE(sql_query);
        EXECUTE IMMEDIATE sql_query;
      END IF;
      
    ELSE
      RAISE_APPLICATION_ERROR(-20001, 'UNEXPECTED ACTION');
    END IF;
END;
/








DECLARE
  json_data CLOB;
  my_cursor SYS_REFCURSOR;
  
    l_cursor_id INTEGER; -- id of cursor
    l_column_count NUMBER; -- amount of columns
    l_record DBMS_SQL.DESC_TAB; -- dynamic table type for cursors
    l_column_value VARCHAR2(4000); 
    cursor_row varchar(2000);
BEGIN
     read_json_file('select2.json', json_data);
     my_cursor:=parse_json_select(json_data);
     dbms_sql.return_result(my_cursor,true);  
END;




DECLARE
  json_data CLOB;
BEGIN
     read_json_file('create2.json', json_data);
     parse_json(json_data);
END;

DROP Table Table1;


SELECT * FROM Table1;
INSERT INTO Table1 (column1)
VALUES ('6');

SELECT * FROM Table2;
INSERT INTO Table2 (id,column1,column2)
VALUES (2,1,2);
              
       
INSERT ALL
INTO Table1 (column1, column2) VALUES (2, 3)
INTO Table1 (column1, column2) VALUES (2, 3)
INTO Table1 (column1, column2) VALUES (1, 2)
SELECT 1 FROM DUAL;












DROP Trigger Table1_increment_pkey;

CREATE OR REPLACE TRIGGER Table1_increment_pkey
BEFORE INSERT OR UPDATE ON Table1
FOR EACH ROW
                    WHEN (NEW.column2 IS NULL)
                    DECLARE
                        row_count Number;
                        max_id Table1.column2%TYPE;
                    BEGIN
                        SELECT COUNT(*) INTO row_count FROM Table1;
                        IF (row_count != 0) THEN
                            SELECT Max(column2) INTO max_id
                            FROM Table1;
                            :NEW.column2 := max_id + 1;
                        ELSE
                            :NEW.column2 := 1;
                        END IF;
                    END;
                    
                    
                    
BEGIN
EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER Table1_increment_pkey
BEFORE INSERT OR UPDATE ON Table1
FOR EACH ROW
                    WHEN (NEW.column2 IS NULL)
                    DECLARE
                        row_count Number;
                        max_id Table1.column2%TYPE;
                    BEGIN
                        SELECT COUNT(*) INTO row_count FROM Table1;
                        IF (row_count != 0) THEN
                            SELECT Max(column2) INTO max_id
                            FROM Table1;
                            :NEW.column2 := max_id + 1;
                        ELSE
                            :NEW.column2 := 1;
                        END IF;
                    END;';
END;