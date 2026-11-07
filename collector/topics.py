"""What people ask about, and which posts answer the most asked question: is study suspended or
moved online? Plain word patterns, no AI, so anyone can read why a reply or a post was counted.

The patterns match text folded by stories.normalize: no diacritics, ة written ه, أ إ آ written ا,
ى written ي, punctuation as spaces.

Why these topics: in the 257 different replies collected under the Ministry's and Shaqra
University's posts in October 2026, people asked whether study was suspended or moved online
(40 replies, 190 likes), about exams, holidays and dates (24), how to reach someone or why nobody
answers (22) and about the apps and platforms (15). None asked about the statistics. PROTOCOL.md
has the table.
"""

import re

from stories import normalize

# The Info page's sections, in the order used when nobody asked about any of them.
SECTIONS = ["status", "dates", "help", "apps", "numbers"]

# What a reply asks about. A reply can ask about more than one.
ASKS = {
    # "suspend it!", "is there school tomorrow?", "remote or in person?"
    "status": re.compile(
        r"\b[وف]?تعليق\b|\bعلق+و+ا?\b|\bتعلق(?:ون|و)? الدراس"
        r"|\bعن ?بعد\b|\bحضوري|\bدوام (?:بكر|غدا|غدوه)|\b(?:فيه|بكره|بكرا) دوام|\bفي دوام (?:بكر|غدا)"
        r"|\bالدراسه (?:بكر|غدا)|\bمنصه مدرستي"),
    # "when is the holiday?", exams, results, the calendar
    "dates": re.compile(
        r"\b[وف]?(?:ال)?اجاز|\bالتقويم|\bمتي\b.{0,25}(?:تبدا|يبدا|تنتهي|ينتهي|الدراس|الاختبار|النتائج"
        r"|الفصل|الرواتب|المكاف)|\bبدايه الدراسه|\bنهايه الفصل|\bموعد|\b[وف]?(?:ال)?اختبار"
        r"|\b[وف]?(?:ال)?نتائج|\bالنتيجه|\bدرجات"),
    # "how do I reach them?", "nobody answers the email"
    "help": re.compile(
        r"\b[وف]?(?:ال)?تواصل|\bاتواصل|\bما ?(?:ترد|يرد|تردون|يردون)\b|\bماحد يرد|\b(?:ال)?ايميل"
        r"|\b(?:علي|في) الخاص\b|\bبالخاص\b|\bاستفسار|\bاستفسر|\bمعامله|\bتذكر[هت]|\bتذاكر|\bاتصلت"
        r"|\bاتصل\b|\bايصال صوت|\bاصال صوت|\bتوصيل صوت|\bيسمع مشكلت"),
    # Madrasati, Noor, Blackboard and the apps not working
    "apps": re.compile(
        r"\bمدرستي\b|\bمنصه\b|\b(?:نظام|منصه|برنامج|موقع) نور\b|\bبلاك ?بورد|blackboard"
        r"|\b[وف]?(?:ال)?تطبيق|\bمعلق\b|\bما ?يفتح|\b[وف]?عطل|\bتسجيل الدخول|\bما ?(?:دخل|يدخل)"),
}

# An announcement about study itself: suspended, moved online, back in person.
STUDY = re.compile(
    r"\bتعليق (?:ال)?(?:دراسه|حضور|الدوام)|\b[وي]?تعلق (?:ال)?دراسه"
    r"|\b(?:تحويل|تحول|تحويلها|استمرار|تمديد|تطبيق|بدء|انطلاق) (?:ال)?(?:دراسه|تعليم)(?: \S+){0,4} "
    r"(?:عن بعد|عبر منصه|الكترونيا|افتراضيا)"
    r"|\b(?:ال)?دراسه(?: \S+){0,2} عن بعد|\bعن بعد(?: \S+){0,3} (?:غدا|اليوم|حتي|لمده|يوم|الاسبوع)"
    r"|\b(?:استئناف|عوده|استمرار) (?:ال)?دراسه (?:ال)?حضوري|\b(?:ال)?دراسه (?:ال)?حضوريه"
    r"|\bحضوريا\b|\bمنصه مدرستي(?: \S+){0,4} (?:غدا|حتي|بدلا|الاسبوع)")

# Saudi papers also report other countries' school closures; those are not about Saudi study,
# unless the headline also names a Saudi place ("تعليق الدراسة في نجران بعد اعتداء الحوثي").
# Each name may follow و ب ف ل ك and ال ("بتعز", "باليمن", "للمحبوسين").
ABROAD_NAMES = ("يمن|يمني|تعز|سوريا|سوريه|سوري|دير الزور|مصر|مصري|غزه|فلسطين|لبنان|عراق|اردن|كويت"
                "|قطر|بحرين|سلطنه عمان|ليبيا|سودان|تونس|جزائر|باكستان|ايران|تركيا|محبوسين|عقابيه")
ABROAD = re.compile(rf"\b[وبفلك]?(?:ال|لل)?(?:{ABROAD_NAMES})\b"
                    r"|\b[وبفلك]?(?:ال|لل)?(?:فرنس|بريطان|امريك|اوروب|الماني|ايطالي|اسبان|صين|يابان|كوري"
                    r"|روسي|اوكران|افغان|اندونيس|ماليزي|فلبين|نيجير|صومال)\w*"
                    r"|\b[وبفلك]?(?:الهند|الامارات)\b")  # only with ال: هند is a name, إمارات المناطق are Saudi
SAUDI = re.compile(
    r"\bتعليم (?!عن\b)\S+|\bمدارس\b|\bمنصه مدرستي|\bالسعوديه|\bالمملكه|\b[وبفلك]?(?:ال)?(?:رياض|جده|مكه|المدينه المنوره"
    r"|طائف|جازان|نجران|عسير|ابها|باحه|تبوك|حائل|جوف|قصيم|بريده|الشرقيه|دمام|احساء|ينبع|رابغ|درعيه|خرج"
    r"|قريات|عرعر|الحدود الشماليه|سكاكا|خميس مشيط|القنفذه|الليث|شقراء|الدوادمي)\b")


def asks(text):
    """The sections a reply asks about, in SECTIONS order."""
    folded = normalize(text)
    return [section for section in SECTIONS if section in ASKS and ASKS[section].search(folded)]


# Technical and vocational training is its own corporation, not the Ministry's schools or universities.
TRAINING = re.compile(r"\bالتدريب التقني|\b[وبل]?تقني\b|\bالتقني والمهني|\bالكليات التقنيه")
SCHOOLS_OR_UNIVERSITIES = re.compile(r"\bتعليم (?!عن\b)\S+|\bمدارس\b|\bجامع[هت]")


def about_study(text):
    """True when a post or headline announces whether study is suspended, online or in person in
    Saudi schools or universities."""
    folded = normalize(text)
    if not STUDY.search(folded):
        return False
    if ABROAD.search(folded) and not SAUDI.search(folded):
        return False
    return not (TRAINING.search(folded) and not SCHOOLS_OR_UNIVERSITIES.search(folded))


def asked_counts(replies):
    """{section: how many different replies ask about it}. A text posted many times counts once."""
    counts = {section: 0 for section in ASKS}
    seen = set()
    for reply in replies:
        key = normalize(reply)[:80]
        if not key.strip() or key in seen:
            continue
        seen.add(key)
        for section in asks(reply):
            counts[section] += 1
    return counts


def order(counts):
    """The sections, most asked first; ties keep SECTIONS order; the numbers always come last."""
    asked = [section for section in SECTIONS if section != "numbers"]
    return sorted(asked, key=lambda section: (-counts.get(section, 0), SECTIONS.index(section))) + ["numbers"]
