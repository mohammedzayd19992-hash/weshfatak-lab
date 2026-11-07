# WeshFatak source protocol · بروتوكول المصادر

How WeshFatak finds **every** official channel of an education institution, including the ones no page links to, checks that each is really official, and records it so the app can show news, opinions and numbers from it. Run it once when adding an institution, then again each semester.

The Ministry of Education and Shaqra University were the first two institutions it was run on. What it found is in the [worked examples](#worked-examples).

## The rules

1. **Public and meant for the public only.** A source qualifies when anyone can open it without signing in and the institution published it for readers: pages, feeds, official accounts, app store listings, open data services. Never use internal or admin endpoints (SharePoint `_api`, CMS back offices, staff portals), login-only groups, or anything found by guessing private addresses. "Hidden" means *unlinked but public* (an RSS feed the site never links, an open-data API mentioned once), not *private*.
2. **Official means proven.** A channel counts as official when one of these holds, checked in this order:
   - the institution's own website links to it;
   - it appears in [Raqmi](https://raqmi.dga.gov.sa), the Digital Government Authority's register of licensed government platforms;
   - the store listing names the institution (or its contracted developer, named on the institution's site) as the publisher;
   - the platform marks it as a verified government account and it links back to the official website.
   A look-alike account with none of these is not a source, however popular.
3. **Never keep who wrote an opinion.** Replies and reviews keep the text, time, likes or stars, and app version. Names, handles and profile pictures of the public are never stored.
4. **Every number keeps its period and its link.** A statistic without both is not added.
5. **Respect each platform's terms and pace.** Read at a person's pace, stop on "too many requests", prefer an official feed or API over reading pages. Where a platform forbids automated collection (LinkedIn, Snapchat stories), the channel is recorded as `planned` or `unavailable`, not scraped.
6. **Record everything found, even what is not collected yet.** The Sources tab in the app shows what is collected and what is not, so nobody mistakes partial coverage for the whole picture.

## The steps

Work through all nine layers for each institution. Each layer lists where to look and the hidden places people usually miss.

| # | Layer | Where to look | Hidden places to check |
|---|---|---|---|
| 1 | **Website news** | News, announcements, events pages, in Arabic and English | `/rss.xml`, `/ar/rss.xml`, `/feed`, `<link rel="alternate" type="application/rss+xml">` in the page head, `sitemap.xml`. Drupal sites (`/themes/custom/…` in the HTML) almost always have `/ar/rss.xml`; WordPress has `/feed` and `/wp-json/wp/v2/posts`. When a site gives its news list only through an internal API (SharePoint), Google News still lists its news pages: search `site:` with the news folder (`site:moe.gov.sa/ar/mediacenter/MOENews/Pages`), not the whole site, which also lists department and contact pages. |
| 2 | **Main social accounts** | Website footer, the institution's "social media" page | Raqmi record; the account's bio link must point back to the official site. |
| 3 | **Sub-accounts** | Deanships, colleges, student affairs, admissions, hospitals, customer care | The website's departments list; accounts the main account follows or reposts; the "تواصل" (customer care) channels. |
| 4 | **Replies under official posts** | Replies on X, comments on YouTube | The most-liked replies first; replies that are about something else (a complaint under an awareness post) are the most useful. |
| 5 | **Official apps** | App Store and Google Play, searched by the institution's name | Search by **publisher**: "Saudi Ministry of Education" publishes تواصل, مدرستي, مدرستي - النتائج and الدعم الموحد. Apple's public review feed (`itunes.apple.com/sa/rss/customerreviews/id=<app>/json`) gives the latest written reviews with stars. |
| 6 | **Open data** | The institution's open data page, [open.data.gov.sa](https://open.data.gov.sa) | An API documented only on the open data page (Swagger at `/swagger/index.html`, spec at `/swagger/v1/swagger.json`). Yearly tables are often empty for the newest years; ask for earlier Hijri years. |
| 7 | **Numbers in print** | "In numbers" blocks on the home page, annual reports, statistical yearbooks | Ministry statements reported by SPA and major papers (Al-Watan, Okaz, Sabq), always with the date and the year the figure covers. |
| 8 | **Government registries** | Raqmi (platform licences), Etimad (tenders), Jadarat (jobs) | Used to verify and to explain, rarely as news. |
| 9 | **Media coverage** | SPA and Saudi newspapers (the list is `OUTLETS` in `collector/press.py`) | Google News search feeds (`news.google.com/rss/search?q=…`), one search per outlet (`"وزارة التعليم" site:sabq.org`): a search across all outlets returns mostly other countries' ministries. Google ignores `when:` in a search by site, so filter by date. Leave out sites that republish foreign news (Tawasul) or whose old reports Google dates as new (Al-Shamal). Keep a report only when its headline names the institution. For the Ministry, also search each outlet, and the Saudi e-papers in `STUDY_OUTLETS`, for study being suspended, moved online or back in person: those decisions are announced region by region ("تعليم الرياض …") and rarely name the Ministry. Keep them for ten days, Saudi ones only, without technical training (a separate corporation), tag pages or other countries' closures. |

For each channel found, decide its **role** and **status**:

- role: `news` (the institution's own posts), `opinions` (what the public says) or `stats` (numbers).
- status: `collected` (a collector reads it), `manual` (entered by hand with its source), `planned` (found and verified, no collector yet) or `unavailable` (exists but cannot be collected under rule 1 or 5).

## Recording a source

Every channel is a row in the `sources` table (`database/migrate-to-institutions.sql`):

| column | example |
|---|---|
| `organization_id` | Shaqra University |
| `name` | جامعة شقراء |
| `platform` | `x`, `rss`, `website`, `instagram`, `snapchat`, `youtube`, `linkedin`, `app_store`, `open_data`, `media` (the press), … |
| `role` | `news` |
| `status` | `collected` |
| `url` | `https://www.su.edu.sa/ar/rss.xml` |
| `handle` | `@ShaqraUni` for X; the app id for an App Store app |
| `note` | in Arabic: how it was found and how it is collected, or why not |

A statistic is a row in `institution_stats` with its `section` (people, study, digital, research), `label` in Arabic, `value`, `unit`, `period`, optional `breakdown` bars, `source_name` and `source_url`.

## Collecting

| Collector | What it reads | When |
|---|---|---|
| `collector/rss.py` | every `rss` source: new posts only, headline and opening sentence, the editor's name dropped | daily |
| `collector/press.py` | every `media` source: SPA's and the Saudi papers' reports naming the institution, and the institution's own news pages that Google lists; headline, outlet, time and link | daily |
| `collector/youtube.py` | every `youtube` source: the latest 15 videos, and their public comments when `YOUTUBE_API_KEY` is set | daily |
| `collector/collect.py run --account <handle>` | an X account's posts and the replies under them (needs a signed-in Chrome, see `collector/README.md`) | weekly |
| `collector/reviews.py` | every `app_store` source: up to 500 latest written reviews per app | weekly |
| `collector/stats.py` | open data APIs, App Store overall ratings, and the hand-written `collector/stats/*.json` | each semester |
| `collector/stories.py` | groups the same event from different sources into one story (below) | after the news collectors |
| `collector/notes.py` | Codex reads new replies under each post: a face for every reply and the summary of them | after stories |
| `collector/info.py` | the Info page: what people ask about most, the newest word on study, the coming dates, where to ask | last |

`collector/autopilot.py` runs them all in this order every 2.5 hours (`stats.py` once a day), so "daily" and "weekly" above are the least each source needs, not how often it runs.

## What people ask, and the Info page

The Info page used to show the numbers that could be found with a source: students, faculty, Blackboard logins. Nobody asked for them. These are the 257 different replies collected under the Ministry's and Shaqra University's posts in October 2026, counted with the word patterns in `collector/topics.py` (a text posted many times counts once; a reply can ask about more than one thing):

| What they asked | Replies | Likes | Examples |
|---|---|---|---|
| Is study suspended, online or in person? | 40 | 190 | "نطالب بتعليق"، "فيه دوام ولا بكره"، "هل الدراسه عن بعد؟" |
| Exams, holidays, results and dates | 24 | 17 | "متى الإجازة؟"، postponed exams |
| How to reach someone, why nobody answers | 22 | 15 | "عمادة القبول ليش ماترد على الايميل؟"، "كيف أتواصل مع الشؤون المالية؟" |
| The apps and platforms | 15 | 11 | "مدرستي معلق مادخل الطلاب" (and 177 of 402 app reviews) |
| The statistics | 0 | 0 | |
| Generic praise that could sit under any post | 77 | | "مبادرة رائعة…" |

So the Info page answers them, in that order: **study** (the newest official posts and Saudi press reports from the last seven days about study being suspended, moved online or back in person, or a plain line saying there were none, with when it was last checked), **coming up** (the academic calendar from `collector/info/*.json`, counting down), **where to ask** (the channels that open a ticket or answer: the Ministry's Tawasul platform and 19996, the university's contact form, phone and email), **its apps**, then **numbers**. `info.py` counts the replies of the last 30 days on every run and puts the most asked first, so the order follows what people ask now; the numbers always come last. A section with nothing to show is left out.

No AI decides any of it: the patterns, the calendar and the channels can each be read and checked, and every line opens its source.

## One story, every source

The same event usually arrives several times: the institution's X post, its website, its YouTube video, and reports in SPA, Sabq or Okaz. The app shows it once. `stories.py` treats two posts of one institution as the same story when they were published within three days and share most of their opening key words, leaving out common words and the institution's own name. The story's main post is the one with the most replies, so its "What people said" covers the whole story; the other copies appear under it as "Also reported by", each opening its own source. Two posts that both have replies stay separate, so no replies are hidden.

## Reading opinions

The mood belongs to the news. Each **reply under a post** gets **one face**, judged on its own words, and the post shows its faces inside its "What people said" summary:

| Face | | Means |
|---|---|---|
| 😄 | happy · سعيد | praise, thanks, support, good wishes about the subject |
| 🤔 | asking · يسأل | a question, a request or a suggestion |
| 😐 | neutral · محايد | information, or greetings and prayers that could sit under any post |
| 😟 | worried · قلق | anxiety about what will happen: results, salaries, transfers, deadlines, privacy |
| 🙃 | sarcastic · ساخر | mockery or irony whose real meaning is negative |
| 😢 | sad · حزين | disappointment, exhaustion or hopelessness, without blaming anyone |
| 😠 | angry · غاضب | a complaint, criticism, blame or frustration |

The charts follow from the faces with no extra AI call: the count of each face per post (`news_cards.emotions`), and for the home screen the faces of all the replies under an institution's news (`institution_cards.emotions`). Below 10 replies the app warns that the sample is small.

App Store reviews are not news, so they are not in the mood. They appear, newest first with their stars, on the institution's Info page next to its apps' ratings. Their stars are not a face either: in 60 reviews read by hand, the stars and the words disagreed in 22, and five gave 4 or 5 stars while complaining (a 4-star "تطبيق سيئ").

### Is AI still needed, and how much?

Yes, for one thing only: reading the replies under each post, which no person could do for every post. Tagging is gone, so:

- A post with **no replies** costs **nothing** (before, every post was sent to Claude to be tagged). Website, RSS and press posts have no replies of their own.
- A post with new replies costs **one** call, which returns the faces and the summary together. The replies themselves stay on the post page, so anyone can check the summary against them.
- Statistics, app reviews, the RSS feed, the press, grouping stories, the charts and the whole Info page need **no** AI. A number, a date or a study announcement is never written by AI.

`notes.py` asks Codex on the ChatGPT plan the Codex app is signed in with (no API key), and each note records the model that wrote it. `--engine claude` asks `claude-opus-5-5` instead.

## Worked examples

Found on 1 November 2026; the press and YouTube were added on 2 November.

### Ministry of Education · وزارة التعليم

| Layer | Channel | Status | How it was found |
|---|---|---|---|
| 2 | X [@moe_gov_sa](https://x.com/moe_gov_sa) | collected | Social media page on moe.gov.sa |
| 2 | Instagram [moe_gov_sa](https://www.instagram.com/moe_gov_sa/) | planned | same page |
| 2 | Snapchat [moe_gov](https://www.snapchat.com/add/moe_gov) | planned (stories expire) | same page |
| 2 | [YouTube channel](https://www.youtube.com/channel/UCNI3mOncSgbjIJJp01EzgVA) | collected (videos; comments need the YouTube Data API key) | same page |
| 1 | [Media centre news](https://moe.gov.sa/ar/mediacenter/MOENews/Pages/default.aspx) | collected through Google News (the page loads its list from the internal SharePoint API) | site navigation |
| 9 | [SPA and Saudi papers](https://news.google.com/search?q=%22%D9%88%D8%B2%D8%A7%D8%B1%D8%A9+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22+OR+%22%D9%88%D8%B2%D9%8A%D8%B1+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22&hl=ar&gl=SA&ceid=SA%3Aar) naming the Ministry or the minister | collected: 42 reports in 45 days from SPA, Sabq, Al-Madina, Ajel, Okaz, Al-Riyadh, Al-Jazirah and Argaam, plus 11 of the Ministry's own news pages | Google News, one search per outlet |
| 5 | App Store: مدرستي (2.96★, 26,801 ratings), مدرستي - النتائج (2.34★), تواصل (2.74★), الدعم الموحد (1.66★) | collected | App Store search by publisher "Saudi Ministry of Education" |
| 6–7 | [Open data](https://moe.gov.sa/ar/knowledgecenter/dataandstats/Pages/opendata.aspx), statements in Al-Watan, Okaz and the Saudi Encyclopedia | manual | Ministry data and statistics pages; press search |

Numbers recorded: 6,815,504 general education students and 32,000 schools (1446H), 415,896 teachers of whom 55% are women (2025), 29 government and 38 private universities and colleges, 1.36 million higher education students (2023), 83.88% higher education enrolment, 56,000+ scholarship students, plus the four apps' ratings.

### Shaqra University · جامعة شقراء

| Layer | Channel | Status | How it was found |
|---|---|---|---|
| 1 | **[RSS feed](https://www.su.edu.sa/ar/rss.xml)** (hidden) | collected | not linked from any page; the site runs Drupal, which publishes `/ar/rss.xml` |
| 1 | [News](https://www.su.edu.sa/ar/news) and [announcements](https://www.su.edu.sa/ar/announcements) | manual (archive) | site navigation; new items arrive through the RSS feed |
| 2 | X [@ShaqraUni](https://x.com/ShaqraUni) | collected | website footer |
| 2 | [YouTube](https://www.youtube.com/user/shaqrauniv), [LinkedIn](https://www.linkedin.com/school/shaqra-university) | planned (the channel's public feed lists no videos) | website footer |
| 9 | [SPA and Saudi papers](https://news.google.com/search?q=%22%D8%AC%D8%A7%D9%85%D8%B9%D8%A9+%D8%B4%D9%82%D8%B1%D8%A7%D8%A1%22&hl=ar&gl=SA&ceid=SA%3Aar) naming the university | collected: 9 reports in 45 days from Sabq, SPA and Ajel, including a Shura Council demand for a plan to improve its rankings | Google News, one search per outlet |
| 5 | [App Store app](https://apps.apple.com/sa/app/id1604564080) (3.73★, 106 ratings) | collected | App Store search; publisher Adaptive TechSoft |
| 6 | **[Open data API](https://opendata.su.edu.sa/swagger/index.html)** (hidden) | collected | mentioned only on the [open data page](https://www.su.edu.sa/ar/open-data/open-data-4); 26 endpoints |
| 8 | Raqmi licence record | used to verify | linked from the website footer |

Numbers recorded from the open data API: 816 faculty by rank and gender, 56.8% of them with their last degree from abroad, 880 administrative and technical staff, 3,575 new bachelor's students by college and 1,885 new diploma students (1445H), 3,351 enrolled diploma students, 497 diploma graduates, and Blackboard use: 19,111 students, 5,542 active courses, 22,991 virtual classes, 76,890 logins a day (1445H).

Not found: Instagram, TikTok, Snapchat or Telegram accounts linked from the website, and no Google Play app. They are not listed until rule 2 can be met.

## Limits

- The App Store feed returns only the latest 500 written reviews per app; star ratings without words are counted in the app's overall rating.
- Replies online come from people who chose to write. A post's faces show what they said, not what every student or teacher thinks, and the app says how many replies they are based on. Posts from the website, the RSS feed and the press have no replies of their own; they show faces only when the same story is on X, or on YouTube once its comments are collected.
- Press reports keep only the headline: Google News links to the article through its own address and gives no text, and the real address can be read only through an internal Google API, which rule 1 rules out.
- Grouping stories by shared words can miss two reports of one event worded differently, or join two events of the same days that share many words. It never joins two posts that both have replies.
- X does not allow automated collection. `collect.py` reads X the way a browser does, with a spare account, and stops when X asks it to.
- The study card finds decisions only where SPA, the papers in `OUTLETS` or the e-papers in `STUDY_OUTLETS` report them. During the alerts of 1 to 5 November 2026, Riyadh's and Taif's move online reached Sada, Saraha and Shahd Now, but Jeddah's reached none of them, so the card would not have shown Jeddah. The regional education departments' own X accounts (layer 3) are the complete source; they are not collected yet.
- The word patterns in `topics.py` can miss a question worded in an unusual way, or count a reply that only uses the same words. They are counts of what people wrote, not a survey.
- The calendar dates are entered by hand from the published calendar (`collector/info/*.json`). A date the institution changes later stays wrong until the file is updated.
