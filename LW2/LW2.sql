-- #1
DROP Table Students;
CREATE Table Students(
    id number NOT NULL,
    name varchar2(100),
    group_id number
);

DROP Table Groups;
CREATE Table Groups(
    id number,
    name varchar2(100),
    c_val number NOT NULL
);




-- #2
CREATE OR REPLACE TRIGGER students_check_id 
FOR INSERT OR UPDATE ON Students
COMPOUND TRIGGER -- compound trigger is needed because select during update is not possible, beforehand copy is required
   TYPE id_set IS TABLE OF Boolean INDEX BY PLS_INTEGER; -- associative array of ids which can be indexed by integers (regular array doesn't allow unordered ids)

   student_ids id_set;

   BEFORE STATEMENT IS
   BEGIN
      FOR rec IN (SELECT id FROM Students) LOOP --set of table ids
          student_ids(rec.id) :=1;
      END LOOP;
   END BEFORE STATEMENT;

   AFTER EACH ROW IS
   BEGIN
      IF UPDATING THEN -- if updating old version of row needs to be removed
        student_ids.DELETE(:OLD.id); 
      END IF;
      IF student_ids.EXISTS(:NEW.id) THEN -- check if id already in table
         RAISE_APPLICATION_ERROR(-20001, 'ID must be unique');
      ELSE
         student_ids(:NEW.id) := 1;
      END IF;
   END AFTER EACH ROW;
END students_check_id;
/













CREATE OR REPLACE TRIGGER groups_check_id 
FOR INSERT OR UPDATE ON Groups
COMPOUND TRIGGER -- compound trigger is needed because select during update is not possible, beforehand copy is required

   TYPE table_type IS TABLE OF Groups%ROWTYPE;
   group_table table_type := table_type();
   new_row Groups%ROWTYPE;

   BEFORE STATEMENT IS
   BEGIN
      FOR rec IN (SELECT * FROM Groups) LOOP --copy of table before operations
         group_table.EXTEND;
         group_table(group_table.LAST) := rec;
      END LOOP;
   END BEFORE STATEMENT;

   AFTER EACH ROW IS
   BEGIN
      IF UPDATING THEN -- if updating old version of row needs to be removed
        FOR i IN 1 .. group_table.COUNT LOOP
          IF group_table(i).id = :OLD.id THEN
            group_table.DELETE(i);
            EXIT;
          END IF;
        END LOOP;
      END IF;
      FOR i IN 1 .. group_table.COUNT LOOP -- compare new record with all old records
        IF group_table(i).id = :NEW.id THEN
           RAISE_APPLICATION_ERROR(-20001, 'ID must be unique');
        END IF;
      END LOOP;
      group_table.EXTEND; -- add new record to copy
      new_row.id := :NEW.id;
      new_row.name := :NEW.name;
      group_table(group_table.LAST) := new_row;
   END AFTER EACH ROW;
END groups_check_id;
/

















CREATE OR REPLACE TRIGGER students_increment_id
BEFORE INSERT OR UPDATE ON Students
FOR EACH ROW
WHEN (NEW.id IS NULL)    -- needed to not change id from insert
DECLARE
    row_count Number;
    max_id Students.id%TYPE;
BEGIN
    SELECT COUNT(*) INTO row_count FROM Students;
    IF (row_count != 0) THEN
        SELECT Max(id) INTO max_id
        FROM Students;
        :NEW.id := max_id + 1;
    ELSE
        :NEW.id := 1;
    END IF;
END;
/



CREATE OR REPLACE TRIGGER groups_increment_id
BEFORE INSERT OR UPDATE ON Groups
FOR EACH ROW
WHEN (NEW.id IS NULL )
DECLARE
    row_count Number;
    max_id Groups.id%TYPE;
BEGIN
    SELECT COUNT(*) INTO row_count FROM Groups;
    IF (row_count != 0) THEN
        SELECT Max(id) INTO max_id
        FROM Groups;
        :NEW.id := max_id + 1;
    ELSE
         :NEW.id := 1;
    END IF;
END;
/



CREATE OR REPLACE TRIGGER groups_check_name 
BEFORE INSERT OR UPDATE ON Groups
FOR EACH ROW
DECLARE
    non_unique_name_cnt Number;
BEGIN
    SELECT count(*) INTO non_unique_name_cnt
    FROM Groups
    WHERE name = :NEW.name AND ROWNUM=1; -- null == null returns false, so null would pass

    IF non_unique_name_cnt != 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Non-unique name insert ''' || :NEW.name || '''');
    END IF;
END;
/






-- #3
CREATE OR REPLACE TRIGGER students_groups_fk -- limits inserted group ids
BEFORE INSERT OR UPDATE ON Students
FOR EACH ROW -- inserted group_ids may differ
WHEN (NEW.group_id IS NOT NULL)
DECLARE
    found_id Groups.id%TYPE;
BEGIN 
    SELECT name INTO found_id
    FROM Groups
    WHERE id = :NEW.group_id AND ROWNUM=1;
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'No matching group ''' || :NEW.group_id || '''');
END;
/

DROP TABLE cascade_trigger_flag;
CREATE TABLE cascade_trigger_flag( -- table,which works as flag that determines whether c_val update should happen on Student delete 
    id number
);

CREATE OR REPLACE TRIGGER groups_students_fk -- deletes as cascade by group_id
AFTER DELETE ON Groups
FOR EACH ROW
DECLARE
    found_id Groups.id%TYPE;
BEGIN 
    INSERT INTO cascade_trigger_flag (id) VALUES (1);
    
    DELETE FROM Students
    WHERE group_id = :OLD.id;
    
    DELETE FROM cascade_trigger_flag;
END;
/






-- #4
DROP Table StudentLog;
CREATE Table StudentLog(
    id number NOT NULL,
    operation varchar2(100),
    st_id number NOT NULL,
    st_name varchar2(100),
    st_group_id number
);




-- #5




-- #6
CREATE OR REPLACE TRIGGER change_group_c_val
AFTER INSERT OR UPDATE OR DELETE ON Students
FOR EACH ROW
DECLARE
    cascade_delete NUMBER;
BEGIN

    IF INSERTING THEN
        UPDATE Groups SET c_val = c_val + 1
        WHERE id = :NEW.group_id;
    ELSIF DELETING THEN
        SELECT COUNT(*)
        INTO cascade_delete
        FROM cascade_trigger_flag;
    
        IF cascade_delete=0 THEN -- was not marked in fk trigger
            UPDATE Groups SET c_val = c_val - 1
            WHERE id = :OLD.group_id;
        END IF;
    ELSIF UPDATING THEN
        IF :NEW.group_id != :OLD.group_id THEN
            UPDATE Groups SET c_val = c_val + 1
            WHERE id = :NEW.group_id;
            UPDATE Groups SET c_val = c_val - 1
            WHERE id = :OLD.group_id;
        END IF;
    END IF;
END;
/





INSERT INTO Groups (id,name, c_val) 
VALUES (1,'153003', 0);

INSERT INTO Students (name, group_id) 
VALUES ('Petr', 1);
    
Select * FROM Groups;
Select * FROM Students;

UPDATE Students SET id = 3
WHERE id = 4;
UPDATE Groups SET id = 3;
    
DELETE FROM Groups
WHERE id = 1;

DELETE FROM Students;

UPDATE GROUPS SET name = '153003'
WHERE name = '153003';
