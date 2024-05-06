CREATE DIRECTORY JSON_files AS 'D:\Programming\BSUIR\OracleDB\LW4\JSON';

DROP Table Table1;
CREATE Table Table1(
    id number,
    column1 number,
    column2 number
)




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





CREATE OR REPLACE FUNCTION parse_json(json_str IN VARCHAR2) RETURN SYS_REFCURSOR 
IS
    json_obj JSON_OBJECT_T;
    keys JSON_KEY_LIST;
    key VARCHAR2(100);
    value VARCHAR2(100);
    key_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    value_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    value_array JSON_ARRAY_T;
    
    action VARCHAR2(100);
    table_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    column_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    
    sql_query VARCHAR2(1000);
    
    select_cursor SYS_REFCURSOR;
BEGIN
    json_obj := JSON_OBJECT_T(json_str);
    keys := json_obj.get_keys;

    FOR i IN 1..keys.COUNT LOOP  -- getting values into collections
        key := keys(i);
        value := json_obj.get_string(key);
        
        key_list.EXTEND;
        value_list.EXTEND;
        key_list(key_list.LAST) := key;
        value_list(value_list.LAST) := value;
        
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
        END IF;
    END LOOP;

    --action type
    if action = 'select' THEN -- select
        sql_query := 'SELECT ' || column_list(1); 
        FOR i IN 2..column_list.COUNT LOOP
            sql_query := sql_query || ', ' || column_list(i); 
        END LOOP;
        sql_query := sql_query  || ' FROM ' || table_list(1); 
        FOR i IN 2..table_list.COUNT LOOP
            sql_query := sql_query || ', ' || table_list(i); 
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(sql_query);
       
        OPEN select_cursor FOR sql_query;
        RETURN select_cursor;

      
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
     read_json_file('json1.json', json_data);
     my_cursor:=parse_json(json_data);
     dbms_sql.return_result(my_cursor,true);  
END;




SELECT * FROM Table1;
INSERT INTO Table1 (id,column1,column2)
VALUES (1,'1','1');