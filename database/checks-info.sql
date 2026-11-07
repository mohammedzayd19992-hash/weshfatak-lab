-- Checks migrate-to-info.sql. Run after it, in the SQL Editor. Everything happens inside one
-- transaction that is rolled back, so nothing is left behind. Passes when it finishes without an
-- error; a failure starts with "CHECK FAILED:".

begin;

insert into public.organizations (name) values ('TEST Info Organization');

-- A section with items, then the same section again: the second replaces the first.
select public.save_info_section('{"organization": "TEST Info Organization", "kind": "dates", "position": 2,
  "asked": 5, "note": " ", "items": [
  {"title": "TEST break", "starts_on": "2099-01-01", "ends_on": "2099-01-05", "source_name": "TEST", "source_url": "https://test.local/a"},
  {"title": "TEST exams", "starts_on": "2099-02-01", "source_name": "TEST", "source_url": "https://test.local/b"}]}');
select public.save_info_section('{"organization": "TEST Info Organization", "kind": "dates", "position": 1,
  "asked": 7, "items": [
  {"title": "TEST exams", "starts_on": "2099-02-01", "source_name": "TEST", "source_url": "https://test.local/b"}]}');
-- A section without items keeps nothing but its place.
select public.save_info_section('{"organization": "TEST Info Organization", "kind": "numbers", "position": 5}');

do $$
declare
  v_org bigint := (select organization_id from public.organizations where name = 'TEST Info Organization');
begin
  if (select count(*) from public.info_items where organization_id = v_org) <> 1 then
    raise exception 'CHECK FAILED: saving a section again should replace its items';
  end if;
  if (select position from public.info_sections where organization_id = v_org and kind = 'dates') <> 1
     or (select asked from public.info_sections where organization_id = v_org and kind = 'dates') <> 7 then
    raise exception 'CHECK FAILED: saving a section again should update its place and count';
  end if;
  if (select note from public.info_sections where organization_id = v_org and kind = 'dates') is not null then
    raise exception 'CHECK FAILED: a blank note should be stored as no note';
  end if;
  if not exists (select 1 from public.info_sections where organization_id = v_org and kind = 'numbers') then
    raise exception 'CHECK FAILED: a section without items should still be saved';
  end if;
  begin
    perform public.save_info_section('{"organization": "No such place", "kind": "dates", "position": 1}');
    raise exception 'CHECK FAILED: an unknown institution should be refused';
  exception when raise_exception then
    if sqlerrm like 'CHECK FAILED%' then raise; end if;
  end;
  begin
    perform public.save_info_section('{"organization": "TEST Info Organization", "kind": "dates", "position": 1,
      "items": [{"title": "TEST", "source_name": "TEST", "source_url": "https://test.local/c"}]}');
    raise exception 'CHECK FAILED: a date without a day should be refused';
  exception when check_violation then null;
  end;
end $$;

-- The app's key can read but not write.
set local role anon;
do $$
begin
  if (select count(*) from public.info_items where title like 'TEST%') <> 1 then
    raise exception 'CHECK FAILED: anyone should be able to read the info items';
  end if;
  begin
    perform public.save_info_section('{"organization": "TEST Info Organization", "kind": "help", "position": 3}');
    raise exception 'CHECK FAILED: the app key should not be able to save a section';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.info_sections (organization_id, kind, position) values (1, 'help', 1);
    raise exception 'CHECK FAILED: the app key should not be able to write a section';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

rollback;
