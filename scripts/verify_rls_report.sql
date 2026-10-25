-- Returns a table of test results for display
select 
    c.table_name,
    c.row_security,
    c.policies_count,
    c.anon_can_insert,
    c.anon_can_update,
    c.anon_can_delete,
    c.auth_can_insert,
    c.auth_can_update,
    c.auth_can_delete
from (
    select 
        t.tablename as table_name,
        t.rowsecurity as row_security,
        count(p.policyname) as policies_count,
        has_table_privilege('anon', 'public.' || t.tablename, 'INSERT') as anon_can_insert,
        has_table_privilege('anon', 'public.' || t.tablename, 'UPDATE') as anon_can_update,
        has_table_privilege('anon', 'public.' || t.tablename, 'DELETE') as anon_can_delete,
        has_table_privilege('authenticated', 'public.' || t.tablename, 'INSERT') as auth_can_insert,
        has_table_privilege('authenticated', 'public.' || t.tablename, 'UPDATE') as auth_can_update,
        has_table_privilege('authenticated', 'public.' || t.tablename, 'DELETE') as auth_can_delete
    from pg_tables t
    left join pg_policies p on p.schemaname = t.schemaname and p.tablename = t.tablename
    where t.schemaname = 'public' and t.tablename in ('user_couples', 'competition_results', 'ksis_dancers', 'import_cooldowns')
    group by t.tablename, t.rowsecurity
) c
order by c.table_name;
