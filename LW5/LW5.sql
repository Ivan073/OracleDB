--1 Tables
DROP TABLE Faculties;
CREATE TABLE Faculties(
    id number PRIMARY KEY,
    name nvarchar2(200),
    creation_time TIMESTAMP
);

DROP TABLE Groups;
CREATE TABLE Groups(
    id number PRIMARY KEY,
    name nvarchar2(200),
    creation_time TIMESTAMP,
    faculty_id number,
    CONSTRAINT fk_faculty FOREIGN KEY (faculty_id) REFERENCES Faculties(Id)
);


DROP TABLE Students;
CREATE TABLE Students(
    id number PRIMARY KEY,
    name nvarchar2(200),
    admission_time TIMESTAMP,
    group_id number,
    CONSTRAINT fk_group FOREIGN KEY (group_id) REFERENCES Groups(Id)
);






--2 Table logs
DROP Table StudentLog;
CREATE Table StudentLog(
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation varchar2(100),
    st_id number NOT NULL,
    st_name varchar2(200),
    st_admission_time TIMESTAMP,
    st_group_id number,
    operation_date timestamp
);

DROP Table GroupLog;
CREATE Table GroupLog(
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation varchar2(100),
    gr_id number NOT NULL,
    gr_name varchar2(200),
    gr_creation_time TIMESTAMP,
    gr_faculty_id number,
    operation_date timestamp
);

DROP Table FacultyLog;
CREATE Table FacultyLog(
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation varchar2(100),
    f_id number NOT NULL,
    f_name varchar2(200),
    f_creation_time TIMESTAMP,
    operation_date timestamp
);




CREATE OR REPLACE TRIGGER log_students
AFTER INSERT OR UPDATE OR DELETE ON Students
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_admission_time,st_group_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.admission_time, :New.group_id, CURRENT_TIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_admission_time,st_group_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.admission_time, :OLD.group_id, CURRENT_TIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO StudentLog (operation, st_id,st_name,st_admission_time,st_group_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.admission_time, :OLD.group_id, CURRENT_TIMESTAMP);
        INSERT INTO StudentLog (operation, st_id,st_name,st_admission_time,st_group_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.admission_time, :New.group_id, CURRENT_TIMESTAMP);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER log_groups
AFTER INSERT OR UPDATE OR DELETE ON Groups
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO GroupLog (operation, gr_id,gr_name,gr_creation_time,gr_faculty_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.creation_time, :New.faculty_id, CURRENT_TIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO GroupLog (operation, gr_id,gr_name,gr_creation_time,gr_faculty_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.creation_time, :OLD.faculty_id, CURRENT_TIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO GroupLog (operation, gr_id,gr_name,gr_creation_time,gr_faculty_id,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.creation_time, :OLD.faculty_id, CURRENT_TIMESTAMP);
        INSERT INTO GroupLog (operation, gr_id,gr_name,gr_creation_time,gr_faculty_id,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.creation_time, :New.faculty_id, CURRENT_TIMESTAMP);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER log_faculties
AFTER INSERT OR UPDATE OR DELETE ON Faculties
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO FacultyLog (operation, f_id,f_name,f_creation_time,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.creation_time, CURRENT_TIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO FacultyLog (operation, f_id,f_name,f_creation_time,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.creation_time, CURRENT_TIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO FacultyLog (operation, f_id,f_name,f_creation_time,operation_date)
        VALUES ('Delete', :OLD.id, :OLD.name,:OLD.creation_time, CURRENT_TIMESTAMP);
        INSERT INTO FacultyLog (operation, f_id,f_name,f_creation_time,operation_date)
        VALUES ('Insert', :NEW.id, :New.name, :New.creation_time, CURRENT_TIMESTAMP);
    END IF;
END;
/





--3 Package procedures
CREATE OR REPLACE PACKAGE log_package AS
  PROCEDURE rollback_tables(rollback_time IN TIMESTAMP);
  PROCEDURE rollback_tables(rollback_interval IN INTERVAL DAY TO SECOND);
END log_package;
/



CREATE OR REPLACE PACKAGE BODY log_package AS
  PROCEDURE rollback_tables(rollback_time IN TIMESTAMP) IS
     st_log_rec StudentLog%ROWTYPE;
     gr_log_rec GroupLog%ROWTYPE;
     f_log_rec FacultyLog%ROWTYPE;
  BEGIN
    FOR log_rec IN ( -- subquery for all revertable operations
        SELECT id, operation, operation_date, 'Students' as TableName
        FROM StudentLog
        WHERE operation_date >= rollback_time
        UNION
        SELECT id, operation, operation_date, 'Groups' as TableName
        FROM GroupLog
        WHERE operation_date >= rollback_time
        UNION
        SELECT id, operation, operation_date, 'Faculties' as TableName
        FROM FacultyLog
        WHERE operation_date >= rollback_time
        ORDER BY operation_date DESC
    )
    LOOP
        IF log_rec.operation = 'Delete' THEN
            IF log_rec.TableName = 'Students' THEN
                SELECT * INTO st_log_rec FROM StudentLog WHERE id=log_rec.id;
                INSERT INTO Students (id, name, admission_time, group_id)
                VALUES (st_log_rec.st_id, st_log_rec.st_name, st_log_rec.st_admission_time, st_log_rec.st_group_id);
            ELSIF log_rec.TableName = 'Groups' THEN
                SELECT * INTO gr_log_rec FROM GroupLog WHERE id=log_rec.id;
                INSERT INTO Groups (id, name, creation_time, faculty_id)
                VALUES (gr_log_rec.gr_id, gr_log_rec.gr_name, gr_log_rec.gr_creation_time, gr_log_rec.gr_faculty_id);
            ELSIF log_rec.TableName = 'Faculties' THEN
                SELECT * INTO f_log_rec FROM FacultyLog WHERE id=log_rec.id;
                INSERT INTO Faculties (id, name,creation_time)
                VALUES (f_log_rec.f_id, f_log_rec.f_name, f_log_rec.f_creation_time);
            END IF;
        ELSIF log_rec.operation = 'Insert' THEN
            IF log_rec.TableName = 'Students' THEN
                SELECT * INTO st_log_rec FROM StudentLog WHERE id=log_rec.id;
                DELETE FROM Students 
                WHERE id = st_log_rec.st_id AND name = st_log_rec.st_name
                AND group_id = st_log_rec.st_group_id AND admission_time = st_log_rec.st_admission_time;
            END IF;
            IF log_rec.TableName = 'Groups' THEN
                SELECT * INTO gr_log_rec FROM GroupLog WHERE id=log_rec.id;
                DELETE FROM Groups 
                WHERE id = gr_log_rec.gr_id AND name = gr_log_rec.gr_name
                AND faculty_id = gr_log_rec.gr_faculty_id AND creation_time = gr_log_rec.gr_creation_time;
            END IF;
            IF log_rec.TableName = 'Faculties' THEN
                SELECT * INTO f_log_rec FROM FacultyLog WHERE id=log_rec.id;
                DELETE FROM Faculties
                WHERE id = f_log_rec.f_id AND name = f_log_rec.f_name
                AND creation_time = f_log_rec.f_creation_time;
            END IF;
        END IF;
    END LOOP;
    
    DELETE FROM StudentLog
    WHERE operation_date >= rollback_time;
    DELETE FROM GroupLog
    WHERE operation_date >= rollback_time;
    DELETE FROM FacultyLog
    WHERE operation_date >= rollback_time;
END;

  PROCEDURE rollback_tables(rollback_interval IN INTERVAL DAY TO SECOND) IS
        st_log_rec StudentLog%ROWTYPE;
         gr_log_rec GroupLog%ROWTYPE;
         f_log_rec FacultyLog%ROWTYPE;
         rollback_time TIMESTAMP;
      BEGIN
        rollback_time := CURRENT_TIMESTAMP - rollback_interval;
        FOR log_rec IN ( -- subquery for all revertable operations
            SELECT id, operation, operation_date, 'Students' as TableName
            FROM StudentLog
            WHERE operation_date >= rollback_time
            UNION
            SELECT id, operation, operation_date, 'Groups' as TableName
            FROM GroupLog
            WHERE operation_date >= rollback_time
            UNION
            SELECT id, operation, operation_date, 'Faculties' as TableName
            FROM FacultyLog
            WHERE operation_date >= rollback_time
            ORDER BY operation_date DESC
        )
        LOOP
            IF log_rec.operation = 'Delete' THEN
                IF log_rec.TableName = 'Students' THEN
                    SELECT * INTO st_log_rec FROM StudentLog WHERE id=log_rec.id;
                    INSERT INTO Students (id, name, admission_time, group_id)
                    VALUES (st_log_rec.st_id, st_log_rec.st_name, st_log_rec.st_admission_time, st_log_rec.st_group_id);
                ELSIF log_rec.TableName = 'Groups' THEN
                    SELECT * INTO gr_log_rec FROM GroupLog WHERE id=log_rec.id;
                    INSERT INTO Groups (id, name, creation_time, faculty_id)
                    VALUES (gr_log_rec.gr_id, gr_log_rec.gr_name, gr_log_rec.gr_creation_time, gr_log_rec.gr_faculty_id);
                ELSIF log_rec.TableName = 'Faculties' THEN
                    SELECT * INTO f_log_rec FROM FacultyLog WHERE id=log_rec.id;
                    INSERT INTO Faculties (id, name,creation_time)
                    VALUES (f_log_rec.f_id, f_log_rec.f_name, f_log_rec.f_creation_time);
                END IF;
            ELSIF log_rec.operation = 'Insert' THEN
                IF log_rec.TableName = 'Students' THEN
                    SELECT * INTO st_log_rec FROM StudentLog WHERE id=log_rec.id;
                    DELETE FROM Students 
                    WHERE id = st_log_rec.st_id AND name = st_log_rec.st_name
                    AND group_id = st_log_rec.st_group_id AND admission_time = st_log_rec.st_admission_time;
                END IF;
                IF log_rec.TableName = 'Groups' THEN
                    SELECT * INTO gr_log_rec FROM GroupLog WHERE id=log_rec.id;
                    DELETE FROM Groups 
                    WHERE id = gr_log_rec.gr_id AND name = gr_log_rec.gr_name
                    AND faculty_id = gr_log_rec.gr_faculty_id AND creation_time = gr_log_rec.gr_creation_time;
                END IF;
                IF log_rec.TableName = 'Faculties' THEN
                    SELECT * INTO f_log_rec FROM FacultyLog WHERE id=log_rec.id;
                    DELETE FROM Faculties
                    WHERE id = f_log_rec.f_id AND name = f_log_rec.f_name
                    AND creation_time = f_log_rec.f_creation_time;
                END IF;
            END IF;
        END LOOP;
        
        DELETE FROM StudentLog
        WHERE operation_date >= rollback_time;
        DELETE FROM GroupLog
        WHERE operation_date >= rollback_time;
        DELETE FROM FacultyLog
        WHERE operation_date >= rollback_time;
    END;
END log_package;























SELECT * FROM FacultyLog;
SELECT * FROM Faculties;

SELECT * FROM GroupLog;
SELECT * FROM Groups;


SELECT * FROM StudentLog;
SELECT * FROM Students;



INSERT INTO Faculties(Id,name,creation_time) VALUES (3,'faculty1',CURRENT_TIMESTAMP);
INSERT INTO Groups(Id,name,creation_time,Faculty_id) VALUES (3,'group1',CURRENT_TIMESTAMP,3);
INSERT INTO Students(Id,name,admission_time,Group_id) VALUES (3,'student1',CURRENT_TIMESTAMP,3);


BEGIN
  log_package.rollback_tables(CURRENT_TIMESTAMP-200);
END;


BEGIN
  log_package.rollback_tables(INTERVAL '200' SECOND);
END;