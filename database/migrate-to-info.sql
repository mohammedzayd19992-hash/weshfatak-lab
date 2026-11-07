-- WeshFatak 1.6.0: the Info page answers what people ask. Run once after migrate-to-institutions.sql
-- (Supabase dashboard -> SQL Editor -> paste this file -> Run). It only adds: two tables, one save
-- function and their security rules. Builds up to 1.5.0 keep reading institution_stats as before.
--
-- In the 257 different replies collected under the Ministry's and Shaqra University's posts in
-- October 2026, people asked whether study was suspended or moved online (40), about exams,
-- holidays and dates (24), how to reach someone (22) and about the apps (15). None asked about
-- the statistics. So the Info page now has, most asked first:
--   status   is study suspended, online or back in person: the newest official posts and press
--            reports about it, with their links
--   dates    the coming dates of the academic calendar, each with its source
--   help     where to ask: the official channels that answer, each with its source
--   apps     the apps' ratings and what their users write (institution_stats, public_reviews)
--   numbers  the statistics (institution_stats), always last
-- collector/info.py works the order out from the replies of the last 30 days and rewrites each
-- section on every run of collector/autopilot.py.

-- =====================================================================
-- 1. Tables
-- =====================================================================

create table public.info_sections (
  organization_id bigint  not null references public.organizations (organization_id) on delete cascade,
  kind            text    not null check (kind in ('status', 'dates', 'help', 'apps', 'numbers')),
  position        integer not null,                               -- 1 is shown first
  asked           integer not null default 0 check (asked >= 0),  -- replies of the last 30 days asking about it
  note            text,                                           -- one line under the title, in Arabic
  checked_at      timestamptz not null default now(),             -- when info.py last rewrote it
  primary key (organization_id, kind)
);

create table public.info_items (
  item_id         bigint generated always as identity primary key,
  organization_id bigint  not null,
  kind            text    not null check (kind in ('status', 'dates', 'help')),
  title           text    not null check (length(trim(title)) between 1 and 400), -- in Arabic
  detail          text,
  starts_on       date,                 -- dates: the day it starts
  ends_on         date,                 -- dates: the last day, when it lasts more than one
  published_at    timestamptz,          -- status: when the post or report was published
  link            text check (link ~ '^(https://|tel:|mailto:)'),
  source_name     text    not null,
  source_url      text    not null check (source_url ~ '^https://'),
  position        integer not null default 100,
  foreign key (organization_id, kind) references public.info_sections (organization_id, kind) on delete cascade,
  check (kind <> 'dates' or starts_on is not null),
  check (ends_on is null or ends_on >= starts_on)
);

create index info_items_section_idx on public.info_items (organization_id, kind, position);

-- =====================================================================
-- 2. How info.py saves
-- =====================================================================
-- One section of one institution:
--   {"organization": "Shaqra University", "kind": "dates", "position": 2, "asked": 16,
--    "note": "...", "items": [{"title": "...", "starts_on": "2026-11-22", ...}]}
-- The items replace the section's old ones. Without "items" (apps, numbers) only the place and
-- the count change.

create function public.save_info_section(p_section jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_org_id bigint;
  v_kind   text := p_section ->> 'kind';
begin
  select organization_id into v_org_id from public.organizations where name = p_section ->> 'organization';
  if v_org_id is null then
    raise exception 'No institution named %', p_section ->> 'organization';
  end if;

  insert into public.info_sections (organization_id, kind, position, asked, note, checked_at)
  values (v_org_id, v_kind, (p_section ->> 'position')::integer,
          coalesce((p_section ->> 'asked')::integer, 0), nullif(trim(p_section ->> 'note'), ''), now())
  on conflict (organization_id, kind) do update set
    position = excluded.position, asked = excluded.asked, note = excluded.note, checked_at = excluded.checked_at;

  if p_section ? 'items' then
    delete from public.info_items where organization_id = v_org_id and kind = v_kind;
    insert into public.info_items (organization_id, kind, title, detail, starts_on, ends_on, published_at,
                                   link, source_name, source_url, position)
    select v_org_id, v_kind, i ->> 'title', nullif(trim(i ->> 'detail'), ''), (i ->> 'starts_on')::date,
           (i ->> 'ends_on')::date, (i ->> 'published_at')::timestamptz, i ->> 'link',
           i ->> 'source_name', i ->> 'source_url', n::integer
    from jsonb_array_elements(coalesce(p_section -> 'items', '[]')) with ordinality as t (i, n);
  end if;
end;
$$;

-- =====================================================================
-- 3. Security: everyone can read; only the collectors (secret key) write
-- =====================================================================

alter table public.info_sections enable row level security;
alter table public.info_items    enable row level security;

revoke all on public.info_sections, public.info_items from anon, authenticated;
grant select on public.info_sections, public.info_items to anon, authenticated;

create policy "Anyone can read info sections" on public.info_sections for select to anon, authenticated using (true);
create policy "Anyone can read info items"    on public.info_items    for select to anon, authenticated using (true);

revoke execute on function public.save_info_section(jsonb) from public, anon, authenticated;
grant execute on function public.save_info_section(jsonb) to service_role;
