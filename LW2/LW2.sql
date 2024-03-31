-- #1
DROP Table Students;
CREATE Table Students(
    id number,
    name varchar2(100),
    group_id number
);

DROP Table Groups;
CREATE Table Groups(
    id number,
    name varchar2(100),
    c_val number
);

-- #2

CREATE OR REPLACE TRIGGER students_insert_check
BEFORE INSERT OR UPDATE ON Students
FOR EACH ROW
DECLARE
    non_unique_id Students.id%TYPE;
BEGIN
    -- ???????? ?? ????????????
    SELECT id INTO non_unique_id
    FROM Students
    WHERE id = :NEW.id;

    IF SQL%FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Non unique id insert');
    END IF;
END;

Select * FROM Students;
Insert into Students (id,name,group_id) VALUES
    (1,'er',1);