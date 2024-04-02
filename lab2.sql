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