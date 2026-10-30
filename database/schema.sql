-- WeshFatak database (Supabase / PostgreSQL)
--   organizations 1-N sources 1-N news_items 1-N news_media
--   news_items N-M tags (news_tags), profiles 1-N comments N-1 news_items
--   news_items 1-N public_replies, news_items 1-1 community_notes
--   auth.users 1-1 profiles
-- Run once on an empty project (Supabase dashboard -> SQL Editor, or as a migration).
-- The live project was moved here from the university version with migrate-to-ministry.sql.

-- =====================================================================
-- 1. News: where it comes from and what it contains
-- =====================================================================

create table public.organizations (
  organization_id bigint generated always as identity primary key,
  name            text not null unique check (length(trim(name)) between 1 and 120),
  website_url     text check (website_url ~ '^https?://')
);

create table public.sources (
  source_id       bigint generated always as identity primary key,
  organization_id bigint not null references public.organizations (organization_id) on delete cascade,
  name            text not null check (length(trim(name)) between 1 and 120),
  source_type     text not null check (source_type in ('website', 'rss', 'social')),
  url             text not null unique check (url ~ '^https?://'),
  avatar_url      text check (avatar_url ~ '^https://'),
  handle          text
);

create table public.news_items (
  news_id      bigint generated always as identity primary key,
  source_id    bigint not null references public.sources (source_id) on delete cascade,
  source_url   text not null unique check (source_url ~ '^https?://'), -- the same post is never saved twice
  body         text not null check (length(trim(body)) > 0),
  published_at timestamptz, -- null when the source shows no date
  collected_at timestamptz not null default now()
);

create table public.news_media (
  media_id bigint generated always as identity primary key,
  news_id  bigint not null references public.news_items (news_id) on delete cascade,
  url      text not null check (url ~ '^https://'),
  alt_text text,
  position integer not null default 0 check (position >= 0),
  width    integer check (width > 0),  -- lets the app reserve the right space before the image loads
  height   integer check (height > 0),
  unique (news_id, position)
);

create table public.tags (
  tag_id    bigint generated always as identity primary key,
  name      text not null check (length(trim(name)) between 1 and 60),
  tag_group text not null check (tag_group in ('audience', 'category')),
  unique (tag_group, name)
);

create table public.news_tags (
  news_id bigint not null references public.news_items (news_id) on delete cascade,
  tag_id  bigint not null references public.tags (tag_id) on delete cascade,
  primary key (news_id, tag_id)
);

-- =====================================================================
-- 2. What people think: replies on X, and the note written from them
-- =====================================================================

-- Replies people wrote under a post on X. Only the text, the time and the likes are kept:
-- never who wrote them.
create table public.public_replies (
  reply_id     bigint generated always as identity primary key,
  news_id      bigint not null references public.news_items (news_id) on delete cascade,
  external_id  text not null, -- the reply's id on X, so the same reply is never saved twice
  body         text not null check (length(trim(body)) > 0),
  posted_at    timestamptz not null,
  like_count   integer not null default 0 check (like_count >= 0),
  collected_at timestamptz not null default now(),
  unique (news_id, external_id)
);

-- What people think of a post, written by Claude from its public replies and app comments.
create table public.community_notes (
  news_id      bigint primary key references public.news_items (news_id) on delete cascade,
  summary      text not null check (length(trim(summary)) > 0),
  key_points   text[] not null default '{}', -- issues, requests and questions people raised
  replies_read integer not null check (replies_read > 0), -- replies and app comments the note is based on
  model        text not null, -- the Claude model that wrote it
  generated_at timestamptz not null default now()
);

-- =====================================================================
-- 3. People: profiles (one per account) and their comments in the app
-- =====================================================================

create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 60)
);

create table public.comments (
  comment_id bigint generated always as identity primary key,
  news_id    bigint not null references public.news_items (news_id) on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles (user_id) on delete cascade,
  body       text not null check (length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index sources_organization_idx on public.sources (organization_id);
create index news_items_source_idx    on public.news_items (source_id);
create index news_items_date_idx      on public.news_items (coalesce(published_at, collected_at) desc, news_id desc);
create index news_tags_tag_idx        on public.news_tags (tag_id, news_id);
create index comments_news_idx        on public.comments (news_id, created_at);
create index comments_user_idx        on public.comments (user_id);

-- Every new account gets a profile. The name comes from the sign-up form.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
                  nullif(split_part(new.email, '@', 1), ''),
                  'Member'), 60)
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- 4. What the app reads: one card per post, and one page of the feed
-- =====================================================================

create view public.news_cards
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
   from public.community_notes cn where cn.news_id = n.news_id) as community_note -- null until written
from public.news_items n
join public.sources s on s.source_id = n.source_id
join public.organizations o on o.organization_id = s.organization_id;

-- One page of the feed, newest first.
--   audiences:  a post matches when it has one of them, or has no audience tag (it is for everyone)
--   categories: a post matches when it has one of them
create function public.feed_page(
  p_audiences  text[] default '{}',
  p_categories text[] default '{}',
  p_limit      integer default 10,
  p_offset     integer default 0
)
returns setof public.news_cards
language sql
stable
security invoker
set search_path = ''
as $$
  select c.*
  from public.news_cards c
  where (coalesce(cardinality(p_audiences), 0) = 0 or cardinality(c.audience) = 0 or c.audience && p_audiences)
    and (coalesce(cardinality(p_categories), 0) = 0 or c.category && p_categories)
  order by c.published_at desc, c.news_id desc
  limit least(greatest(coalesce(p_limit, 10), 1), 30)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- =====================================================================
-- 5. How the collector saves posts and notes (collector/collect.py, collector/notes.py)
-- =====================================================================
-- One call saves a post with its images and replies. Running it again for the same post updates
-- the text and like counts and adds new replies, without making copies.

create function public.import_x_post(p_post jsonb)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_source_id bigint;
  v_news_id   bigint;
begin
  update public.sources
  set avatar_url = coalesce(p_post ->> 'avatar_url', avatar_url)
  where handle = p_post ->> 'handle'
  returning source_id into v_source_id;
  if v_source_id is null then
    raise exception 'No source with the handle %', p_post ->> 'handle';
  end if;

  insert into public.news_items (source_id, source_url, body, published_at)
  values (v_source_id, p_post ->> 'url', p_post ->> 'text', (p_post ->> 'posted_at')::timestamptz)
  on conflict (source_url) do update set body = excluded.body, published_at = excluded.published_at
  returning news_id into v_news_id;

  delete from public.news_media where news_id = v_news_id;
  insert into public.news_media (news_id, url, alt_text, position, width, height)
  select v_news_id, m ->> 'url', m ->> 'alt', (i - 1)::integer,
         (m ->> 'width')::integer, (m ->> 'height')::integer
  from jsonb_array_elements(coalesce(p_post -> 'images', '[]')) with ordinality as t (m, i);

  insert into public.public_replies (news_id, external_id, body, posted_at, like_count)
  select v_news_id, r ->> 'id', r ->> 'text', (r ->> 'posted_at')::timestamptz,
         coalesce((r ->> 'likes')::integer, 0)
  from jsonb_array_elements(coalesce(p_post -> 'replies', '[]')) as t (r)
  on conflict (news_id, external_id) do update set like_count = excluded.like_count;

  return v_news_id;
end;
$$;

-- How the notes writer saves what Claude found (collector/notes.py): the post's tags and the
-- note. A post with no replies gets tags but no note.

create function public.save_community_note(p_note jsonb)
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

  delete from public.news_tags where news_id = v_news_id;
  insert into public.news_tags (news_id, tag_id)
  select v_news_id, t.tag_id
  from public.tags t
  where (t.tag_group = 'category' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'categories', '[]'))))
     or (t.tag_group = 'audience' and t.name in (select jsonb_array_elements_text(coalesce(p_note -> 'audiences', '[]'))));

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

-- =====================================================================
-- 6. Security
-- =====================================================================
-- Guests and members can read news, tags, names, comments, replies and notes.
-- Members can edit only their own profile and comment only as themselves.
-- News, replies and notes are written only with the secret key (the collector, never the app).

alter table public.organizations   enable row level security;
alter table public.sources         enable row level security;
alter table public.news_items      enable row level security;
alter table public.news_media      enable row level security;
alter table public.tags            enable row level security;
alter table public.news_tags       enable row level security;
alter table public.public_replies  enable row level security;
alter table public.community_notes enable row level security;
alter table public.profiles        enable row level security;
alter table public.comments        enable row level security;

revoke all on public.organizations, public.sources, public.news_items, public.news_media,
              public.tags, public.news_tags, public.public_replies, public.community_notes,
              public.profiles, public.comments, public.news_cards
  from anon, authenticated;

grant select on public.organizations, public.sources, public.news_items, public.news_media,
                public.tags, public.news_tags, public.public_replies, public.community_notes,
                public.profiles, public.comments, public.news_cards
  to anon, authenticated;
grant insert (user_id, display_name), update (display_name) on public.profiles to authenticated;
grant insert (news_id, body) on public.comments to authenticated;

revoke execute on function public.feed_page(text[], text[], integer, integer) from public;
grant execute on function public.feed_page(text[], text[], integer, integer) to anon, authenticated;
revoke execute on function public.import_x_post(jsonb) from public, anon, authenticated;
grant execute on function public.import_x_post(jsonb) to service_role;
revoke execute on function public.save_community_note(jsonb) from public, anon, authenticated;
grant execute on function public.save_community_note(jsonb) to service_role;

create policy "Anyone can read organizations"   on public.organizations   for select to anon, authenticated using (true);
create policy "Anyone can read sources"         on public.sources         for select to anon, authenticated using (true);
create policy "Anyone can read news"            on public.news_items      for select to anon, authenticated using (true);
create policy "Anyone can read news media"      on public.news_media      for select to anon, authenticated using (true);
create policy "Anyone can read tags"            on public.tags            for select to anon, authenticated using (true);
create policy "Anyone can read news tags"       on public.news_tags       for select to anon, authenticated using (true);
create policy "Anyone can read public replies"  on public.public_replies  for select to anon, authenticated using (true);
create policy "Anyone can read community notes" on public.community_notes for select to anon, authenticated using (true);
create policy "Anyone can read profiles"        on public.profiles        for select to anon, authenticated using (true);
create policy "Anyone can read comments"        on public.comments        for select to anon, authenticated using (true);

create policy "Members create their own profile" on public.profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Members edit their own profile" on public.profiles
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Members comment as themselves" on public.comments
  for insert to authenticated with check (user_id = (select auth.uid()));

-- =====================================================================
-- 7. Images: a public bucket the app reads from
-- =====================================================================
-- Public means anyone with the link can view a file. Only the service role can upload.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('news-media', 'news-media', true, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;
