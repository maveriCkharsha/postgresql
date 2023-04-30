DO
$$
DECLARE 
    v_databasename text := 'test';
   	v_env text:= 'QA';
   	v_serverip text:= '10.210.0.22';
    v_adminrole text := v_databasename||'_admin';
    v_readwriterole text := v_databasename||'_readwrite';
    v_readonlyrole text := v_databasename||'_readonly';
BEGIN
    RAISE NOTICE '%', format('REVOKE CONNECT ON DATABASE %s FROM PUBLIC;',v_databasename);
    RAISE NOTICE '%', '------------> After logging in to the dabase <-------------';
    RAISE NOTICE '%', format('REVOKE CREATE ON SCHEMA public FROM PUBLIC;',v_databasename);
    RAISE NOTICE '%', format('CREATE ROLE %s CREATEDB CREATEROLE NOLOGIN REPLICATION BYPASSRLS;', v_adminrole);
    RAISE NOTICE '%', format('GRANT CONNECT ON DATABASE %s TO %s;', v_databasename, v_adminrole);
    RAISE NOTICE '%', format('GRANT USAGE, CREATE ON SCHEMA public TO %s;', v_adminrole);
    RAISE NOTICE '%', format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO %s;', v_adminrole);
    RAISE NOTICE '%', format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO %s;', v_adminrole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO %s;', v_adminrole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO %s;', v_adminrole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO %s;', v_adminrole);
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', format('CREATE ROLE %s NOLOGIN;',v_readwriterole);
    RAISE NOTICE '%', format('GRANT CONNECT ON DATABASE %s TO %s;',v_databasename, v_readwriterole);
    RAISE NOTICE '%', format('GRANT USAGE ON SCHEMA public TO %s;',v_readwriterole);
    RAISE NOTICE '%', format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %s;',v_readwriterole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO %s;',v_readwriterole);
    RAISE NOTICE '%', format('GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO %s;',v_readwriterole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO %s;',v_readwriterole);
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', format('CREATE ROLE %s NOLOGIN;',v_readonlyrole);
    RAISE NOTICE '%', format('GRANT CONNECT ON DATABASE %s TO %s;',v_databasename, v_readonlyrole);
    RAISE NOTICE '%', format('GRANT USAGE ON SCHEMA public TO %s;',v_readonlyrole);
    RAISE NOTICE '%', format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %s;',v_readonlyrole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %s;',v_readonlyrole);
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', format('CREATE USER harsha LOGIN INHERIT ENCRYPTED PASSWORD ***** IN ROLE %s;', v_adminrole);
    RAISE NOTICE '%', format('ALTER ROLE harsha IN DATABASE %s SET ROLE %s;', v_databasename, v_adminrole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO %s;', v_readwriterole);
    RAISE NOTICE '%', format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %s;', v_readwriterole);
    RAISE NOTICE '%', format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %s;', v_readonlyrole);
    RAISE NOTICE '%', format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %s;', v_readonlyrole);
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', '';
    RAISE NOTICE '%', format('INSERT INTO user_passwords VALUES (%L, %L,%L,%L,%L,%L,%L,%L);',v_databasename, v_env, 'harsha', 'dZdAZrDzlWi3TYp', v_adminrole, v_databasename, v_serverip, 'PG' );
    RAISE NOTICE '%', format('INSERT INTO user_passwords VALUES (%L, %L,%L,%L,%L,%L,%L,%L);',v_databasename, v_env, 'strimmgcp_'||v_databasename, '3DnLuNtWym5BtRsazsf3', v_adminrole, v_databasename, v_serverip, 'PG' );
    RAISE NOTICE '%', format('INSERT INTO user_passwords VALUES (%L, %L,%L,%s,%L,%L,%L,%L);',v_databasename, v_env,  v_databasename||'_rw', ''''||random_string(20)||'''', v_readwriterole, v_databasename, v_serverip, 'PG' );
    RAISE NOTICE '%', format('INSERT INTO user_passwords VALUES (%L, %L,%L,%s,%L,%L,%L,%L)',v_databasename, v_env,  v_databasename||'_ro', ''''||random_string(20)||'''', v_readonlyrole, v_databasename, v_serverip, 'PG' );
    RAISE NOTICE '%', format('CREATE USER %s_rw LOGIN INHERIT ENCRYPTED PASSWORD ***** IN ROLE %s;', v_databasename, v_readwriterole);
    RAISE NOTICE '%', format('CREATE USER %s_ro LOGIN INHERIT ENCRYPTED PASSWORD ***** IN ROLE %s;', v_databasename, v_readonlyrole);
END;
$$
language 'plpgsql'
