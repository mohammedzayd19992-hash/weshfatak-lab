"""Collects each institution's statistics. Every number keeps its period and the link it came from.

    python stats.py                 collect, save and send to Supabase
    python stats.py upload FILE     send a file saved by an earlier run to Supabase

Three kinds of source:
- Shaqra University's open data API (opendata.su.edu.sa), which only its open data page mentions:
  admissions by college, diploma students and graduates, faculty and staff, Blackboard use.
  The yearly tables are asked for from this Hijri year back, and the newest year with data is kept.
- The App Store: the overall rating of every official app (sources with platform 'app_store').
- stats/*.json, written by hand from official reports and statements, each with its link.
"""

import argparse
import json
import sys
import urllib.error
from collections import Counter
from datetime import date
from pathlib import Path

import collect

HERE = Path(__file__).resolve().parent
SHAQRA = "Shaqra University"
SHAQRA_API = "https://opendata.su.edu.sa/api/"
SHAQRA_SOURCE = "البيانات المفتوحة - جامعة شقراء"
LOOKUP = "https://itunes.apple.com/lookup?id={app}&country=sa"
# English job grades in the faculty list, in Arabic like the others.
GRADES = {"Lecturer": "محاضر", "Assistant Professor": "استاذ مساعد",
          "Associate Professor": "استاذ مشارك", "Professor": "استاذ", "Teaching Assistant": "معيد"}


# ---------------------------------------------------------------------------
# Turning API answers into statistics (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def hijri_year(today=None):
    """The Hijri year a Gregorian date falls in, near enough to pick which tables to ask for."""
    today = today or date.today()
    return int((today.toordinal() - date(622, 7, 19).toordinal()) / 354.367) + 1


def bars(counts, top=12):
    """[{"label", "value"}] largest first, the smallest beyond [top] added up as "أخرى"."""
    ordered = sorted(((name.strip(), value) for name, value in counts.items() if value), key=lambda kv: -kv[1])
    kept = [{"label": name, "value": value} for name, value in ordered[:top]]
    rest = sum(value for _, value in ordered[top:])
    return kept + ([{"label": "أخرى", "value": rest}] if rest else [])


def stat(section, label, value, period, source_url, position, unit=None, breakdown=None,
         organization=SHAQRA, source_name=SHAQRA_SOURCE):
    return {"organization": organization, "section": section, "label": label, "value": value,
            "unit": unit, "period": period, "breakdown": breakdown or [], "source_name": source_name,
            "source_url": source_url, "position": position}


def by_college(answer, key="student_Count"):
    return Counter({row["college"]: row[key] for row in answer.get("data", [])})


def studied_abroad(people):
    """The share of people whose last degree is from a university outside Saudi Arabia, in %."""
    known = [p for p in people if (p.get("universityCountry") or "").strip()]
    abroad = [p for p in known if "السعودية" not in p["universityCountry"] and "saudi" not in p["universityCountry"].lower()]
    return round(100 * len(abroad) / len(known), 1) if known else None


def faculty_stats(members, url, period):
    grades = Counter(GRADES.get(m["grade"], m["grade"]) for m in members if m.get("grade"))
    genders = Counter(m["gender"] for m in members if m.get("gender"))
    found = [
        stat("people", "أعضاء هيئة التدريس", len(members), period, url, 10, breakdown=bars(grades)),
        stat("people", "أعضاء هيئة التدريس حسب الجنس", len(members), period, url, 11, breakdown=bars(genders)),
    ]
    share = studied_abroad(members)
    if share is not None:
        found.append(stat("people", "أعضاء هيئة التدريس من خريجي جامعات خارج المملكة", share, period, url, 12, unit="%"))
    return found


def staff_stats(staff, url, period):
    genders = Counter(m["gender"] for m in staff if m.get("gender"))
    return [stat("people", "الموظفون الإداريون والفنيون", len(staff), period, url, 13, breakdown=bars(genders))]


BLACKBOARD = {  # Blackboard figure -> (label in the app, position)
    "عدد الطلاب": ("الطلاب في نظام بلاك بورد", 30),
    "عدد أعضاء هيئة التدريس": ("أعضاء هيئة التدريس في بلاك بورد", 31),
    "عدد المقررات النشطة": ("المقررات النشطة في بلاك بورد", 32),
    "عدد الفصول الافتراضية": ("الفصول الافتراضية", 33),
    "متوسط عمليات تسجيل الدخول اليومية": ("متوسط تسجيلات الدخول اليومية", 34),
    "عدد الاختبارات المسلمة": ("الاختبارات الإلكترونية المسلّمة", 35),
}


def blackboard_stats(answer, url, period):
    found = []
    for row in answer.get("blackboardStatisticsList", []):
        if row.get("title") in BLACKBOARD:
            label, position = BLACKBOARD[row["title"]]
            found.append(stat("digital", label, row["count"], period, url, position))
    return found


def app_rating(app, listing, today):
    """The app's overall App Store rating, or None when Apple shows none."""
    results = listing.get("results") or []
    if not results or not results[0].get("userRatingCount"):
        return None
    result = results[0]
    name = app["name"] if app["name"].startswith("تطبيق") else f"تطبيق {app['name']}"
    return stat("digital", f"تقييم {name} في App Store", round(result["averageUserRating"], 2),
                today.strftime("%Y-%m"), app["url"], 50, unit="/5",
                organization=app["organization"], source_name="App Store",
                breakdown=[{"label": "عدد التقييمات", "value": result["userRatingCount"]}])


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

def get_json(url):
    _, raw = collect.fetch(url, timeout=60)
    return json.loads(raw)


def newest_year(path, has_data):
    """The newest Hijri year whose table at [path] has data: (year, answer) or (None, None)."""
    for year in range(hijri_year(), hijri_year() - 6, -1):
        try:
            answer = get_json(f"{SHAQRA_API}{path}/{year}")
        except (urllib.error.URLError, json.JSONDecodeError):
            continue
        if has_data(answer):
            return year, answer
    return None, None


def shaqra():
    found = []
    url = SHAQRA_API + "FacultyMembers/FacultyMembers"
    found += faculty_stats(get_json(url)["members"], url, str(date.today().year))
    url = SHAQRA_API + "Staff/Staff"
    found += staff_stats(get_json(url)["staffList"], url, str(date.today().year))

    yearly = [  # path, label, section, position
        ("BachelorAdmittedStudentsByCollege", "المقبولون الجدد في البكالوريوس", "study", 20),
        ("DiplomaAdmittedStudentsByCollege", "المقبولون الجدد في الدبلوم", "study", 21),
        ("EnrolledDiplomaStudentsByCollege", "طلاب الدبلوم المسجلون", "study", 22),
    ]
    for path, label, section, position in yearly:
        year, answer = newest_year(path, lambda a: a.get("totalStudents"))
        if year:
            found.append(stat(section, label, answer["totalStudents"], f"{year}هـ",
                              f"{SHAQRA_API}{path}/{year}", position, breakdown=bars(by_college(answer))))
    year, answer = newest_year("GraduatesByFaculty", lambda a: a.get("totalGraduate"))
    if year:
        found.append(stat("study", "خريجو الدبلوم", answer["totalGraduate"], f"{year}هـ",
                          f"{SHAQRA_API}GraduatesByFaculty/{year}", 23,
                          breakdown=bars(by_college(answer, "graduate_Count"))))
    year, answer = newest_year("BlackboardStatistics", lambda a: a.get("blackboardStatisticsList"))
    if year:
        found += blackboard_stats(answer, f"{SHAQRA_API}BlackboardStatistics/{year}", f"{year}هـ")
    return found


def app_ratings(env):
    found = []
    apps = collect.read("sources?platform=eq.app_store&select=name,url,handle,organizations(name)", env)
    for app in apps:
        app["organization"] = app["organizations"]["name"]
        rating = app_rating(app, get_json(LOOKUP.format(app=app["handle"])), date.today())
        if rating:
            found.append(rating)
    return found


def by_hand():
    found = []
    for file in sorted((HERE / "stats").glob("*.json")):
        found += json.loads(file.read_text(encoding="utf-8"))
    return found


def run():
    env = collect.read_env()
    rows = by_hand()
    print(f"{len(rows)} written by hand")
    try:
        found = shaqra()
        print(f"{len(found)} from Shaqra University's open data")
        rows += found
    except (urllib.error.URLError, KeyError, json.JSONDecodeError) as error:
        print(f"Shaqra University's open data could not be read: {error}")
    found = app_ratings(env)
    print(f"{len(found)} App Store ratings")
    rows += found
    send(collect.save(rows, "stats"))


def send(path):
    collect.upload(path, function="save_institution_stat", argument="p_stat", script="stats.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command")
    upload_command = commands.add_parser("upload", help="send a saved file to Supabase")
    upload_command.add_argument("file")
    args = parser.parse_args()
    if args.command == "upload":
        send(args.file)
    else:
        run()


if __name__ == "__main__":
    sys.exit(main())
