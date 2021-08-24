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


-- with composite type and other ouptput parameters
create type type_x as (propcode int, propname text);


CREATE OR REPLACE FUNCTION employeefunc1 (rc_out OUT type_x[], x out int)
returns record 
AS
$$
declare 
    z record;
    propc int;
    pname text;
BEGIN
    rc_out := ARRAY(SELECT ROW(propcode, propname) :: type_x FROM prop LIMIT 5);
        
x := 0;
END;
$$ LANGUAGE plpgsql;       


select (unnest(rc_out)).propcode, (unnest(rc_out)).propname from employeefunc1() ;

select (unnest(rc_out)).propcode, (unnest(rc_out)).propname, x from employeefunc1() ;

