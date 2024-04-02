grant connect to c##Labs;
grant all privileges to c##Labs;

DROP TABLE GROUPS;

CREATE TABLE STUDENTS (
    id NUMBER(10),
    name VARCHAR2(256),
    group_id NUMBER(10),
    CONSTRAINT pk_students PRIMARY KEY (id)
);

CREATE TABLE GROUPS (
    id NUMBER(10),
    name VARCHAR2(256),
    c_val NUMBER(10),
    CONSTRAINT pk_group PRIMARY KEY (id)
);

create or replace trigger insert_on_student
before insert on students
for each row
declare id_count number;
begin
    select count(*) into id_count from STUDENTS where id = :NEW.id;
    
    if (id_count != 0) then
        raise_application_error(-20001, 'Id should be unique.');
    end if;
end;


CREATE SEQUENCE stud_seq START WITH 1;

create or replace trigger auto_increment_on_students
before insert on students
for each row
follows insert_on_student//check_group_id_on_student
begin
    if (:NEW.id is null) then
        select stud_seq.nextval into :NEW.id from dual;
    end if;
end;

CREATE SEQUENCE group_seq START WITH 1;

create or replace trigger auto_increment_on_groups
before insert on groups
for each row
follows insert_on_group
begin
    if (:NEW.id is null) then
        select group_seq.nextval into :NEW.id from dual;
    end if;
end;


SELECT * FROM STUDENTS;

DECLARE
BEGIN
    insert into students (id, name, group_id) values(1, 's 1', 1);
    insert into students (id, name, group_id) values(2, 's 2', 2);
    insert into students (id, name, group_id) values(3, 's 3', 2);
END;

SELECT * FROM STUDENTS;