-- WeshFatak starter data. Run after schema.sql.
-- The Ministry of Education, its X account and the tags for the filters.
-- Posts and replies come from the X collector (collector/collect.py).

insert into public.organizations (name, website_url) values
  ('Ministry of Education', 'https://moe.gov.sa');

-- The collector fills in the account picture the first time it saves a post.
insert into public.sources (organization_id, name, source_type, url, handle)
select organization_id, 'وزارة التعليم', 'social', 'https://x.com/moe_gov_sa', '@moe_gov_sa'
from public.organizations where name = 'Ministry of Education';

-- The app shows tags in this order.
insert into public.tags (name, tag_group) values
  ('Students',             'audience'),
  ('Teaching Staff',       'audience'),
  ('Administrative Staff', 'audience'),
  ('Academic',             'category'),
  ('Administrative',       'category'),
  ('Activities',           'category'),
  ('Exams',                'category');

