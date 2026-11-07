"""Copies the files that may be public into a clone of the public GitHub repository, and refuses if
any of them holds something that must stay private.

    git clone https://github.com/mohammedzayd19992-hash/weshfatak-lab.git ../weshfatak-lab
    python tools/export_public.py ../weshfatak-lab
    cd ../weshfatak-lab && git status          # review, then commit and push

What is published: the source of the app, the collectors and the database, the docs and the tests.
What never is (the rules in SKIP below):
  - secrets: collector/.env, app/config/live.json (the live project's address and key), signing keys;
  - what was collected: collector/data, logs, the X sign-in profile;
  - the live project's history: database/news-import, v1-archive and the migrations only it needed;
  - build output, APKs, editor settings and files Flutter writes on each computer.
The live project's id is replaced by YOUR-PROJECT-REF wherever it appears (the SQL that created Shaqra
University points its logo at the live project's storage). Then every published text file is checked
for the live project's address and keys (read from the private files above, so they are never
written here), key-shaped strings, this computer's user folder and email addresses that are not an
institution's public contact or a made-up example. If anything is found, nothing is copied.
"""

import fnmatch
import json
import re
import shutil
import sys
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent

# Folders and files that are published, relative to SOURCE.
INCLUDE = ["README.md", "DEMO.md", "PROTOCOL.md", "RELEASE-CHECKLIST.md", "SHARING.md", ".gitignore", "app",
           "collector", "database", "tools"]

SKIP = [
    # secrets and keys
    "collector/.env", "app/config/live.json", "*.jks", "*.keystore", "*key.properties",
    # collected data, logs and sign-ins
    "collector/data", "collector/logs", "collector/x-profile", "*.log",
    # the live project's history
    "database/news-import", "database/v1-archive", "database/migrate-from-v1.sql", "database/migrate-to-ministry.sql",
    # build output and machine files
    "app/build", "app/.dart_tool", "app/.flutter-plugins", "app/.flutter-plugins-dependencies",
    "app/android/local.properties", "app/android/.gradle", "app/android/.kotlin", "app/android/app/debug",
    "app/android/app/profile", "app/android/app/release", "app/android/gradlew", "app/android/gradlew.bat",
    "app/android/gradle/wrapper/gradle-wrapper.jar",
    "app/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
    "app/ios", "app/linux", "app/macos", "app/windows", "*.iml", ".idea", ".vscode", "__pycache__", "*.pyc",
    "*.apk", "*.aab", ".DS_Store", "Thumbs.db",
]

# Public contacts the Info page shows, and made-up addresses used in tests and the demo.
ALLOWED_EMAILS = {"info@su.edu.sa"}
ALLOWED_EMAIL_DOMAINS = ("example.com", "example.org", "example.invalid", ".local", ".test", "anthropic.com")

KEY_SHAPES = re.compile(
    r"sb_secret_[\w-]{8,}"                    # Supabase secret key
    r"|sb_publishable_(?!YOUR)[\w-]{8,}"      # a real publishable key (placeholders say YOUR)
    r"|eyJ[\w-]{10,}\.eyJ[\w-]{10,}\.[\w-]+"  # a JWT, such as an old service_role key
    r"|-----BEGIN [A-Z ]*PRIVATE KEY-----"
    r"|\bAIza[\w-]{35}"                       # Google API key (YouTube)
    r"|\bsk-ant-[\w-]{20,}"                   # Anthropic API key
    r"|\bgh[pousr]_[A-Za-z0-9]{36}"           # GitHub token
    r"|\bAKIA[0-9A-Z]{16}")                   # AWS key
EMAIL = re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+")
TEXT = {".md", ".py", ".dart", ".sql", ".json", ".yaml", ".yml", ".kts", ".kt", ".xml", ".html", ".txt", ".example",
        ".gitignore", ".properties", ".metadata", ".lock", ".cfg", ".toml", ".env"}


def skipped(relative):
    parts = relative.split("/")
    for rule in SKIP:
        if "/" in rule:
            if relative == rule or relative.startswith(rule + "/"):
                return True
        elif any(fnmatch.fnmatch(part, rule) for part in parts):
            return True
    return False


def files():
    for name in INCLUDE:
        top = SOURCE / name
        if top.is_file():
            yield name
        elif top.is_dir():
            for path in sorted(top.rglob("*")):
                relative = path.relative_to(SOURCE).as_posix()
                if path.is_file() and not skipped(relative):
                    yield relative


def project_id():
    """The live project's id (the first part of its address), from the private app/config/live.json."""
    live = SOURCE / "app" / "config" / "live.json"
    if not live.exists():
        return None
    host = re.match(r"https://([\w-]+)\.", json.loads(live.read_text(encoding="utf-8")).get("SUPABASE_URL", ""))
    return host.group(1) if host else None


def private_values():
    """The live project's address, project id and keys, read from the private files, never stored here."""
    values = set()
    live = SOURCE / "app" / "config" / "live.json"
    if live.exists():
        config = json.loads(live.read_text(encoding="utf-8"))
        values |= {config.get("SUPABASE_URL", ""), config.get("SUPABASE_PUBLISHABLE_KEY", "")}
        if project_id():
            values.add(project_id())
    env = SOURCE / "collector" / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            if key.strip().endswith(("KEY", "URL", "TOKEN", "SECRET")) and len(value.strip()) > 8:
                values.add(value.strip())
    values |= {str(Path.home()), Path.home().as_posix()}
    return {value for value in values if len(value) >= 8}


def problems(relative, text, secrets):
    found = [f"{relative}: holds a private value ({value[:6]}...)" for value in secrets if value in text]
    found += [f"{relative}: key-shaped text ({match.group(0)[:12]}...)" for match in KEY_SHAPES.finditer(text)]
    user = Path.home().name
    if re.search(rf"[\\/]Users[\\/]{re.escape(user)}\b", text, re.I):
        found.append(f"{relative}: names this computer's user folder")
    for match in EMAIL.finditer(text):
        address = match.group(0).lower()
        if address not in ALLOWED_EMAILS and not address.endswith(ALLOWED_EMAIL_DOMAINS):
            found.append(f"{relative}: email address {address}")
    return found


def export(target):
    target = Path(target).resolve()
    if not (target / ".git").exists():
        sys.exit(f"{target} is not a clone of the public repository (no .git folder).")
    if SOURCE in target.parents or target == SOURCE:
        sys.exit("The target must be outside the source folder.")
    chosen = list(files())
    secrets = private_values()
    live_id = project_id()
    texts, trouble = {}, []
    for relative in chosen:
        path = SOURCE / relative
        if path.suffix in TEXT or path.name in TEXT or path.suffix == "":
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if live_id:
                text = text.replace(live_id, "YOUR-PROJECT-REF")
            texts[relative] = text
            trouble += problems(relative, text, secrets)
    if trouble:
        sys.exit("Nothing was copied. Fix these first:\n  " + "\n  ".join(trouble))
    # Mirror: remove what is no longer published, then copy.
    for old in sorted(target.rglob("*"), reverse=True):
        relative = old.relative_to(target).as_posix()
        if relative == ".git" or relative.startswith(".git/"):
            continue
        if old.is_file() and relative not in chosen:
            old.unlink()
        elif old.is_dir() and not any(old.iterdir()):
            old.rmdir()
    for relative in chosen:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if relative in texts:
            with open(destination, "w", encoding="utf-8", newline="") as file:
                file.write(texts[relative])
        else:
            shutil.copy2(SOURCE / relative, destination)
    print(f"Copied {len(chosen)} files to {target}; none holds a private value, key, user folder or private email.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    export(sys.argv[1])
