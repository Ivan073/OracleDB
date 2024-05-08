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
    operation varchar2(100),
    st_id number NOT NULL,
    st_name varchar2(200),
    st_admission_time TIMESTAMP,
    st_group_id number,
    operation_date timestamp
);

DROP Table GroupLog;
CREATE Table GroupLog(
    operation varchar2(100),
    gr_id number NOT NULL,
    gr_name varchar2(200),
    gr_creation_time TIMESTAMP,
    gr_faculty_id number,
    operation_date timestamp
);

DROP Table FacultyLog;
CREATE Table FacultyLog(
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









SELECT * FROM FacultyLog;
SELECT * FROM Faculties;

SELECT * FROM GroupLog;
SELECT * FROM Groups;


SELECT * FROM StudentLog;
SELECT * FROM Students;



INSERT INTO Faculties(Id,name,creation_time) VALUES (1,'faculty1',CURRENT_TIMESTAMP);
INSERT INTO Groups(Id,name,creation_time,Faculty_id) VALUES (2,'group1',CURRENT_TIMESTAMP,1);
INSERT INTO Students(Id,name,admission_time,Group_id) VALUES (1,'student1',CURRENT_TIMESTAMP,1);