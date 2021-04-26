/*
  How to read refcursor data
  rpt_rentroll has return value as refcursor
  create table with columns as returns from refcursor
*/



DO $$
  DECLARE
   c refcursor;
   a_row record;
BEGIN
	truncate table xxy;
   FOR c IN
      select * FROM rpt_rentroll(1 :: character varying,114974 ,'04/24/2021' :: character varying,0)
     LOOP
     	LOOP
         FETCH c INTO a_row;
       EXIT WHEN NOT FOUND;
     --  RAISE NOTICE '%,%,%,%,%,%,%', a_row.propcode, a_row.propfp, a_row.unittype, a_row.propunit, a_row.propbldg,a_row.leasetype,a_row.effrentwop;
    --  INSERT INTO xxy VALUES (a_row.propcode, a_row.propfp, a_row.unittype, a_row.propbldg,a_row.propunit,null,a_row.effrentwop :: int,a_row.leasetype, a_row.status);
      INSERT INTO xxy VALUES( a_row.propcode,a_row.propfp,a_row.unittype,a_row.propbldg,a_row.propunit,a_row.tenant,a_row.fpulkey,a_row.propname,
      						 a_row.appdate,a_row.leasesigned,a_row.leasestart,a_row.leaseend,a_row.noticedate,a_row.noticemoveout,a_row.actleaseend,
      						 a_row.actmoveout,a_row.term,a_row.rent,a_row.conc,a_row.effrentwop,a_row.stprem,a_row.unitamen,a_row.renewal,a_row.transfer,
      						 a_row.renguar,a_row.leasetype,a_row.status,a_row.leasetypeid,a_row.leaseout,a_row.poleaseout,a_row.ltypedesc,a_row.resultset);
   END LOOP;
  END LOOP;
END;   
 $$
 language 'plpgsql'