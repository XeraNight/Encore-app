# SQL na schválenie (balík E), 24. 11. 2026

**Nič z tohto nebolo spustené.** Každý blok je samostatný súbor v `supabase/migrations/`, ktorý vytvorím až po tvojom "áno" a spustím cez Supabase,
jeden po druhom, s kontrolou po každom.

| # | Čo | Povinné? | Poradie |
|---|---|---|---|
| 1 | Nový druh záznamu `figure_notes` (hlasovky vo figúrach na novom iPhone) | áno, **pred buildom**, ktorý to posiela | prvý |
| 2 | Limity veľkosti: jeden používateľ nezaplní databázu | áno (Free plán má 500 MB) | kedykoľvek |
| 3 | Bucket `encore-media`: zákaz nahrávania | áno (Free úložisko má 1 GB) | kedykoľvek |
| 4 | Starý 4-miestny Dancer ID jedného účtu | nie, tvoje rozhodnutie | kedykoľvek |

## Overené na kópii databázy (Postgres 17, rovnaká verzia ako produkcia)

Kópia mala tie isté tabuľky, kľúče, CHECK-y a denné limity ako produkcia. Výsledky:

- 100 malých záznamov naraz, potom ich úprava, potom zmiešané odoslanie nových a existujúcich (to posiela záloha): prejde.
- Záznamy po 60 KB: odmietne sa až ten, ktorý by prekročil 10 MB (174 záznamov = 10,4 MB), s kódom `storage_budget`.
- Po zmazaní veľkých záznamov sa zase dá zapisovať. Iný používateľ tým nie je dotknutý.
- Riadok nad 64 KB sa odmietne v `routines`, `canvas_nodes` aj `figure_library_items` (`row_too_large`), normálny prejde.
- Partner, ktorý píše do zostavy majiteľa, sa počíta do limitu majiteľa (zostava s 262 figúrami po 40 KB zastavila ďalší zápis aj partnerovi).
- Knižnica: zastavenie po 5 MB (174 figúr po 30 KB).
- Rýchlosť: záloha 100 záznamov pri 6 000 uložených trvá 8 ms namiesto 4 ms, úprava 20 figúr pri 5 000 figúrach majiteľa 7 ms namiesto 1,5 ms.
- Migrácia sa dá spustiť aj druhýkrát bez chyby.
- Namerané v produkcii dnes: najväčší riadok má 700 bajtov, najväčšie uložené hodnotenie rozhodcov (kolá) 17 KB, takže nič existujúce limity neporuší.

## Blok 1: `figure_notes`

```sql
-- Záloha formátovaných poznámok figúr (hlasovky vo figúrach na novom iPhone): nový druh záznamu v zálohe denníka.
alter table public.device_records drop constraint device_records_kind_check;
alter table public.device_records add constraint device_records_kind_check
  check (kind in ('training_log', 'planned_session', 'planned_competition',
                  'training_cadence', 'lesson_priority', 'instant_note', 'figure_notes'));
```

iPhone s novým buildom začne tieto poznámky posielať hneď. Bez tohto SQL tie dávky zlyhajú, preto ho treba spustiť pred buildom. Záloha denníka
ide pred nimi a vo vlastných dávkach, takže sa pri takej chybe nezastaví.

## Blok 2: limity veľkosti

Prečo: cez verejné API vie prihlásený používateľ zapísať riadky ľubovoľnej veľkosti do `canvas_nodes`, `figure_library_items`,
`routines`, `profiles` a `invite_tokens` a 5 000 nových riadkov po 64 KB denne do `device_records`. Skript naplní 500 MB Free databázy
za pár minút a projekt sa pre všetkých prepne len na čítanie.

```sql
-- Budgets: one signed-in user can no longer fill the Free database.
--
-- Until now a user could write rows of any size through the public API into canvas_nodes, figure_library_items,
-- routines, profiles and invite_tokens (text columns without a limit), and 5 000 new rows of 64 KB a day into
-- device_records. A script could fill the 500 MB of the Free plan in minutes, and the whole project would go
-- read-only for everybody. What the app writes is far below these numbers (the biggest row today is 700 bytes, a
-- dancer's whole diary backup is about 1 MB after years).
--
-- 1. no row is bigger than 64 KB, like device_records already;
-- 2. one user's rows of device_records, canvas_nodes (of his routines) and figure_library_items together stay under
--    10, 10 and 5 MB;
-- 3. the figures a user adds to the library are limited per day like the other writes.
-- A write over a limit is refused with the hint 'row_too_large' or 'storage_budget'. Deleting data frees the budget
-- again, nothing already stored is touched, and the app's data stays on the iPhone and is sent again.

-- Indexes: the budgets and the row-level security policies look rows up by owner, and these tables had no index for it.
create index if not exists routines_user_id_idx on public.routines (user_id);
create index if not exists canvas_nodes_routine_id_idx on public.canvas_nodes (routine_id);
create index if not exists figure_library_items_user_id_idx on public.figure_library_items (user_id);

-- 1. One row, at most 64 KB.
create or replace function public.refuse_oversized_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if pg_column_size(new) > 65536 then
    raise exception 'Row too large' using errcode = '54000', hint = 'row_too_large';
  end if;
  return new;
end;
$$;

create or replace trigger profiles_row_size before insert or update on public.profiles
  for each row execute function public.refuse_oversized_row();
create or replace trigger routines_row_size before insert or update on public.routines
  for each row execute function public.refuse_oversized_row();
create or replace trigger canvas_nodes_row_size before insert or update on public.canvas_nodes
  for each row execute function public.refuse_oversized_row();
create or replace trigger figure_library_items_row_size before insert or update on public.figure_library_items
  for each row execute function public.refuse_oversized_row();
create or replace trigger invite_tokens_row_size before insert or update on public.invite_tokens
  for each row execute function public.refuse_oversized_row();
create or replace trigger guest_coach_keys_row_size before insert or update on public.guest_coach_keys
  for each row execute function public.refuse_oversized_row();

-- 2. One user's rows together. Checked once at the end of a statement for the users it touched (a backup sends up to
--    a hundred rows in one), from what is really stored, so there is no counter that could drift.
create or replace function public.enforce_storage_budget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cap bigint := tg_argv[0]::bigint;
  v_over boolean;
begin
  if tg_table_name = 'device_records' then
    select exists (
      select 1 from public.device_records d
      where d.user_id in (select user_id from changed)
      group by d.user_id
      having sum(pg_column_size(d.payload)) > v_cap
    ) into v_over;
  elsif tg_table_name = 'canvas_nodes' then
    select exists (
      select 1 from public.canvas_nodes n join public.routines r on r.id = n.routine_id
      where r.user_id in (select r2.user_id from changed c join public.routines r2 on r2.id = c.routine_id)
      group by r.user_id
      having sum(octet_length(n.figure_name) + octet_length(n.rhythm) + octet_length(n.notes)
                 + octet_length(n.transition_notes) + coalesce(octet_length(n.coach_notes), 0)) > v_cap
    ) into v_over;
  else
    select exists (
      select 1 from public.figure_library_items f
      where f.user_id in (select user_id from changed)
      group by f.user_id
      having sum(octet_length(f.name) + octet_length(f.dance_name) + octet_length(f.rhythm) + octet_length(f.technique_notes)
                 + coalesce(octet_length(f.image_path), 0) + coalesce(octet_length(f.video_path), 0)) > v_cap
    ) into v_over;
  end if;
  if v_over then
    raise exception 'Storage budget exceeded' using errcode = '54000', hint = 'storage_budget';
  end if;
  return null;
end;
$$;

create or replace trigger device_records_budget_insert after insert on public.device_records
  referencing new table as changed for each statement execute function public.enforce_storage_budget('10485760');
create or replace trigger device_records_budget_update after update on public.device_records
  referencing new table as changed for each statement execute function public.enforce_storage_budget('10485760');
create or replace trigger canvas_nodes_budget_insert after insert on public.canvas_nodes
  referencing new table as changed for each statement execute function public.enforce_storage_budget('10485760');
create or replace trigger canvas_nodes_budget_update after update on public.canvas_nodes
  referencing new table as changed for each statement execute function public.enforce_storage_budget('10485760');
create or replace trigger figure_library_items_budget_insert after insert on public.figure_library_items
  referencing new table as changed for each statement execute function public.enforce_storage_budget('5242880');
create or replace trigger figure_library_items_budget_update after update on public.figure_library_items
  referencing new table as changed for each statement execute function public.enforce_storage_budget('5242880');

-- 3. The other tables already limit new rows a day; the library had no limit.
create or replace trigger figure_library_items_rate_limit before insert on public.figure_library_items
  for each row execute function public.limit_writes('library_figure_write', '2000', '1 day');
```

## Blok 3: bucket `encore-media` (Supabase Storage)

Appka do tohto bucketu nič nenahráva (videá a hlasovky idú do Cloudflare R2 cez `media-share`). Zostanú 4 staré súbory (3,9 MB),
čítať a mazať ich dá ďalej. Kód appky aj serverov som prezrel, `web/` som nečítal (je to časť Antigravity).

```sql
-- encore-media (Supabase Storage): nothing uploads here any more.
--
-- The app keeps videos on the iPhone and, for sharing, in Cloudflare R2 through the media-share function; it never
-- writes to this bucket. Its policies still let every signed-in user put 100 MB files into his own folder until the
-- 1 GB of Free Storage is full. Without insert and update nothing new can come in; reading and deleting what is
-- already there stays as it was, and the server code (account deletion, data export) uses the service role.
drop policy if exists encore_media_insert on storage.objects;
drop policy if exists encore_media_update on storage.objects;
```

## Blok 4 (voliteľný): starý Dancer ID

```sql
-- Jediný starý účet má 4-miestny kód (DNC-1234). Nový kód má 6 miest ako všetky ostatné.
update public.profiles set dancer_code = public.generate_dancer_code() where dancer_code !~ '^DNC-[0-9]{6}$';
```

Zmení sa číslo na členskej karte toho jedného účtu. Staré 4-miestne číslo sa dá uhádnuť (10 000 možností) a podľa neho nájsť meno, klub a fotku
aj pri mladšom ako 17 rokov. Ostatné kódy majú 900 000 možností a hľadanie je obmedzené na 120 za 10 minút.

## Súbor, ktorý v repozitári chýba (nič sa nespúšťa)

Produkcia má migráciu `20261006141225 canvas_coach_notes_author_name` (stĺpec `canvas_nodes.coach_notes_by_name`), ktorú repozitár nemá, a neskoršia
`20261022_canvas_node_bars.sql` ho používa. Kto by databázu stavial z repozitára, narazí. Po tvojom "áno" pridám súbor
`20261007b_canvas_coach_notes_author_name.sql` s presným textom, ktorý už v produkcii je.

## Servery (Edge Functions): zmeny sú v repozitári, v Supabase NIE SÚ

| Funkcia | Čo sa zmenilo | Commit |
|---|---|---|
| `ksis-page` | uloženie jednej súťaže má rovnaký strop 2 000 ako stránka páru; uložené hodnotenie porotcov nad 64 KB (rozhodcovia nad 16 KB) sa odmietne | 7ce1a58 |
| `media-share` | 300 volaní denne na video a 3 000 na hlasovky; funkcie majú 500 000 volaní mesačne pre všetkých | f037bab |
| `delete-account` a `owner-delete-account` | súbory v R2 sa mažú po desiatich naraz (tisíc hlasoviek za sebou by funkcia nestihla a účet by sa nedal zmazať), meno trénera sa zmaže z poznámok figúr | e13404a |
| `owner-delete-account` | pokusy o PIN sa počítajú atomicky pred porovnaním (päť za hodinu, správny PIN ich vráti) | 885cab0 |

Nasadenie spravím až na tvoje "nasaď": cez Supabase po jednej funkcii, s kontrolou logu po každej.
