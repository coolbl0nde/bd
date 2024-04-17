
CREATE OR REPLACE PROCEDURE COMPARE_SCHEM(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2
) AS

    TYPE TableList IS TABLE OF VARCHAR2(200);
    TYPE ColumnList IS TABLE OF VARCHAR2(200);

    dev_tables TableList;
    prod_tables TableList;
    sorted_tables TableList := TableList();
    checked_tables TableList := TableList();
    
    proc_dev           TableList := TableList();
    proc_prod          TableList := TableList();
    proc_only_dev      TableList := TableList();
    proc_only_prod     TableList := TableList();
    proc_diff          TableList := TableList();
    func_dev           TableList := TableList();
    func_prod          TableList := TableList();
    func_only_dev      TableList := TableList();
    func_only_prod     TableList := TableList();
    func_diff          TableList := TableList();
    idx_dev            TableList := TableList();
    idx_prod           TableList := TableList();
    idx_only_dev       TableList := TableList();
    idx_only_prod      TableList := TableList();
    pkg_dev            TableList := TableList();
    pkg_prod           TableList := TableList();
    pkg_only_dev       TableList := TableList();
    pkg_only_prod      TableList := TableList();
    pkg_diff           TableList := TableList();
    ddl_str            CLOB := '';
    
    counter Number;
    
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
        IF p_table_name NOT MEMBER OF checked_tables THEN
            checked_tables.EXTEND;
            checked_tables(checked_tables.LAST) := p_table_name;
            
            FOR i IN fk_cursor LOOP
                IF i.child_table NOT MEMBER OF checked_tables THEN
                    sort_tables(i.child_table);
                ELSE
                    DBMS_OUTPUT.PUT_LINE('Looped connections detected');
                END IF;
            END LOOP;
            
            sorted_tables.EXTEND;
            sorted_tables(sorted_tables.LAST) := p_table_name;
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
    FOR i IN 1..sorted_tables.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(sorted_tables(i));
    END LOOP;
    
    SELECT
    COUNT(*)
INTO counter
FROM
    (
        WITH table_hierarchy AS (
            SELECT
                child_owner,
                child_table,
                parent_owner,
                parent_table
            FROM
                     (
                    SELECT
                        owner             AS child_owner,
                        table_name        AS child_table,
                        r_owner           AS parent_owner,
                        r_constraint_name AS constraint_name
                    FROM
                        all_constraints
                    WHERE
                            constraint_type = 'R'
                        AND owner = dev_schema_name
                )
                JOIN (
                    SELECT
                        owner      AS parent_owner,
                        constraint_name,
                        table_name AS parent_table
                    FROM
                        all_constraints
                    WHERE
                            constraint_type = 'P'
                        AND owner = dev_schema_name
                ) USING ( parent_owner,
                          constraint_name )
        )
        SELECT DISTINCT
            child_owner,
            child_table
        FROM
            (
                SELECT
                    *
                FROM
                    table_hierarchy
                WHERE
                    ( child_owner, child_table ) IN (
                        SELECT
                            parent_owner, parent_table
                        FROM
                            table_hierarchy
                    )
            )
        WHERE
            CONNECT_BY_ISCYCLE = 1
        CONNECT BY NOCYCLE
            ( PRIOR child_owner,
              PRIOR child_table ) = ( ( parent_owner,
                                        parent_table ) )
    );

IF counter > 0 THEN
    dbms_output.put_line(counter || ' ' ||' Loop connections detected.');
ELSE
    dbms_output.put_line('No loop connections detected.');
END IF;

    dbms_output.put_line('********************');
    dbms_output.put_line(chr(10)
                         || 'Table in DEV but not in PROD or with different structure');                     
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN REVERSE 1..sorted_tables.count LOOP
        IF sorted_tables(i) NOT MEMBER OF prod_tables THEN
            dbms_output.put_line(dbms_metadata.get_ddl('TABLE', sorted_tables(i), dev_schema_name)
                                 || chr(10));

        ELSIF NOT compare_table_structure(sorted_tables(i)) THEN
            dbms_output.put_line(sorted_tables(i)
                                 || ' }'
                                 || chr(10));
        END IF;
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    
    dbms_output.put_line('********************');
    dbms_output.put_line(chr(10) || 'Tables only in PROD');
    dbms_output.put_line('********************');
    FOR i IN 1..prod_tables.COUNT LOOP
        IF prod_tables(i) NOT MEMBER OF dev_tables THEN
            dbms_output.put_line('DROP TABLE ' || prod_schema_name || '.' || prod_tables(i) || ';');
        END IF;
    END LOOP;

    --compare_packages;

    SELECT
        object_name
    BULK COLLECT
    INTO proc_dev
    FROM
        all_objects
    WHERE
            object_type = 'PROCEDURE'
        AND owner = dev_schema_name;

    SELECT
        object_name
    BULK COLLECT
    INTO proc_prod
    FROM
        all_objects
    WHERE
            object_type = 'PROCEDURE'
        AND owner = prod_schema_name;

    FOR i IN 1..proc_dev.count LOOP
        IF proc_dev(i) MEMBER OF proc_prod THEN
            SELECT
                COUNT(*)
            INTO counter
            FROM
                (
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = dev_schema_name
                        AND object_name = proc_dev(i)
                    MINUS
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = prod_schema_name
                        AND object_name = proc_dev(i)
                    UNION ALL
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = prod_schema_name
                        AND object_name = proc_dev(i)
                    MINUS
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = dev_schema_name
                        AND object_name = proc_dev(i)
                );

            IF counter > 0 THEN
                proc_diff.extend;
                proc_diff(proc_diff.last) := proc_dev(i);
            END IF;

        END IF;
    END LOOP;

    proc_only_dev := proc_dev MULTISET EXCEPT proc_prod;
    proc_only_prod := proc_prod MULTISET EXCEPT proc_dev;
    dbms_output.put_line('********************');
    dbms_output.put_line('Only DEV procedures');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..proc_only_dev.count LOOP
        ddl_str := ddl_str
                   || dbms_metadata.get_ddl('PROCEDURE', proc_only_dev(i), dev_schema_name);
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    dbms_output.put_line('********************');
    dbms_output.put_line('Only PROD procedures');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..proc_only_prod.count LOOP
        --ddl_str := ddl_str
        --           || dbms_metadata.get_ddl('PROCEDURE', proc_only_prod(i), prod_schema_name);
        dbms_output.put_line('DROP PROCEDURE ' || prod_schema_name || '.' || proc_only_prod(i) || ';');
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    dbms_output.put_line('********************');
    dbms_output.put_line(chr(10)
                         || 'Procedures that have different parameters');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..proc_diff.count LOOP
        ddl_str := ddl_str
                   || 'DROP PROCEDURE'
                   || ' '
                   || prod_schema_name
                   || '.'
                   || proc_diff(i)
                   || ';';

        ddl_str := ddl_str
                   || dbms_metadata.get_ddl('PROCEDURE', proc_diff(i), dev_schema_name);

    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);

    SELECT
        object_name
    BULK COLLECT
    INTO func_dev
    FROM
        all_objects
    WHERE
            object_type = 'FUNCTION'
        AND owner = dev_schema_name;

    SELECT
        object_name
    BULK COLLECT
    INTO func_prod
    FROM
        all_objects
    WHERE
            object_type = 'FUNCTION'
        AND owner = prod_schema_name;

    FOR i IN 1..func_dev.count LOOP
        IF func_dev(i) MEMBER OF func_prod THEN
            SELECT
                COUNT(*)
            INTO counter
            FROM
                (
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = dev_schema_name
                        AND object_name = func_dev(i)
                    MINUS
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = prod_schema_name
                        AND object_name = func_dev(i)
                    UNION ALL
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = prod_schema_name
                        AND object_name = func_dev(i)
                    MINUS
                    SELECT
                        argument_name,
                        position,
                        data_type,
                        in_out
                    FROM
                        all_arguments
                    WHERE
                            owner = dev_schema_name
                        AND object_name = func_dev(i)
                );

            IF counter > 0 THEN
                func_diff.extend;
                func_diff(func_diff.last) := func_dev(i);
            END IF;

        END IF;
    END LOOP;

    func_only_dev := func_dev MULTISET EXCEPT func_prod;
    func_only_prod := func_prod MULTISET EXCEPT func_dev;
    dbms_output.put_line('********************');
    dbms_output.put_line('Only DEV functions');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..func_only_dev.count LOOP
        ddl_str := ddl_str
                   || dbms_metadata.get_ddl('FUNCTION', func_only_dev(i), dev_schema_name);
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    dbms_output.put_line('********************');
    dbms_output.put_line('Only PROD functions');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..func_only_prod.count LOOP
        --ddl_str := ddl_str
         --          || dbms_metadata.get_ddl('FUNCTION', func_only_prod(i), prod_schema_name);
         dbms_output.put_line('DROP FUNCTION ' || prod_schema_name || '.' || func_only_prod(i) || ';');
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    dbms_output.put_line('********************');
    dbms_output.put_line(chr(10)
                         || 'Functions that have different parameters');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..func_diff.count LOOP
        ddl_str := ddl_str
                   || 'DROP FUNCTION'
                   || ' '
                   || prod_schema_name
                   || '.'
                   || func_diff(i)
                   || ';';

        ddl_str := ddl_str
                   || dbms_metadata.get_ddl('FUNCTION', func_diff(i), dev_schema_name);

    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);

    SELECT
        index_name
    BULK COLLECT
    INTO idx_dev
    FROM
        all_indexes
    WHERE
            owner = dev_schema_name
         AND index_name NOT LIKE 'SYS%';

    SELECT
        index_name
    BULK COLLECT
    INTO idx_prod
    FROM
        all_indexes
    WHERE
            owner = prod_schema_name
        AND index_name NOT LIKE 'SYS%';

    idx_only_dev := idx_dev MULTISET EXCEPT idx_prod;
    idx_only_prod := idx_prod MULTISET EXCEPT idx_dev;
    dbms_output.put_line('********************');
    dbms_output.put_line('Only DEV indexes');
    dbms_output.put_line('********************');
    ddl_str := '';
    FOR i IN 1..idx_only_dev.count LOOP
        ddl_str := ddl_str
                   || dbms_metadata.get_ddl('INDEX', idx_only_dev(i), dev_schema_name);
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    dbms_output.put_line('********************');
    dbms_output.put_line('Only PROD indexes');
    dbms_output.put_line('********************');
    ddl_str        := '';
    FOR i IN 1..idx_only_prod.count LOOP
        dbms_output.put_line('DROP INDEX '
                             || prod_schema_name
                             || '.'
                             || idx_only_prod(i)
                             || ';');
    END LOOP;

    ddl_str := replace(ddl_str, dev_schema_name, prod_schema_name);
    dbms_output.put_line(ddl_str);
    
END COMPARE_SCHEM;



SHOW ERRORS PROCEDURE COMPARE_SCHEM;


SELECT * FROM user_errors WHERE name = 'COMPARE_SCHEM';

ALTER PROCEDURE COMPARE_SCHEM COMPILE;

DROP PROCEDURE COMPARE_SCHEM;

CALL COMPARE_SCHEM('C##DEV', 'C##PROD');
