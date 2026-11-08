-- Where a competition took place, as KSIS writes it in "Miesto:" on the results and marks pages (a hall and its
-- town). The app takes the town from it for the map of where a couple danced. No personal data; the existing RLS
-- policies of competition_results cover the new column.
alter table public.competition_results add column if not exists venue text;
