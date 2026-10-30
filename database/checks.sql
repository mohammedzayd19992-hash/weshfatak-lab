-- WeshFatak checks. Run after schema.sql and seed.sql.
-- Everything happens inside one transaction that is rolled back, so nothing is left behind.
-- Passes when it finishes without an error. A failure starts with "CHECK FAILED:".

begin;

create function public.uninews_expect_error(statement text, expected_sqlstate text, check_name text)
returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    if sqlstate = expected_sqlstate then return; end if;
    raise exception 'CHECK FAILED: % (expected error %, got %: %)', check_name, expected_sqlstate, sqlstate, sqlerrm;
  end;
  raise exception 'CHECK FAILED: % (it was allowed but should be rejected)', check_name;
end $$;
grant execute on function public.uninews_expect_error(text, text, text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Test data: one organization, one source, three posts, two accounts.
-- The posts are dated 2099 so they come first in the feed, before any real news.
-- ---------------------------------------------------------------------
insert into public.organizations (name) values ('TEST Organization');
insert into public.sources (organization_id, name, source_type, url, handle)
select organization_id, 'TEST source', 'social', 'https://test.local/news', '@test_source'
from public.organizations where name = 'TEST Organization';

insert into public.news_items (source_id, source_url, body, published_at)
select source_id, v.url, v.body, v.at
from public.sources, (values
  ('https://test.local/1', 'TEST exam timetable for students',  timestamptz '2099-01-03'),
  ('https://test.local/2', 'TEST staff meeting',                timestamptz '2099-01-02'),
  ('https://test.local/3', 'TEST open day for everyone',        timestamptz '2099-01-01')
) as v (url, body, at)
where sources.url = 'https://test.local/news';

insert into public.news_tags (news_id, tag_id)
select n.news_id, t.tag_id
from public.news_items n
join public.tags t on (n.source_url, t.tag_group, t.name) in (
  ('https://test.local/1', 'audience', 'Students'),
  ('https://test.local/1', 'category', 'Exams'),
  ('https://test.local/2', 'audience', 'Teaching Staff'),
  ('https://test.local/2', 'category', 'Administrative'),
  ('https://test.local/3', 'category', 'Activities'));

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local', '{"display_name": "TEST Member A"}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local', '{}');

do $$
begin
  if (select display_name from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a') is distinct from 'TEST Member A' then
    raise exception 'CHECK FAILED: a new account should get a profile with the name from sign up';
  end if;
  if (select display_name from public.profiles where user_id = '00000000-0000-0000-0000-00000000000b') is distinct from 'b' then
    raise exception 'CHECK FAILED: an account without a name should be named after its email';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Bad data is rejected (23514 = rule broken, 23505 = duplicate)
-- ---------------------------------------------------------------------
select public.uninews_expect_error(
  $sql$ insert into public.news_items (source_id, source_url, body)
        select source_id, 'https://test.local/empty', '   ' from public.sources where url = 'https://test.local/news' $sql$,
  '23514', 'a post cannot be empty');
select public.uninews_expect_error(
  $sql$ insert into public.news_items (source_id, source_url, body)
        select source_id, 'https://test.local/1', 'Copy' from public.sources where url = 'https://test.local/news' $sql$,
  '23505', 'the same post cannot be saved twice');
select public.uninews_expect_error(
  $sql$ insert into public.tags (name, tag_group) values ('Sports', 'colour') $sql$,
  '23514', 'a tag group must be audience or category');
select public.uninews_expect_error(
  $sql$ update public.profiles set display_name = repeat('x', 61) where user_id = '00000000-0000-0000-0000-00000000000a' $sql$,
  '23514', 'a name has at most 60 characters');

-- ---------------------------------------------------------------------
-- The X collector (secret key): saving the same post twice makes no copies
-- ---------------------------------------------------------------------
set local role service_role;

select public.import_x_post($json$
  {"handle": "@test_source", "url": "https://test.local/x/1", "posted_at": "2098-06-01T09:00:00+03:00",
   "text": "TEST ministry announcement", "avatar_url": "https://test.local/avatar.png",
   "images": [{"url": "https://test.local/a.jpg", "alt": "A", "width": 800, "height": 450},
              {"url": "https://test.local/b.jpg", "alt": "B", "width": 800, "height": 450}],
   "replies": [{"id": "r1", "text": "TEST great news", "posted_at": "2098-06-01T10:00:00+03:00", "likes": 2},
               {"id": "r2", "text": "TEST what about the heat?", "posted_at": "2098-06-01T11:00:00+03:00", "likes": 0}]}
$json$::jsonb);

select public.import_x_post($json$
  {"handle": "@test_source", "url": "https://test.local/x/1", "posted_at": "2098-06-01T09:00:00+03:00",
   "text": "TEST ministry announcement (edited)",
   "images": [{"url": "https://test.local/a.jpg", "alt": "A", "width": 800, "height": 450}],
   "replies": [{"id": "r2", "text": "TEST what about the heat?", "posted_at": "2098-06-01T11:00:00+03:00", "likes": 7},
               {"id": "r3", "text": "TEST thanks", "posted_at": "2098-06-01T12:00:00+03:00", "likes": 1}]}
$json$::jsonb);

do $$
begin
  if (select count(*) from public.news_items where source_url = 'https://test.local/x/1') <> 1 then
    raise exception 'CHECK FAILED: saving a post twice should keep one copy';
  end if;
  if (select body from public.news_items where source_url = 'https://test.local/x/1') <> 'TEST ministry announcement (edited)' then
    raise exception 'CHECK FAILED: saving a post again should update its text';
  end if;
  if (select array_agg(r.external_id || ':' || r.like_count order by r.external_id)
      from public.public_replies r join public.news_items n using (news_id)
      where n.source_url = 'https://test.local/x/1') is distinct from array['r1:2', 'r2:7', 'r3:1'] then
    raise exception 'CHECK FAILED: replies should be added once each, with their latest like counts';
  end if;
  if (select count(*) from public.news_media m join public.news_items n using (news_id)
      where n.source_url = 'https://test.local/x/1') <> 1 then
    raise exception 'CHECK FAILED: saving a post again should replace its images';
  end if;
  if (select avatar_url from public.sources where handle = '@test_source') <> 'https://test.local/avatar.png' then
    raise exception 'CHECK FAILED: the collector should keep the account picture it found';
  end if;
end $$;

select public.uninews_expect_error(
  $sql$ select public.import_x_post('{"handle": "@nobody", "url": "https://test.local/x/2", "text": "x"}') $sql$,
  'P0001', 'a post from an unknown account is refused');

-- ---------------------------------------------------------------------
-- The notes writer (secret key): tags and the note
-- ---------------------------------------------------------------------
select public.save_community_note(jsonb_build_object(
  'news_id', (select news_id from public.news_items where source_url = 'https://test.local/1'),
  'summary', 'TEST most people welcome the timetable',
  'key_points', jsonb_build_array('TEST asks for an earlier start'),
  'replies_read', 5, 'model', 'test-model',
  'categories', jsonb_build_array('Exams'), 'audiences', jsonb_build_array('Students')));

-- A post with an empty summary gets its tags but no note.
select public.save_community_note(jsonb_build_object(
  'news_id', (select news_id from public.news_items where source_url = 'https://test.local/x/1'),
  'summary', '', 'replies_read', 3, 'model', 'test-model',
  'categories', jsonb_build_array('Academic', 'Not a tag'), 'audiences', '[]'::jsonb));

do $$
begin
  if (select category from public.news_cards where source_url = 'https://test.local/x/1') is distinct from array['Academic'] then
    raise exception 'CHECK FAILED: the post should get only known category tags';
  end if;
  if (select community_note from public.news_cards where source_url = 'https://test.local/x/1') is not null then
    raise exception 'CHECK FAILED: an empty summary should leave the post without a note';
  end if;
  if (select (key_points, replies_read, model) from public.community_notes cn
      join public.news_items n using (news_id) where n.source_url = 'https://test.local/1')
     is distinct from (array['TEST asks for an earlier start'], 5, 'test-model'::text) then
    raise exception 'CHECK FAILED: the note should keep its points, how many replies it read and its model';
  end if;
end $$;

select public.uninews_expect_error(
  $sql$ select public.save_community_note('{"news_id": -1, "summary": "x"}') $sql$,
  'P0001', 'a note for a post that does not exist is refused');

reset role;

-- ---------------------------------------------------------------------
-- Guests (not signed in)
-- ---------------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '{"role": "anon"}', true);

do $$
begin
  if (select array_agg(source_url) from public.feed_page(p_limit => 3))
     is distinct from array['https://test.local/1', 'https://test.local/2', 'https://test.local/3'] then
    raise exception 'CHECK FAILED: guests should see the three test posts first, newest first';
  end if;
  -- Students filter: the student post, plus the post that is for everyone
  if (select array_agg(source_url) from public.feed_page(array['Students'], p_limit => 2))
     is distinct from array['https://test.local/1', 'https://test.local/3'] then
    raise exception 'CHECK FAILED: the Students filter should show posts for students and posts for everyone';
  end if;
  if (select array_agg(source_url) from public.feed_page('{}', array['Administrative'], p_limit => 1))
     is distinct from array['https://test.local/2'] then
    raise exception 'CHECK FAILED: the Administrative tag should show the staff meeting first';
  end if;
  if (select source_url from public.feed_page(p_limit => 2, p_offset => 2) limit 1) <> 'https://test.local/3' then
    raise exception 'CHECK FAILED: the second page of two should start with the third post';
  end if;
  if (select reply_count from public.news_cards where source_url = 'https://test.local/x/1') <> 3 then
    raise exception 'CHECK FAILED: a post should count its public replies';
  end if;
  if (select community_note ->> 'summary' from public.news_cards where source_url = 'https://test.local/1')
     is distinct from 'TEST most people welcome the timetable' then
    raise exception 'CHECK FAILED: guests should see the community note under a post';
  end if;
  if (select community_note from public.news_cards where source_url = 'https://test.local/2') is not null then
    raise exception 'CHECK FAILED: a post without a note should have no note';
  end if;
end $$;

select public.uninews_expect_error(
  $sql$ insert into public.comments (news_id, body) select news_id, 'Hi' from public.news_items where source_url = 'https://test.local/1' $sql$,
  '42501', 'guests cannot comment');
select public.uninews_expect_error(
  $sql$ insert into public.news_items (source_id, source_url, body) values (1, 'https://test.local/fake', 'Fake') $sql$,
  '42501', 'guests cannot write news');
select public.uninews_expect_error(
  $sql$ select public.import_x_post('{"handle": "@test_source", "url": "https://test.local/x/3", "text": "x"}') $sql$,
  '42501', 'guests cannot use the collector function');
select public.uninews_expect_error(
  $sql$ select public.save_community_note('{"news_id": 1, "summary": "Fake"}') $sql$,
  '42501', 'guests cannot write community notes');

-- ---------------------------------------------------------------------
-- Member A (signed in)
-- ---------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}', true);

insert into public.comments (news_id, body)
select news_id, 'First comment from A' from public.news_items where source_url = 'https://test.local/1';

do $$
declare
  changed integer;
begin
  if (select user_id from public.comments where body = 'First comment from A') is distinct from '00000000-0000-0000-0000-00000000000a' then
    raise exception 'CHECK FAILED: a comment should belong to the member who wrote it';
  end if;
  if (select comment_count from public.news_cards where source_url = 'https://test.local/1') <> 1 then
    raise exception 'CHECK FAILED: the post should count its comment';
  end if;

  update public.profiles set display_name = 'Member A' where user_id = '00000000-0000-0000-0000-00000000000a';
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'CHECK FAILED: a member should be able to edit their own profile'; end if;

  update public.profiles set display_name = 'Hacked' where user_id = '00000000-0000-0000-0000-00000000000b';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'CHECK FAILED: a member must not edit another member''s profile'; end if;
end $$;

select public.uninews_expect_error(
  $sql$ insert into public.comments (news_id, user_id, body)
        select news_id, '00000000-0000-0000-0000-00000000000b', 'Pretending to be B' from public.news_items where source_url = 'https://test.local/1' $sql$,
  '42501', 'a member cannot comment as someone else');
select public.uninews_expect_error(
  $sql$ insert into public.news_items (source_id, source_url, body) values (1, 'https://test.local/fake', 'Fake') $sql$,
  '42501', 'members cannot write news');
select public.uninews_expect_error(
  $sql$ insert into public.public_replies (news_id, external_id, body, posted_at)
        select news_id, 'fake', 'Fake reply', now() from public.news_items where source_url = 'https://test.local/1' $sql$,
  '42501', 'members cannot add public replies');
select public.uninews_expect_error(
  $sql$ update public.community_notes set summary = 'Changed' $sql$,
  '42501', 'members cannot change community notes');

select public.uninews_expect_error(
  $sql$ delete from public.comments where body = 'First comment from A' $sql$,
  '42501', 'the app cannot delete comments');
select public.uninews_expect_error(
  $sql$ update public.comments set body = 'Changed' where body = 'First comment from A' $sql$,
  '42501', 'the app cannot change comments');

reset role;
rollback;
