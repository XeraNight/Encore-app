-- KSIS cannot be read from the server (Cloudflare lets only browsers in, docs/KSIS_SAMPLES_NEEDED.md §1) and the
-- ksis-sync function these jobs call was never deployed: the morning job called a missing function every day and
-- the live job checked the database every 2 minutes for nothing. The tables stay for when SZTŠ allows our server.
-- KSIS keeps working from the phone (the in-app KSIS browser and ksis-page).
select cron.unschedule('ksis-daily');
select cron.unschedule('ksis-live');
select cron.unschedule('ksis-cleanup');
delete from cron.job_run_details where jobid not in (select jobid from cron.job);
