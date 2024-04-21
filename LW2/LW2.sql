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
          student_ids(rec.id) :=true;
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
         student_ids(:NEW.id) := true;
      END IF;
   END AFTER EACH ROW;
END students_check_id;
/


CREATE OR REPLACE TRIGGER groups_check_id 
FOR INSERT OR UPDATE ON Groups
COMPOUND TRIGGER
   TYPE id_set IS TABLE OF Boolean INDEX BY PLS_INTEGER;
   group_ids id_set;

   BEFORE STATEMENT IS
   BEGIN
      FOR rec IN (SELECT id FROM Groups) LOOP
          group_ids(rec.id) :=true;
      END LOOP;
   END BEFORE STATEMENT;

   AFTER EACH ROW IS
   BEGIN
      IF UPDATING THEN
        group_ids.DELETE(:OLD.id); 
      END IF;
      IF group_ids.EXISTS(:NEW.id) THEN
         RAISE_APPLICATION_ERROR(-20001, 'ID must be unique');
      ELSE
         group_ids(:NEW.id) := true;
      END IF;
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
FOR INSERT OR UPDATE ON Groups
COMPOUND TRIGGER
   TYPE name_set IS TABLE OF Boolean INDEX BY PLS_INTEGER;
   group_names name_set;

   BEFORE STATEMENT IS
   BEGIN
      FOR rec IN (SELECT name FROM Groups) LOOP
          group_names(rec.name) :=true;
      END LOOP;
   END BEFORE STATEMENT;

   AFTER EACH ROW IS
   BEGIN
      IF UPDATING THEN
        group_names.DELETE(:OLD.name); 
      END IF;
      IF group_names.EXISTS(:NEW.name) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Name must be unique');
      ELSE
         group_names(:NEW.name) := true;
      END IF;
   END AFTER EACH ROW;
END groups_check_name;
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
    operation varchar2(100),
    st_id number NOT NULL,
    st_name varchar2(100),
    st_group_id number,
    operation_date timestamp
);

CREATE OR REPLACE TRIGGER log_students
AFTER INSERT OR UPDATE OR DELETE ON Students
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_group_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.group_id, CURRENT_TIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_group_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name, :OLD.group_id, CURRENT_TIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_group_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name, :OLD.group_id, CURRENT_TIMESTAMP);
        INSERT INTO StudentLog (operation, st_id,st_name,st_group_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.group_id, CURRENT_TIMESTAMP);
    END IF;
END;
/



-- #5
CREATE OR REPLACE PROCEDURE rollback_students_to_timestamp(
    ts Timestamp
)
IS
BEGIN
    FOR log_rec IN ( -- subquery for all revertable operations
        SELECT operation, st_id, st_name, st_group_id
        FROM StudentLog
        WHERE operation_date >= ts
        ORDER BY operation_date DESC
    )
    LOOP
        IF log_rec.operation = 'Delete' THEN
            INSERT INTO Students (id, name, group_id)
            VALUES (log_rec.st_id, log_rec.st_name, log_rec.st_group_id);
        ELSIF log_rec.operation = 'Insert' THEN
            DELETE FROM Students 
            WHERE id = log_rec.st_id;
        END IF;
    END LOOP;
    
    DELETE FROM StudentLog -- removing logs for reverted operations
    WHERE operation_date >= ts;
END;
/



CREATE OR REPLACE PROCEDURE rollback_students_by_interval(
    revert_interval INTERVAL DAY TO SECOND
)
IS
    ts Timestamp;
BEGIN
    ts:= CURRENT_TIMESTAMP - revert_interval;
    FOR log_rec IN ( -- subquery for all revertable operations
        SELECT operation, st_id, st_name, st_group_id
        FROM StudentLog
        WHERE operation_date >= ts
        ORDER BY operation_date DESC
    )
    LOOP
        IF log_rec.operation = 'Delete' THEN
            INSERT INTO Students (id, name, group_id)
            VALUES (log_rec.st_id, log_rec.st_name, log_rec.st_group_id);
        ELSIF log_rec.operation = 'Insert' THEN
            DELETE FROM Students 
            WHERE id = log_rec.st_id;
        END IF;
    END LOOP;
    
    DELETE FROM StudentLog -- removing logs for reverted operations
    WHERE operation_date >= ts;
END;
/



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
VALUES (1,'153125', 0);

INSERT INTO Students (name, group_id) 
VALUES ('Petr', 1);
    
Select * FROM Groups;
Select * FROM Students;
SELECT * FROM StudentLog;

UPDATE Students SET id = 5
WHERE id = 2;
UPDATE Groups SET id = 3;
    
DELETE FROM Groups
WHERE id = 1;

DELETE FROM Students;

DELETE FROM Students
WHERE Id=3;

UPDATE GROUPS SET name = '153003'
WHERE name = '153003';



select * From dba_triggers
WHERE table_owner = 'SYSTEM';


select * From dba_triggers
WHERE table_owner = 'SYSTEM' and table_name = 'STUDENTS';

Begin
    rollback_students_to_timestamp(CURRENT_TIMESTAMP - INTERVAL '1' HOUR);
END;

Begin
    rollback_students_to_timestamp(CURRENT_TIMESTAMP - INTERVAL '5' SECOND);
END;

Begin
    rollback_students_by_interval(INTERVAL '2' MINUTE);
END;