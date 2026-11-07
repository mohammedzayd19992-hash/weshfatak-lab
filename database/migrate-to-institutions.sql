-- Moves WeshFatak from one ministry feed to institution pages (applied to the live project as the
-- migration institutions_opinions_stats). Each institution gets:
--   - its news from every source the source protocol found (PROTOCOL.md), not only X
--   - a mood chart of what people said: an emotion on every reply and app store review
--   - a page of statistics, each number with its period and source
-- Accounts, comments and tags are no longer used by the app. Their tables stay for now, so the
-- 1.3 app keeps working until phones update; nothing here removes data.
--
-- 1. Institutions: Arabic name, kind, city, founding year, logo, description, order
-- 2. Sources: platform, role (news / opinions / stats), status (collected / planned / manual /
--    unavailable) and a note, so every channel found is recorded, even ones without a collector yet
-- 3. Opinions: an emotion on every reply, app store reviews, one pulse per institution
-- 4. Statistics
-- 5. What the app reads: news_cards gains organization_id and emotions, institution_cards,
--    review_cards, institution_feed_page
-- 6. How the collectors save: import_post (any source), import_review, save_community_note
--    (now with emotions; tags only when sent), save_institution_pulse, save_institution_stat
-- 7. Security
-- 8. Shaqra University comes back with its sources and archived news; the ministry gets its
--    other channels

-- =====================================================================
-- 1. Institutions
-- =====================================================================

alter table public.organizations
  add column name_ar      text check (length(trim(name_ar)) between 1 and 120),
  add column kind         text not null default 'university' check (kind in ('ministry', 'university', 'college')),
  add column city         text,
  add column founded_year integer check (founded_year between 1900 and 2100),
  add column logo_url     text check (logo_url ~ '^https://'),
  add column about        text, -- one or two sentences in Arabic
  add column position     integer not null default 100; -- order on the home screen

-- =====================================================================
-- 2. Sources
-- =====================================================================

alter table public.sources drop constraint sources_source_type_check;
alter table public.sources add constraint sources_source_type_check
  check (source_type in ('website', 'rss', 'social', 'app', 'open_data'));

alter table public.sources
  add column platform text not null default 'website' check (platform in (
    'website', 'rss', 'x', 'instagram', 'snapchat', 'tiktok', 'youtube', 'linkedin',
    'telegram', 'whatsapp', 'app_store', 'google_play', 'open_data', 'media')),
  add column role     text not null default 'news' check (role in ('news', 'opinions', 'stats')),
  add column status   text not null default 'collected' check (status in ('collected', 'planned', 'manual', 'unavailable')),
  add column note     text; -- how it was found or why it is not collected yet

update public.sources set platform = 'x' where url like 'https://x.com/%';

-- =====================================================================
-- 3. Opinions
-- =====================================================================
-- The seven faces of the mood chart (PROTOCOL.md, "Reading opinions"):
--   happy, neutral, asking, worried, angry, sad, sarcastic

alter table public.public_replies
  add column emotion text check (emotion in ('happy', 'neutral', 'asking', 'worried', 'angry', 'sad', 'sarcastic'));

-- Written reviews of an institution's official apps. Like replies, never who wrote them.
create table public.public_reviews (
  review_id    bigint generated always as identity primary key,
  source_id    bigint not null references public.sources (source_id) on delete cascade,
  external_id  text not null, -- the review's id in the store, so it is never saved twice
  title        text,
  body         text not null check (length(trim(body)) > 0),
  rating       smallint not null check (rating between 1 and 5),
  app_version  text,
  posted_at    timestamptz not null,
  emotion      text check (emotion in ('happy', 'neutral', 'asking', 'worried', 'angry', 'sad', 'sarcastic')),
  collected_at timestamptz not null default now(),
  unique (source_id, external_id)
);

create index public_reviews_source_idx on public.public_reviews (source_id, posted_at desc);
create index public_replies_news_idx   on public.public_replies (news_id);

-- What people are saying about an institution lately, written by Claude from its post notes and
-- app reviews: one call per institution per run.
create table public.institution_pulse (
  organization_id bigint primary key references public.organizations (organization_id) on delete cascade,
  summary         text not null check (length(trim(summary)) > 0),
  key_points      text[] not null default '{}',
  opinions_read   integer not null check (opinions_read > 0),
  since           timestamptz not null, -- the oldest opinion it read
  model           text not null,
  generated_at    timestamptz not null default now()
);

-- =====================================================================
-- 4. Statistics
-- =====================================================================

create table public.institution_stats (
  stat_id         bigint generated always as identity primary key,
  organization_id bigint not null references public.organizations (organization_id) on delete cascade,
  section         text not null check (section in ('people', 'study', 'digital', 'research')),
  label           text not null check (length(trim(label)) between 1 and 120), -- in Arabic
  value           numeric not null,
  unit            text, -- '%' or '/5'; null for a count
  period          text not null, -- '1445هـ', '2025'
  breakdown       jsonb not null default '[]', -- [{"label": "...", "value": 12}] drawn as bars
  source_name     text not null,
  source_url      text not null check (source_url ~ '^https://'),
  position        integer not null default 100,
  collected_at    timestamptz not null default now(),
  unique (organization_id, label)
);

create index institution_stats_org_idx on public.institution_stats (organization_id, section, position);

-- =====================================================================
-- 5. What the app reads
-- =====================================================================

-- {"happy": 3, "angry": 1}: how many opinions show each face (unlabeled ones are left out).
create function public.emotion_counts(p_emotions text[])
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e, n), '{}'::jsonb)
  from (select e, count(*) as n from unnest(p_emotions) as e where e is not null group by e) t;
$$;

-- The same columns as before, then the institution and the mood of the replies.
create or replace view public.news_cards
with (security_invoker = true) as
select
  n.news_id,
  n.body,
  coalesce(n.published_at, n.collected_at) as published_at,
  n.source_url,
  s.source_id,
  s.name        as source_name,
  s.handle,
  s.source_type,
  s.avatar_url,
  o.name        as organization,
  array(select t.name from public.news_tags nt join public.tags t on t.tag_id = nt.tag_id
        where nt.news_id = n.news_id and t.tag_group = 'audience' order by t.tag_id) as audience,
  array(select t.name from public.news_tags nt join public.tags t on t.tag_id = nt.tag_id
        where nt.news_id = n.news_id and t.tag_group = 'category' order by t.tag_id) as category,
  coalesce((select jsonb_agg(jsonb_build_object('url', m.url, 'alt', m.alt_text,
                                                'width', m.width, 'height', m.height) order by m.position)
            from public.news_media m where m.news_id = n.news_id), '[]'::jsonb) as media,
  (select count(*) from public.comments c where c.news_id = n.news_id)::integer as comment_count,
  (select count(*) from public.public_replies r where r.news_id = n.news_id)::integer as reply_count,
  (select jsonb_build_object('summary', cn.summary, 'key_points', cn.key_points,
                             'replies_read', cn.replies_read, 'model', cn.model,
                             'generated_at', cn.generated_at)
   from public.community_notes cn where cn.news_id = n.news_id) as community_note, -- null until written
  o.organization_id,
  public.emotion_counts(array(select r.emotion from public.public_replies r where r.news_id = n.news_id)) as emotions,
  s.platform
from public.news_items n
join public.sources s on s.source_id = n.source_id
join public.organizations o on o.organization_id = s.organization_id;

-- One card per institution for the home screen and the top of its page.
create view public.institution_cards
with (security_invoker = true) as
select
  o.organization_id,
  o.name,
  o.name_ar,
  o.kind,
  o.city,
  o.founded_year,
  o.website_url,
  o.about,
  o.position,
  coalesce(o.logo_url, (select s.avatar_url from public.sources s
                        where s.organization_id = o.organization_id and s.avatar_url is not null
                        order by s.source_id limit 1)) as logo_url,
  (select count(*) from public.news_items n join public.sources s on s.source_id = n.source_id
   where s.organization_id = o.organization_id)::integer as post_count,
  (select max(coalesce(n.published_at, n.collected_at)) from public.news_items n
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id) as last_post_at,
  (select count(*) from public.sources s where s.organization_id = o.organization_id)::integer as source_count,
  (select count(*) from public.institution_stats st where st.organization_id = o.organization_id)::integer as stat_count,
  public.emotion_counts(array(
    select r.emotion from public.public_replies r
    join public.news_items n on n.news_id = r.news_id
    join public.sources s on s.source_id = n.source_id
    where s.organization_id = o.organization_id
    union all
    select v.emotion from public.public_reviews v
    join public.sources s on s.source_id = v.source_id
    where s.organization_id = o.organization_id)) as emotions,
  (select count(*) from public.public_replies r join public.news_items n on n.news_id = r.news_id
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id)::integer as reply_count,
  (select count(*) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id)::integer as review_count,
  (select round(avg(v.rating), 2) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id) as review_rating,
  (select jsonb_build_object('summary', p.summary, 'key_points', p.key_points,
                             'opinions_read', p.opinions_read, 'since', p.since,
                             'model', p.model, 'generated_at', p.generated_at)
   from public.institution_pulse p where p.organization_id = o.organization_id) as pulse -- null until written
from public.organizations o;

-- App store reviews with the app they are about.
create view public.review_cards
with (security_invoker = true) as
select v.review_id, v.title, v.body, v.rating, v.app_version, v.posted_at, v.emotion,
       s.source_id, s.name as app_name, s.url as app_url, s.organization_id
from public.public_reviews v
join public.sources s on s.source_id = v.source_id;

-- One page of an institution's news, newest first.
create function public.institution_feed_page(
  p_organization_id bigint,
  p_limit           integer default 10,
  p_offset          integer default 0
)
returns setof public.news_cards
language sql
stable
security invoker
set search_path = ''
as $$
  select c.*
  from public.news_cards c
  where c.organization_id = p_organization_id
  order by c.published_at desc, c.news_id desc
  limit least(greatest(coalesce(p_limit, 10), 1), 30)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- =====================================================================
-- 6. How the collectors save
-- =====================================================================

-- Saves a post from any source with its images and replies. The source is found by its address
-- ("source") or, for X, by its handle. Running it again updates the text and like counts and adds
-- new replies, without making copies.
create function public.import_post(p_post jsonb)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_source_id bigint;
  v_news_id   bigint;
begin
  select source_id into v_source_id
  from public.sources
  where url = p_post ->> 'source' or lower(handle) = lower(p_post ->> 'handle')
  order by (url = p_post ->> 'source') desc nulls last
  limit 1;
  if v_source_id is null then
    raise exception 'No source with the address % or handle %', p_post ->> 'source', p_post ->> 'handle';
  end if;
  if p_post ->> 'avatar_url' is not null then
    update public.sources set avatar_url = p_post ->> 'avatar_url' where source_id = v_source_id;
  end if;

  insert into public.news_items (source_id, source_url, body, published_at)
  values (v_source_id, p_post ->> 'url', p_post ->> 'text', (p_post ->> 'posted_at')::timestamptz)
  on conflict (source_url) do update set body = excluded.body, published_at = excluded.published_at
  returning news_id into v_news_id;

  if p_post ? 'images' then
    delete from public.news_media where news_id = v_news_id;
    insert into public.news_media (news_id, url, alt_text, position, width, height)
    select v_news_id, m ->> 'url', m ->> 'alt', (i - 1)::integer,
           (m ->> 'width')::integer, (m ->> 'height')::integer
    from jsonb_array_elements(p_post -> 'images') with ordinality as t (m, i);
  end if;

  insert into public.public_replies (news_id, external_id, body, posted_at, like_count)
  select v_news_id, r ->> 'id', r ->> 'text', (r ->> 'posted_at')::timestamptz,
         coalesce((r ->> 'likes')::integer, 0)
  from jsonb_array_elements(coalesce(p_post -> 'replies', '[]')) as t (r)
  on conflict (news_id, external_id) do update set like_count = excluded.like_count;

  return v_news_id;
end;
$$;

-- The X collector's name for the same thing (collector/collect.py).
create or replace function public.import_x_post(p_post jsonb)
returns bigint
language sql
set search_path = ''
as $$
  select public.import_post(p_post);
$$;

-- Saves an app store review (collector/reviews.py). The source is found by the app's store address.
create function public.import_review(p_review jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_source_id bigint;
begin
  select source_id into v_source_id from public.sources where url = p_review ->> 'source';
  if v_source_id is null then
    raise exception 'No source with the address %', p_review ->> 'source';
  end if;
  insert into public.public_reviews (source_id, external_id, title, body, rating, app_version, posted_at, emotion)
  values (v_source_id, p_review ->> 'id', nullif(trim(p_review ->> 'title'), ''), p_review ->> 'text',
          (p_review ->> 'rating')::smallint, p_review ->> 'version',
          (p_review ->> 'posted_at')::timestamptz, p_review ->> 'emotion')
  on conflict (source_id, external_id) do update set
    title = excluded.title, body = excluded.body, rating = excluded.rating,
    app_version = excluded.app_version, emotion = coalesce(excluded.emotion, public.public_reviews.emotion);
end;
$$;

-- Saves what Claude found about a post (collector/notes.py): the note, and the face of each reply.
-- Tags are rewritten only when the note sends them (the 1.3 app still filters by them).
create or replace function public.save_community_note(p_note jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_news_id bigint := (p_note ->> 'news_id')::bigint;
begin
  if not exists (select 1 from public.news_items where news_id = v_news_id) then
    raise exception 'No post with id %', v_news_id;
  end if;

  if p_note ? 'categories' or p_note ? 'audiences' then
    delete from public.news_tags where news_id = v_news_id;
    insert into public.news_tags (news_id, tag_id)
    select v_news_id, t.tag_id
    from public.tags t
    where (t.tag_group = 'category' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'categories', '[]'))))
       or (t.tag_group = 'audience' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'audiences', '[]'))));
  end if;

  update public.public_replies r
  set emotion = e.emotion
  from (select (x ->> 'reply_id')::bigint as reply_id, x ->> 'emotion' as emotion
        from jsonb_array_elements(coalesce(p_note -> 'emotions', '[]')) as t (x)) e
  where r.reply_id = e.reply_id and r.news_id = v_news_id;

  if nullif(trim(p_note ->> 'summary'), '') is null then
    delete from public.community_notes where news_id = v_news_id;
    return;
  end if;

  insert into public.community_notes (news_id, summary, key_points, replies_read, model, generated_at)
  values (v_news_id, p_note ->> 'summary',
          array(select jsonb_array_elements_text(coalesce(p_note -> 'key_points', '[]'))),
          (p_note ->> 'replies_read')::integer, p_note ->> 'model', now())
  on conflict (news_id) do update set
    summary = excluded.summary, key_points = excluded.key_points,
    replies_read = excluded.replies_read, model = excluded.model, generated_at = excluded.generated_at;
end;
$$;

-- Saves an institution's pulse (collector/notes.py --pulse). The institution is found by name.
create function public.save_institution_pulse(p_pulse jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_org_id bigint;
begin
  select organization_id into v_org_id from public.organizations where name = p_pulse ->> 'organization';
  if v_org_id is null then
    raise exception 'No institution named %', p_pulse ->> 'organization';
  end if;
  insert into public.institution_pulse (organization_id, summary, key_points, opinions_read, since, model, generated_at)
  values (v_org_id, p_pulse ->> 'summary',
          array(select jsonb_array_elements_text(coalesce(p_pulse -> 'key_points', '[]'))),
          (p_pulse ->> 'opinions_read')::integer, (p_pulse ->> 'since')::timestamptz, p_pulse ->> 'model', now())
  on conflict (organization_id) do update set
    summary = excluded.summary, key_points = excluded.key_points, opinions_read = excluded.opinions_read,
    since = excluded.since, model = excluded.model, generated_at = excluded.generated_at;
end;
$$;

-- Saves one statistic (collector/stats.py). A newer value with the same label replaces the old one.
create function public.save_institution_stat(p_stat jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_org_id bigint;
begin
  select organization_id into v_org_id from public.organizations where name = p_stat ->> 'organization';
  if v_org_id is null then
    raise exception 'No institution named %', p_stat ->> 'organization';
  end if;
  insert into public.institution_stats (organization_id, section, label, value, unit, period, breakdown,
                                        source_name, source_url, position, collected_at)
  values (v_org_id, p_stat ->> 'section', p_stat ->> 'label', (p_stat ->> 'value')::numeric,
          p_stat ->> 'unit', p_stat ->> 'period', coalesce(p_stat -> 'breakdown', '[]'::jsonb),
          p_stat ->> 'source_name', p_stat ->> 'source_url',
          coalesce((p_stat ->> 'position')::integer, 100), now())
  on conflict (organization_id, label) do update set
    section = excluded.section, value = excluded.value, unit = excluded.unit, period = excluded.period,
    breakdown = excluded.breakdown, source_name = excluded.source_name, source_url = excluded.source_url,
    position = excluded.position, collected_at = excluded.collected_at;
end;
$$;

-- =====================================================================
-- 7. Security
-- =====================================================================
-- Everyone can read; only the collectors (secret key) write.

alter table public.public_reviews    enable row level security;
alter table public.institution_pulse enable row level security;
alter table public.institution_stats enable row level security;

revoke all on public.public_reviews, public.institution_pulse, public.institution_stats,
              public.institution_cards, public.review_cards
  from anon, authenticated;
grant select on public.public_reviews, public.institution_pulse, public.institution_stats,
                public.institution_cards, public.review_cards
  to anon, authenticated;

create policy "Anyone can read reviews"           on public.public_reviews    for select to anon, authenticated using (true);
create policy "Anyone can read institution pulse" on public.institution_pulse for select to anon, authenticated using (true);
create policy "Anyone can read institution stats" on public.institution_stats for select to anon, authenticated using (true);

revoke execute on function public.emotion_counts(text[]) from public;
grant execute on function public.emotion_counts(text[]) to anon, authenticated, service_role;
revoke execute on function public.institution_feed_page(bigint, integer, integer) from public;
grant execute on function public.institution_feed_page(bigint, integer, integer) to anon, authenticated;

revoke execute on function public.import_post(jsonb)            from public, anon, authenticated;
revoke execute on function public.import_x_post(jsonb)          from public, anon, authenticated;
revoke execute on function public.import_review(jsonb)          from public, anon, authenticated;
revoke execute on function public.save_institution_pulse(jsonb) from public, anon, authenticated;
revoke execute on function public.save_institution_stat(jsonb)  from public, anon, authenticated;
grant execute on function public.import_post(jsonb)            to service_role;
grant execute on function public.import_x_post(jsonb)          to service_role;
grant execute on function public.import_review(jsonb)          to service_role;
grant execute on function public.save_institution_pulse(jsonb) to service_role;
grant execute on function public.save_institution_stat(jsonb)  to service_role;

-- =====================================================================
-- 8. The institutions and their sources (found with PROTOCOL.md)
-- =====================================================================

update public.organizations set
  name_ar = 'وزارة التعليم', kind = 'ministry', city = 'الرياض', founded_year = 1953, position = 1,
  about = 'الجهة الحكومية المسؤولة عن التعليم العام والجامعي في المملكة العربية السعودية. '
          'تأسست وزارة المعارف عام 1953م، ودُمجت مع وزارة التعليم العالي عام 2015م باسم وزارة التعليم.'
where name = 'Ministry of Education';

update public.sources set platform = 'x', role = 'news', status = 'collected',
  note = 'الحساب الرسمي في إكس. تُجمع منشوراته والردود العامة عليها.'
where url = 'https://x.com/moe_gov_sa';

insert into public.organizations (name, name_ar, kind, city, founded_year, website_url, logo_url, about, position)
values ('Shaqra University', 'جامعة شقراء', 'university', 'شقراء', 2009, 'https://www.su.edu.sa',
        'https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/news-media/sources/shaqra-university.png',
        'جامعة حكومية تأسست عام 2009م (1430هـ) ومقرها محافظة شقراء، '
        'وتتوزع كلياتها على عدة محافظات منها الدوادمي والقويعية وعفيف.', 2);

insert into public.sources (organization_id, name, source_type, platform, role, status, url, handle, avatar_url, note)
select o.organization_id, v.name, v.source_type, v.platform, v.role, v.status, v.url, v.handle, v.avatar_url, v.note
from public.organizations o
join (values
  -- Ministry of Education
  ('Ministry of Education', 'وزارة التعليم', 'social', 'instagram', 'news', 'planned',
   'https://www.instagram.com/moe_gov_sa/', '@moe_gov_sa', null::text,
   'مرتبط من صفحة قنوات التواصل في موقع الوزارة. لا يوجد جامع بعد.'),
  ('Ministry of Education', 'وزارة التعليم', 'social', 'snapchat', 'news', 'planned',
   'https://www.snapchat.com/add/moe_gov', 'moe_gov', null,
   'مرتبط من صفحة قنوات التواصل في موقع الوزارة. محتوى مؤقت لا يُحفظ.'),
  ('Ministry of Education', 'وزارة التعليم', 'social', 'youtube', 'news', 'planned',
   'https://www.youtube.com/channel/UCNI3mOncSgbjIJJp01EzgVA', null, null,
   'مرتبط من صفحة قنوات التواصل. يمكن جمع التعليقات عبر YouTube Data API.'),
  ('Ministry of Education', 'المركز الإعلامي - وزارة التعليم', 'website', 'website', 'news', 'planned',
   'https://moe.gov.sa/ar/mediacenter/MOENews/Pages/default.aspx', 'moe.gov.sa', null,
   'لا توجد خلاصة RSS عامة؛ يحتاج قارئًا لصفحة الأخبار.'),
  ('Ministry of Education', 'مدرستي', 'app', 'app_store', 'opinions', 'collected',
   'https://apps.apple.com/sa/app/id1528970623', '1528970623', null,
   'تطبيق رسمي (الناشر: Saudi Ministry of Education). تُجمع مراجعاته المكتوبة.'),
  ('Ministry of Education', 'مدرستي - النتائج', 'app', 'app_store', 'opinions', 'collected',
   'https://apps.apple.com/sa/app/id1562545956', '1562545956', null,
   'تطبيق رسمي (الناشر: Saudi Ministry of Education). تُجمع مراجعاته المكتوبة.'),
  ('Ministry of Education', 'تواصل - وزارة التعليم', 'app', 'app_store', 'opinions', 'collected',
   'https://apps.apple.com/sa/app/id1071815086', '1071815086', null,
   'تطبيق رسمي لخدمة المستفيدين. تُجمع مراجعاته المكتوبة.'),
  ('Ministry of Education', 'الدعم الموحد', 'app', 'app_store', 'opinions', 'collected',
   'https://apps.apple.com/sa/app/id6739730553', '6739730553', null,
   'تطبيق رسمي للدعم الفني. تُجمع مراجعاته المكتوبة.'),
  ('Ministry of Education', 'البيانات المفتوحة - وزارة التعليم', 'open_data', 'open_data', 'stats', 'manual',
   'https://moe.gov.sa/ar/knowledgecenter/dataandstats/Pages/opendata.aspx', null, null,
   'الأرقام الرسمية تُنشر في تقارير وبيانات صحفية؛ تُدخل يدويًا في stats/moe.json مع مصدرها.'),
  -- Shaqra University
  ('Shaqra University', 'جامعة شقراء', 'social', 'x', 'news', 'collected',
   'https://x.com/ShaqraUni', '@ShaqraUni',
   'https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/news-media/sources/shaqra-university.png',
   'مرتبط من تذييل موقع الجامعة. تُجمع منشوراته والردود العامة عليها.'),
  ('Shaqra University', 'جامعة شقراء', 'rss', 'rss', 'news', 'collected',
   'https://www.su.edu.sa/ar/rss.xml', 'su.edu.sa',
   'https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/news-media/sources/shaqra-university.png',
   'خلاصة RSS غير مرتبطة من أي صفحة في الموقع: تصل منها أخبار الجامعة وإعلاناتها.'),
  ('Shaqra University', 'جامعة شقراء', 'website', 'website', 'news', 'manual',
   'https://www.su.edu.sa/ar/news', 'su.edu.sa',
   'https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/news-media/sources/shaqra-university.png',
   'أخبار أبريل–أكتوبر 2026 جُمعت يدويًا؛ الجديد يصل عبر خلاصة RSS.'),
  ('Shaqra University', 'جامعة شقراء', 'website', 'website', 'news', 'manual',
   'https://www.su.edu.sa/ar/announcements', 'su.edu.sa',
   'https://YOUR-PROJECT-REF.supabase.co/storage/v1/object/public/news-media/sources/shaqra-university.png',
   'إعلانات جُمعت يدويًا؛ الجديد يصل عبر خلاصة RSS.'),
  ('Shaqra University', 'جامعة شقراء', 'social', 'youtube', 'news', 'planned',
   'https://www.youtube.com/user/shaqrauniv', null, null,
   'مرتبط من تذييل الموقع. يمكن جمع التعليقات عبر YouTube Data API.'),
  ('Shaqra University', 'جامعة شقراء', 'social', 'linkedin', 'news', 'planned',
   'https://www.linkedin.com/school/shaqra-university', null, null,
   'مرتبط من تذييل الموقع. لينكدإن لا يسمح بالجمع الآلي.'),
  ('Shaqra University', 'تطبيق جامعة شقراء', 'app', 'app_store', 'opinions', 'collected',
   'https://apps.apple.com/sa/app/id1604564080', '1604564080', null,
   'تطبيق الجامعة (الناشر: Adaptive TechSoft). تُجمع مراجعاته المكتوبة.'),
  ('Shaqra University', 'البيانات المفتوحة - جامعة شقراء', 'open_data', 'open_data', 'stats', 'collected',
   'https://opendata.su.edu.sa/swagger/index.html', null, null,
   'واجهة برمجية عامة مذكورة في صفحة البيانات المفتوحة فقط: القبول والخريجون وأعضاء هيئة التدريس والموظفون وإحصاءات بلاك بورد.')
) as v (organization, name, source_type, platform, role, status, url, handle, avatar_url, note)
  on v.organization = o.name;

-- Shaqra's news from the university version, archived in v2_archive (migrate-to-ministry.sql).
-- A new project has no archive and skips this; its news comes from rss.py and collect.py.
do $$
begin
  if to_regclass('v2_archive.news_items') is null then
    return;
  end if;

  insert into public.news_items (source_id, source_url, body, published_at, collected_at)
  select ns.source_id, an.source_url, an.body, an.published_at, an.collected_at
  from v2_archive.news_items an
  join v2_archive.sources asrc on asrc.source_id = an.source_id
  join v2_archive.universities u on u.university_id = asrc.university_id and u.name = 'Shaqra University'
  join public.sources ns on ns.url = asrc.url
  on conflict (source_url) do nothing;

  insert into public.news_media (news_id, url, alt_text, position, width, height)
  select n.news_id, am.url, am.alt_text, am.position, am.width, am.height
  from v2_archive.news_media am
  join v2_archive.news_items an on an.news_id = am.news_id
  join public.news_items n on n.source_url = an.source_url
  on conflict (news_id, position) do nothing;
end $$;

-- =====================================================================
-- 9. Who gave each face (applied as the migration emotion_labelled_by)
-- =====================================================================
-- A review's face starts from its stars ('stars'); Claude then reads the words, which often
-- disagree with the stars, and the model that read them replaces 'stars'.

alter table public.public_replies add column emotion_by text; -- the Claude model that read it
alter table public.public_reviews add column emotion_by text; -- 'stars', or the Claude model that read the text

create or replace function public.import_review(p_review jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_source_id bigint;
begin
  select source_id into v_source_id from public.sources where url = p_review ->> 'source';
  if v_source_id is null then
    raise exception 'No source with the address %', p_review ->> 'source';
  end if;
  insert into public.public_reviews (source_id, external_id, title, body, rating, app_version, posted_at, emotion, emotion_by)
  values (v_source_id, p_review ->> 'id', nullif(trim(p_review ->> 'title'), ''), p_review ->> 'text',
          (p_review ->> 'rating')::smallint, p_review ->> 'version',
          (p_review ->> 'posted_at')::timestamptz, p_review ->> 'emotion', p_review ->> 'emotion_by')
  on conflict (source_id, external_id) do update set
    title = excluded.title, body = excluded.body, rating = excluded.rating, app_version = excluded.app_version,
    -- a face Claude read from the text is kept; one from the stars follows the stars
    emotion = case when public.public_reviews.emotion_by is null or public.public_reviews.emotion_by = 'stars'
                   then excluded.emotion else public.public_reviews.emotion end,
    emotion_by = case when public.public_reviews.emotion_by is null or public.public_reviews.emotion_by = 'stars'
                      then excluded.emotion_by else public.public_reviews.emotion_by end;
end;
$$;

-- Faces Claude read from review texts (collector/notes.py): {"model": ..., "emotions": [{"review_id", "emotion"}]}
create function public.save_review_emotions(p_labels jsonb)
returns void
language sql
set search_path = ''
as $$
  update public.public_reviews v
  set emotion = e.emotion, emotion_by = p_labels ->> 'model'
  from (select (x ->> 'review_id')::bigint as review_id, x ->> 'emotion' as emotion
        from jsonb_array_elements(coalesce(p_labels -> 'emotions', '[]')) as t (x)) e
  where v.review_id = e.review_id;
$$;

-- save_community_note now also records which model gave each reply its face.
create or replace function public.save_community_note(p_note jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_news_id bigint := (p_note ->> 'news_id')::bigint;
begin
  if not exists (select 1 from public.news_items where news_id = v_news_id) then
    raise exception 'No post with id %', v_news_id;
  end if;

  if p_note ? 'categories' or p_note ? 'audiences' then
    delete from public.news_tags where news_id = v_news_id;
    insert into public.news_tags (news_id, tag_id)
    select v_news_id, t.tag_id
    from public.tags t
    where (t.tag_group = 'category' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'categories', '[]'))))
       or (t.tag_group = 'audience' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'audiences', '[]'))));
  end if;

  update public.public_replies r
  set emotion = e.emotion, emotion_by = p_note ->> 'model'
  from (select (x ->> 'reply_id')::bigint as reply_id, x ->> 'emotion' as emotion
        from jsonb_array_elements(coalesce(p_note -> 'emotions', '[]')) as t (x)) e
  where r.reply_id = e.reply_id and r.news_id = v_news_id;

  if nullif(trim(p_note ->> 'summary'), '') is null then
    delete from public.community_notes where news_id = v_news_id;
    return;
  end if;

  insert into public.community_notes (news_id, summary, key_points, replies_read, model, generated_at)
  values (v_news_id, p_note ->> 'summary',
          array(select jsonb_array_elements_text(coalesce(p_note -> 'key_points', '[]'))),
          (p_note ->> 'replies_read')::integer, p_note ->> 'model', now())
  on conflict (news_id) do update set
    summary = excluded.summary, key_points = excluded.key_points,
    replies_read = excluded.replies_read, model = excluded.model, generated_at = excluded.generated_at;
end;
$$;

create or replace view public.review_cards
with (security_invoker = true) as
select v.review_id, v.title, v.body, v.rating, v.app_version, v.posted_at, v.emotion,
       s.source_id, s.name as app_name, s.url as app_url, s.organization_id, v.emotion_by
from public.public_reviews v
join public.sources s on s.source_id = v.source_id;

revoke execute on function public.save_review_emotions(jsonb) from public, anon, authenticated;
grant execute on function public.save_review_emotions(jsonb) to service_role;

-- =====================================================================
-- 10. The mood belongs to the news (applied as the migration mood_from_news)
-- =====================================================================
-- An institution's faces now come only from the replies under its news, the same faces its
-- posts show. App reviews stay, without faces in the app, on its Info page. latest_body is its
-- newest post, for the home screen. The pulse column stays for older builds; 1.4.1 no longer
-- shows it.

create or replace view public.institution_cards
with (security_invoker = true) as
select
  o.organization_id,
  o.name,
  o.name_ar,
  o.kind,
  o.city,
  o.founded_year,
  o.website_url,
  o.about,
  o.position,
  coalesce(o.logo_url, (select s.avatar_url from public.sources s
                        where s.organization_id = o.organization_id and s.avatar_url is not null
                        order by s.source_id limit 1)) as logo_url,
  (select count(*) from public.news_items n join public.sources s on s.source_id = n.source_id
   where s.organization_id = o.organization_id)::integer as post_count,
  (select max(coalesce(n.published_at, n.collected_at)) from public.news_items n
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id) as last_post_at,
  (select count(*) from public.sources s where s.organization_id = o.organization_id)::integer as source_count,
  (select count(*) from public.institution_stats st where st.organization_id = o.organization_id)::integer as stat_count,
  public.emotion_counts(array(
    select r.emotion from public.public_replies r
    join public.news_items n on n.news_id = r.news_id
    join public.sources s on s.source_id = n.source_id
    where s.organization_id = o.organization_id)) as emotions,
  (select count(*) from public.public_replies r join public.news_items n on n.news_id = r.news_id
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id)::integer as reply_count,
  (select count(*) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id)::integer as review_count,
  (select round(avg(v.rating), 2) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id) as review_rating,
  (select jsonb_build_object('summary', p.summary, 'key_points', p.key_points,
                             'opinions_read', p.opinions_read, 'since', p.since,
                             'model', p.model, 'generated_at', p.generated_at)
   from public.institution_pulse p where p.organization_id = o.organization_id) as pulse,
  (select n.body from public.news_items n join public.sources s on s.source_id = n.source_id
   where s.organization_id = o.organization_id
   order by coalesce(n.published_at, n.collected_at) desc, n.news_id desc limit 1) as latest_body
from public.organizations o;

-- =====================================================================
-- 11. Every source, one story per event (applied as the migration stories_and_press)
-- =====================================================================
-- Press reports join the official channels: one 'press' source per institution, a Google News
-- search that press.py reads outlet by outlet, with each report's newspaper or agency in news_items.outlet. When the website, X, YouTube
-- and the press report the same event, story_links ties each copy to the story's main post (the
-- one with the replies). news_cards shows only the main post, with the copies in also_in, so its
-- "What people said" covers the whole story. Nothing is deleted; older builds keep working.

alter table public.sources drop constraint sources_source_type_check;
alter table public.sources add constraint sources_source_type_check
  check (source_type in ('website', 'rss', 'social', 'app', 'open_data', 'press'));

alter table public.news_items
  add column outlet text check (length(trim(outlet)) between 1 and 120); -- for press reports

create table public.story_links (
  news_id      bigint primary key references public.news_items (news_id) on delete cascade,
  main_news_id bigint not null references public.news_items (news_id) on delete cascade,
  check (news_id <> main_news_id)
);
create index story_links_main_idx on public.story_links (main_news_id);
alter table public.story_links enable row level security;
create policy "Anyone can read story links" on public.story_links
  for select to anon, authenticated using (true);
revoke all on public.story_links from anon, authenticated;
grant select on public.story_links to anon, authenticated;

create or replace function public.import_post(p_post jsonb)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_source_id bigint;
  v_news_id   bigint;
begin
  select source_id into v_source_id
  from public.sources
  where url = p_post ->> 'source' or lower(handle) = lower(p_post ->> 'handle')
  order by (url = p_post ->> 'source') desc nulls last
  limit 1;
  if v_source_id is null then
    raise exception 'No source with the address % or handle %', p_post ->> 'source', p_post ->> 'handle';
  end if;
  if p_post ->> 'avatar_url' is not null then
    update public.sources set avatar_url = p_post ->> 'avatar_url' where source_id = v_source_id;
  end if;

  insert into public.news_items (source_id, source_url, body, published_at, outlet)
  values (v_source_id, p_post ->> 'url', p_post ->> 'text', (p_post ->> 'posted_at')::timestamptz,
          p_post ->> 'outlet')
  on conflict (source_url) do update set body = excluded.body, published_at = excluded.published_at,
                                         outlet = excluded.outlet
  returning news_id into v_news_id;

  if p_post ? 'images' then
    delete from public.news_media where news_id = v_news_id;
    insert into public.news_media (news_id, url, alt_text, position, width, height)
    select v_news_id, m ->> 'url', m ->> 'alt', (i - 1)::integer,
           (m ->> 'width')::integer, (m ->> 'height')::integer
    from jsonb_array_elements(p_post -> 'images') with ordinality as t (m, i);
  end if;

  insert into public.public_replies (news_id, external_id, body, posted_at, like_count)
  select v_news_id, r ->> 'id', r ->> 'text', (r ->> 'posted_at')::timestamptz,
         coalesce((r ->> 'likes')::integer, 0)
  from jsonb_array_elements(coalesce(p_post -> 'replies', '[]')) as t (r)
  on conflict (news_id, external_id) do update set like_count = excluded.like_count;

  return v_news_id;
end;
$$;

-- Saves one story found by stories.py: {"main": id, "others": [ids]}. Copies that belonged to
-- another story move to this one; "others": [] makes the main post a story of its own again.
create function public.save_story(p_story jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_main   bigint := (p_story ->> 'main')::bigint;
  v_others bigint[] := array(select jsonb_array_elements_text(coalesce(p_story -> 'others', '[]'))::bigint);
begin
  delete from public.story_links
  where news_id = v_main or news_id = any (v_others)
     or main_news_id = v_main or main_news_id = any (v_others);
  insert into public.story_links (news_id, main_news_id)
  select other, v_main from unnest(v_others) as other where other <> v_main
  on conflict (news_id) do update set main_news_id = excluded.main_news_id;
end;
$$;
revoke execute on function public.save_story(jsonb) from public, anon, authenticated;
grant execute on function public.save_story(jsonb) to service_role;

-- A story's main post, with the other copies of it in also_in (official ones first). A press
-- report shows its outlet as the source name; the institution's website and YouTube posts show
-- its logo (applied as the migration news_cards_logos).
create or replace view public.news_cards
with (security_invoker = true) as
select
  n.news_id,
  n.body,
  coalesce(n.published_at, n.collected_at) as published_at,
  n.source_url,
  s.source_id,
  coalesce(n.outlet, s.name) as source_name,
  s.handle,
  s.source_type,
  case when s.source_type = 'press' then s.avatar_url
       else coalesce(s.avatar_url, o.logo_url,
                     (select s2.avatar_url from public.sources s2
                      where s2.organization_id = o.organization_id and s2.avatar_url is not null
                      order by s2.source_id limit 1)) end as avatar_url, -- the institution's logo for its website and YouTube
  o.name as organization,
  array(select t.name from public.news_tags nt join public.tags t on t.tag_id = nt.tag_id
        where nt.news_id = n.news_id and t.tag_group = 'audience' order by t.tag_id) as audience,
  array(select t.name from public.news_tags nt join public.tags t on t.tag_id = nt.tag_id
        where nt.news_id = n.news_id and t.tag_group = 'category' order by t.tag_id) as category,
  coalesce((select jsonb_agg(jsonb_build_object('url', m.url, 'alt', m.alt_text, 'width', m.width,
                                                'height', m.height) order by m.position)
            from public.news_media m where m.news_id = n.news_id), '[]'::jsonb) as media,
  (select count(*) from public.comments c where c.news_id = n.news_id)::integer as comment_count,
  (select count(*) from public.public_replies r where r.news_id = n.news_id)::integer as reply_count,
  (select jsonb_build_object('summary', cn.summary, 'key_points', cn.key_points,
                             'replies_read', cn.replies_read, 'model', cn.model,
                             'generated_at', cn.generated_at)
   from public.community_notes cn where cn.news_id = n.news_id) as community_note,
  o.organization_id,
  public.emotion_counts(array(select r.emotion from public.public_replies r
                              where r.news_id = n.news_id)) as emotions,
  s.platform,
  coalesce((select jsonb_agg(jsonb_build_object(
                     'source_name', coalesce(c.outlet, cs.name), 'platform', cs.platform,
                     'source_type', cs.source_type, 'url', c.source_url,
                     'published_at', coalesce(c.published_at, c.collected_at))
                   order by (cs.source_type = 'press'), coalesce(c.published_at, c.collected_at))
            from public.story_links l
            join public.news_items c on c.news_id = l.news_id
            join public.sources cs on cs.source_id = c.source_id
            where l.main_news_id = n.news_id), '[]'::jsonb) as also_in
from public.news_items n
join public.sources s on s.source_id = n.source_id
join public.organizations o on o.organization_id = s.organization_id
where not exists (select 1 from public.story_links l where l.news_id = n.news_id);

-- post_count and latest_body now count stories, not copies.
create or replace view public.institution_cards
with (security_invoker = true) as
select
  o.organization_id,
  o.name,
  o.name_ar,
  o.kind,
  o.city,
  o.founded_year,
  o.website_url,
  o.about,
  o.position,
  coalesce(o.logo_url, (select s.avatar_url from public.sources s
                        where s.organization_id = o.organization_id and s.avatar_url is not null
                        order by s.source_id limit 1)) as logo_url,
  (select count(*) from public.news_cards c where c.organization_id = o.organization_id)::integer as post_count,
  (select max(coalesce(n.published_at, n.collected_at)) from public.news_items n
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id) as last_post_at,
  (select count(*) from public.sources s where s.organization_id = o.organization_id)::integer as source_count,
  (select count(*) from public.institution_stats st where st.organization_id = o.organization_id)::integer as stat_count,
  public.emotion_counts(array(
    select r.emotion from public.public_replies r
    join public.news_items n on n.news_id = r.news_id
    join public.sources s on s.source_id = n.source_id
    where s.organization_id = o.organization_id)) as emotions,
  (select count(*) from public.public_replies r join public.news_items n on n.news_id = r.news_id
   join public.sources s on s.source_id = n.source_id where s.organization_id = o.organization_id)::integer as reply_count,
  (select count(*) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id)::integer as review_count,
  (select round(avg(v.rating), 2) from public.public_reviews v join public.sources s on s.source_id = v.source_id
   where s.organization_id = o.organization_id) as review_rating,
  (select jsonb_build_object('summary', p.summary, 'key_points', p.key_points,
                             'opinions_read', p.opinions_read, 'since', p.since,
                             'model', p.model, 'generated_at', p.generated_at)
   from public.institution_pulse p where p.organization_id = o.organization_id) as pulse,
  (select c.body from public.news_cards c where c.organization_id = o.organization_id
   order by c.published_at desc, c.news_id desc limit 1) as latest_body
from public.organizations o;

-- The channels this adds or starts collecting.
insert into public.sources (organization_id, name, source_type, url, platform, role, status, note)
select o.organization_id, 'الصحف السعودية ووكالة الأنباء', 'press', press.url, 'media', 'news', 'collected', press.note
from (values
  ('Ministry of Education', 'https://news.google.com/search?q=%22%D9%88%D8%B2%D8%A7%D8%B1%D8%A9+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22+OR+%22%D9%88%D8%B2%D9%8A%D8%B1+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22&hl=ar&gl=SA&ceid=SA%3Aar',
   'ما تنشره واس والصحف السعودية عن الوزارة والوزير، من بحث أخبار Google. يُحفظ العنوان والجهة الناشرة والرابط فقط.'),
  ('Shaqra University', 'https://news.google.com/search?q=%22%D8%AC%D8%A7%D9%85%D8%B9%D8%A9+%D8%B4%D9%82%D8%B1%D8%A7%D8%A1%22&hl=ar&gl=SA&ceid=SA%3Aar',
   'ما تنشره واس والصحف السعودية عن الجامعة، من بحث أخبار Google. يُحفظ العنوان والجهة الناشرة والرابط فقط.')
) as press (organization, url, note)
join public.organizations o on o.name = press.organization
on conflict (url) do nothing;

update public.sources set status = 'collected',
  note = 'لا تعطي الصفحة قائمة أخبارها إلا عبر واجهة SharePoint الداخلية، فتُقرأ أخبار الوزارة من فهرس أخبار Google الذي يدرج صفحاتها.'
where url = 'https://moe.gov.sa/ar/mediacenter/MOENews/Pages/default.aspx';

update public.sources set status = 'collected',
  note = 'آخر المقاطع من خلاصة القناة العامة (videos.xml). التعليقات عبر YouTube Data API عند إضافة مفتاحها.'
where url = 'https://www.youtube.com/channel/UCNI3mOncSgbjIJJp01EzgVA';

update public.sources set
  note = 'مرتبط من تذييل الموقع. خلاصة القناة العامة لا تعرض مقاطع حاليًا.'
where url = 'https://www.youtube.com/user/shaqrauniv';
