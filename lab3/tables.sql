CREATE TABLE c##dev.employees (
    employee_id number not null,
    first_name varchar2(100) not null,
    last_name varchar2(100) not null,
    department_id number not null,
    CONSTRAINT pk_employee_id PRIMARY KEY (employee_id),
    CONSTRAINT FK_DEPARTMENT FOREIGN KEY (department_id) REFERENCES C##DEV.DEPARTMENTS(department_id)
);

CREATE TABLE c##dev.departments (
    department_id number not null,
    department_name varchar2(100) not null,
    CONSTRAINT pk_department_id PRIMARY KEY (department_id)
);

CREATE TABLE c##dev.abc (
    abc_id number not null,
    CONSTRAINT pk_abc_id PRIMARY KEY (abc_id)
);

CREATE TABLE c##prod.employees (
    employee_id number not null,
    first_name varchar2(100) not null,
    last_name varchar2(100) not null,
    CONSTRAINT pk_employee_id PRIMARY KEY (employee_id)
);

CREATE TABLE c##prod.departments (
    department_id number not null,
    department_name varchar2(100) not null,
    location varchar2(100) not null,
    CONSTRAINT pk_department_id PRIMARY KEY (department_id)
);

CREATE TABLE c##prod.abc (
    abc_id number not null,
    CONSTRAINT pk_abc_id PRIMARY KEY (abc_id)
);

drop table c##prod.abc;

