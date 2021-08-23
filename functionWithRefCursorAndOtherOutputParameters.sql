CREATE OR REPLACE FUNCTION employeefunc1 (rc_out OUT refcursor, x out int)
RETURNS record /*If there are multiple OUT parameters it should always be RECORD*/
AS
$$
BEGIN
    OPEN rc_out
    FOR
    SELECT propcode, propname
    FROM prop LIMIT 5;
x := 0;
END;
$$ LANGUAGE plpgsql;       


DO
$$
DECLARE
    prop refcursor;
    yy int;
    propcode int;
    propname text;
begin
    SELECT * FROM employeefunc1() INTO prop, yy;
    RAISE NOTICE '%,%',prop, yy;
    LOOP
    FETCH NEXT FROM prop INTO propcode, propname;
    EXIT WHEN NOT FOUND;
    RAISE NOTICE 'propcode :%, propname : %', propcode, propname;
    END LOOP;
end;
$$
language plpgsql
