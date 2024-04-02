CREATE TABLE MYTABLE (
    id NUMBER,
    val NUMBER
);


DECLARE
    i NUMBER;
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO MYTABLE (id, val)
        VALUES (i, TRUNC(DBMS_RANDOM.VALUE(1, 10000)));
    END LOOP;
    COMMIT;
END;
/



CREATE OR REPLACE FUNCTION check_even_odd_balance
RETURN VARCHAR2
IS
    even_count NUMBER;
    odd_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO even_count FROM MYTABLE WHERE MOD(val, 2) = 0;
    
    SELECT COUNT(*) INTO odd_count FROM MYTABLE WHERE MOD(val, 2) != 0;
    
    IF even_count > odd_count THEN
        RETURN 'TRUE';
    ELSIF odd_count > even_count THEN
        RETURN 'FALSE';
    ELSE
        RETURN 'EQUAL';
    END IF;
END;
/

SELECT check_even_odd_balance FROM dual;


CREATE OR REPLACE FUNCTION generate_insert_command(p_id NUMBER) RETURN VARCHAR2 IS
    v_val NUMBER;
    v_command VARCHAR2(100);
BEGIN
    SELECT val INTO v_val FROM MYTABLE WHERE id = p_id;
    
    v_command := 'INSERT INTO MyTable (id, val) VALUES (' || TO_CHAR(p_id) || ', ' || TO_CHAR(v_val) || ');';
    
    RETURN v_command;
END;
/


SELECT generate_insert_command(1) FROM dual;




CREATE OR REPLACE PROCEDURE insert_into_mytable (p_id IN NUMBER, p_val IN NUMBER) IS
BEGIN
    INSERT INTO MYTABLE (id, val) VALUES (p_id, p_val);
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE update_mytable (p_id IN NUMBER, p_new_val IN NUMBER) IS
BEGIN
    UPDATE MYTABLE SET val = p_new_val WHERE id = p_id;
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE delete_from_mytable (p_id IN NUMBER) IS
BEGIN
    DELETE FROM MYTABLE WHERE id = p_id;
    COMMIT;
END;
/


CREATE OR REPLACE FUNCTION calculate_annual_compensation(
    p_monthly_salary NUMBER,
    p_annual_bonus_percentage INTEGER
) RETURN NUMBER IS
    v_annual_compensation NUMBER;
BEGIN
    IF p_monthly_salary IS NULL OR p_annual_bonus_percentage IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'ћес€чна€ зарплата и процент годовых премий не могут быть NULL.');
    ELSIF p_monthly_salary < 0 OR p_annual_bonus_percentage < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'ћес€чна€ зарплата и процент годовых премий не могут быть отрицательными.');
    END IF;
    
    v_annual_compensation := (1 + p_annual_bonus_percentage / 100.0) * 12 * p_monthly_salary;
    
    RETURN v_annual_compensation;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'ѕроизошла непредвиденна€ ошибка: ' || SQLERRM);
END;
/

SELECT calculate_annual_compensation(100000, 10) FROM dual;








