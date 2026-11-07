-- WeshFatak 1.7.0: close what the old accounts left open.
--
-- The app has had no accounts, sign-in or comments since 1.4.0, but the database still let a
-- signed-in member add comments and a profile, and let anyone read the profiles' names. Supabase
-- still accepts new sign-ups with the public key, so anyone could create a member, and notes.py
-- read those comments into the AI's question. After this file:
--   - nobody but the service role can add or change comments or profiles;
--   - the profiles' names are no longer readable with the public key;
--   - comments stay readable (no new ones can arrive) because news_cards, a security_invoker view,
--     counts them for every reader.
-- It only takes rights away, so every app version keeps reading the news. It checks itself at the end.
-- Also turn off sign-ups in the Supabase dashboard: Authentication -> Sign In / Providers.

drop policy if exists "Members comment as themselves" on public.comments;
drop policy if exists "Members create their own profile" on public.profiles;
drop policy if exists "Members edit their own profile" on public.profiles;
drop policy if exists "Anyone can read profiles" on public.profiles;

-- Revoking a table right also revokes the column rights granted with it.
revoke insert, update, delete, truncate on public.comments from public, anon, authenticated;
revoke all on public.profiles from public, anon, authenticated;

do $check$
begin
  if has_any_column_privilege('authenticated', 'public.comments', 'INSERT')
     or has_any_column_privilege('anon', 'public.comments', 'INSERT') then
    raise exception 'WeshFatak: comments can still be added';
  end if;
  if has_table_privilege('anon', 'public.profiles', 'SELECT')
     or has_table_privilege('authenticated', 'public.profiles', 'SELECT')
     or has_any_column_privilege('authenticated', 'public.profiles', 'INSERT')
     or has_any_column_privilege('authenticated', 'public.profiles', 'UPDATE') then
    raise exception 'WeshFatak: profiles are still open';
  end if;
  if not has_table_privilege('anon', 'public.news_cards', 'SELECT')
     or not has_table_privilege('anon', 'public.comments', 'SELECT') then
    raise exception 'WeshFatak: the news would no longer load';
  end if;
end
$check$;
