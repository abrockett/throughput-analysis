WITH
POIDS as (
  select oid from ALM_SCOPE where name = 'Mr. Rogers'
  --select oid from QUERY_OIDS_TMP where workspace_oid = ? and oid_type = 1 and request_id = ?
),
WORKSPACE as (
  select oid from alm_scope where subclass_type = 'W' and oid = 41529001
),
STATES as (
  select * from ALM_STATE where workspace_oid in (select oid from WORKSPACE) and subclass_type = 'S'
),
FARTIFACTS as (
  select a.oid,a.parent_oid,a.project_oid,a.formatted_id_oid,j.state_oid,a.workproduct_oid,a.subclass_type,j.accepted_date from ALM_ARTIFACT a
  join ALM_ARTIFACT j on j.workproduct_oid = a.oid
  join states s on j.state_oid = s.oid
  WHERE a.workspace_oid in (select oid from WORKSPACE) and a.project_oid in (select oid from POIDS) and a.subclass_type in (/*ts*/'G','D'/*te*/) and a.is_deleted = 0
  and j.accepted_date >= trunc(add_months(sysdate,-12),'MONTH') and j.accepted_date < trunc(sysdate,'MONTH')
  and s.order_index >= 4
),
RANGE AS (
  select trunc(add_months(sysdate,-12),'MONTH') as start_date, trunc(sysdate,'MONTH')-1 as end_date from dual
),
DAYS AS (
  SELECT R.start_date + (rownum - 1) creation_date FROM DUAL, RANGE R CONNECT BY LEVEL <= R.end_date - R.start_date + 1
),
OIDS as (select oid from FARTIFACTS where subclass_type = 'G'),
OUT_OF_SCOPE_PARENT_OIDS as (select parent_oid from FARTIFACTS f where subclass_type = 'G' and not exists ( select 1 from OIDS o where o.oid = f.parent_oid ) and parent_oid is not null),
ARTIFACTS as ( 
select * from FARTIFACTS WHERE connect_by_isleaf = 1 start with parent_oid in (select parent_oid from OUT_OF_SCOPE_PARENT_OIDS) or parent_oid is null connect by prior oid = parent_oid 
),
FILTERED as (
 select a.* from ARTIFACTS a 
),
ACCEPTED as (
  select a.parent_oid, a.oid, a.subclass_type, concat(id.prefix,concat(f.id,id.suffix)) as formatted_id, a.accepted_date from FILTERED a 
  join alm_formatted_id f on a.formatted_id_oid = f.oid
  join alm_id_format id on f.id_format_oid = id.oid
)
SELECT creation_date, subclass_type, TYPE, formatted_id
  FROM (SELECT creation_date, subclass_type, TYPE, formatted_id, LAG ( creation_date, 1, creation_date) OVER (ORDER BY creation_date) AS date_lag, LAG ( subclass_type, 1, subclass_type) OVER (ORDER BY creation_date) AS subclass_type_lag 
          FROM (SELECT d.creation_date, a.subclass_type, DECODE (a.subclass_type,  'D', 'Defects',  'G', 'Stories',  NULL) AS TYPE, a.formatted_id
                  FROM days d JOIN ACCEPTED a ON d.creation_date = TRUNC (a.accepted_date)
                UNION
                SELECT creation_date, NULL, NULL, NULL
                  FROM days) ORDER BY creation_date, subclass_type NULLS LAST)
 WHERE subclass_type_lag IS NULL OR subclass_type IS NOT NULL