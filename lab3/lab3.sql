
CREATE OR REPLACE PROCEDURE COMPARE_SCHEM(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2
) AS

    TYPE TableList IS TABLE OF VARCHAR2(200);
    TYPE ColumnList IS TABLE OF VARCHAR2(200);

    dev_tables TableList;
    prod_tables TableList;
    tables_sorted TableList := TableList();
    tables_checked TableList := TableList();
    
    PROCEDURE sort_tables(
        p_table_name IN VARCHAR2
    ) IS

        cursor fk_cursor IS
            SELECT CC.TABLE_NAME AS child_table
            FROM ALL_CONSTRAINTS PC
            JOIN ALL_CONSTRAINTS CC ON PC.CONSTRAINT_NAME = CC.R_CONSTRAINT_NAME
            WHERE PC.CONSTRAINT_TYPE = 'P'
              AND CC.CONSTRAINT_TYPE = 'R'
              AND PC.OWNER = dev_schema_name
              AND CC.OWNER = dev_schema_name
              AND PC.TABLE_NAME = p_table_name;
    BEGIN
        IF p_table_name NOT MEMBER OF tables_checked THEN
            tables_checked.EXTEND;
            tables_checked(tables_checked.LAST) := p_table_name;
            
            FOR i IN fk_cursor LOOP
                IF i.child_table NOT MEMBER OF tables_checked THEN
                    sort_tables(i.child_table);
                ELSE
                    DBMS_OUTPUT.PUT_LINE('Looped connections detected');
                END IF;
            END LOOP;
            
            tables_sorted.EXTEND;
            tables_sorted(tables_sorted.LAST) := p_table_name;
        END IF;
    END sort_tables;
    
    
    FUNCTION compare_table_structure(
        p_table_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_dev_count NUMBER;
        l_prod_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO l_dev_count
        FROM all_tab_columns
        WHERE owner = UPPER(dev_schema_name) AND table_name = UPPER(p_table_name);

        SELECT COUNT(*)
        INTO l_prod_count
        FROM all_tab_columns
        WHERE owner = UPPER(prod_schema_name) AND table_name = UPPER(p_table_name);

        IF l_dev_count <> l_prod_count THEN
           RETURN FALSE;
        END IF;

        FOR r IN (
            SELECT column_name, data_type, data_length
            FROM all_tab_columns
            WHERE owner = UPPER(dev_schema_name) AND table_name = UPPER(p_table_name)
            MINUS
            SELECT column_name, data_type, data_length
            FROM all_tab_columns
            WHERE owner = UPPER(prod_schema_name) AND table_name = UPPER(p_table_name)
        ) LOOP
            RETURN FALSE;
        END LOOP;

        RETURN TRUE;
    END;



BEGIN
    SELECT table_name BULK COLLECT INTO dev_tables FROM all_tables WHERE owner = UPPER(dev_schema_name);
    SELECT table_name BULK COLLECT INTO prod_tables FROM all_tables WHERE owner = UPPER(prod_schema_name);

    FOR i IN 1..dev_tables.COUNT LOOP
        sort_tables(dev_tables(i));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Sorted tables in ' || dev_schema_name || ':');
    FOR i IN 1..tables_sorted.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(tables_sorted(i));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Tables in ' || dev_schema_name || ' but not in ' || prod_schema_name || ':');
    FOR i IN 1..tables_sorted.COUNT LOOP
        IF NOT tables_sorted(i) MEMBER OF prod_tables THEN
            DBMS_OUTPUT.PUT_LINE(tables_sorted(i) || ' (missing in ' || prod_schema_name || ')');
        ELSIF NOT compare_table_structure(tables_sorted(i)) THEN
            DBMS_OUTPUT.PUT_LINE(tables_sorted(i) || ' (exists in both but diff structure)');
        END IF;
    END LOOP;
    
END COMPARE_SCHEM;



SHOW ERRORS PROCEDURE COMPARE_SCHEM;


SELECT * FROM user_errors WHERE name = 'COMPARE_SCHEM';

ALTER PROCEDURE COMPARE_SCHEM COMPILE;

DROP PROCEDURE COMPARE_SCHEM;

CALL COMPARE_SCHEM('C##DEV', 'C##PROD');
