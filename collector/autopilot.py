"""Keeps WeshFatak up to date by itself: every 2.5 hours it runs the collectors, has Codex read the
new replies, and rewrites the Info page. Leave it running.

    python autopilot.py               a round now, then one every 2.5 hours, until you stop it (Ctrl+C)
    python autopilot.py --every 1.5   another number of hours between rounds
    python autopilot.py --once        one round now, then stop
    python autopilot.py --skip x      leave a step out this time (repeatable): x, press, notes, ...
    python autopilot.py status        when each step last ran and how it went
    python autopilot.py install       start it hidden every time you sign in to Windows
    python autopilot.py uninstall     stop starting it at sign-in

A round runs these steps in order. Each is one of the collectors, run as its own program, so one that
fails does not stop the others:
  rss       Shaqra University's feed
  press     SPA and the Saudi papers, and for the Ministry the regional decisions on study
  youtube   the institutions' videos
  x         each X account's newest posts and their replies (opens Chrome with the collector's
            sign-in; after X says "too many requests" it rests for two rounds)
  reviews   the newest App Store reviews
  stats     the numbers, once a day (they change once a semester)
  stories   one story per event
  notes     Codex reads the new replies: the faces and "What people said" (at most NOTES_LIMIT posts)
  info      the Info page: study status, dates, where to ask, in the order people ask about them

Each round's output is added to logs/autopilot-<date>.log, and how each step went to
data/autopilot-status.json. Settings in collector/.env: AUTOPILOT_EVERY_HOURS (2.5),
NOTES_LIMIT (30), AUTOPILOT_SKIP (for example "x,youtube"). The app sees nothing new until
SUPABASE_SECRET_KEY is in collector/.env, so the 2.5-hour loop does not start without it.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

import collect

HERE = Path(__file__).resolve().parent
LOGS = HERE / "logs"
STATUS = HERE / "data" / "autopilot-status.json"
LOCK = HERE / "data" / "autopilot.lock"
STARTUP = Path(os.environ.get("APPDATA", "")) / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup"
LAUNCHER = STARTUP / "WeshFatak autopilot.cmd"
X_REST_ROUNDS = 2

# name, program and arguments, timeout in seconds, hours between runs (None: every round)
STEPS = [
    ("rss", ["rss.py"], 600, None),
    ("press", ["press.py"], 1800, None),
    ("youtube", ["youtube.py"], 900, None),
    ("x", ["collect.py", "run", "--posts", "10", "--days", "10"], 2400, None),  # once per account
    ("reviews", ["reviews.py", "--pages", "2"], 900, None),
    ("stats", ["stats.py"], 1800, 24),
    ("stories", ["stories.py"], 600, None),
    ("notes", ["notes.py"], 3600, None),
    ("info", ["info.py"], 600, None),
]
NAMES = [name for name, *_ in STEPS]


# ---------------------------------------------------------------------------
# Deciding what to run and how it went (no programs started, so these can be tested on their own)
# ---------------------------------------------------------------------------

def due(name, every, last_success, now):
    """True when a step that runs every [every] hours has not succeeded within that time."""
    if every is None or name not in last_success:
        return True
    return now - datetime.fromisoformat(last_success[name]) >= timedelta(hours=every) - timedelta(minutes=10)


def outcome(code, output):
    """'sent', 'saved' (kept in data/ because the secret key is missing), 'nothing new', 'limited'
    (X said too many requests) or 'failed'."""
    if code != 0:
        return "failed"
    if "too many requests" in output.lower():
        return "limited"
    if "Not sent to Supabase" in output:
        return "saved"
    if "Sent " in output:
        return "sent"
    return "nothing new"


def worst(a, b):
    """Of two outcomes of one step (X runs once per account), the one to report."""
    rank = ["nothing new", "sent", "saved", "limited", "failed"]
    return max(a, b, key=lambda result: rank.index(result) if result in rank else -1)


def last_words(output):
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    return lines[-1][:240] if lines else ""


def commands(state, skip, accounts, notes_limit, now):
    """The steps of this round, in order: (name, arguments, timeout), or (name, None, why) when skipped."""
    plan = []
    for name, args, timeout, every in STEPS:
        if name in skip:
            plan.append((name, None, "skipped"))
        elif not due(name, every, state.get("last_success", {}), now):
            plan.append((name, None, "not due"))
        elif name == "x" and state.get("x_rest", 0) > 0:
            plan.append((name, None, f"resting after too many requests ({state['x_rest']} more round(s))"))
        elif name == "x":
            plan += [(f"x {account}", args + ["--account", account], timeout) for account in accounts]
        elif name == "notes":
            plan.append((name, args + ["--limit", str(notes_limit)], timeout))
        else:
            plan.append((name, args, timeout))
    return plan


def info_args(args, results):
    """info.py leaves the study status alone when press.py did not work this round."""
    return args + ["--no-status"] if results.get("press") == "failed" else args


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

class Log:
    """Writes to the console when there is one (pythonw has none) and to today's log file."""

    def __call__(self, text=""):
        stamp = datetime.now().strftime("%H:%M:%S")
        LOGS.mkdir(exist_ok=True)
        with open(LOGS / f"autopilot-{datetime.now():%Y-%m-%d}.log", "a", encoding="utf-8") as file:
            for line in (text.splitlines() or [""]):
                file.write(f"{stamp}  {line}\n")
        if sys.stdout:
            print(text, flush=True)


log = Log()


def read_state():
    try:
        return json.loads(STATUS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def write_state(state):
    STATUS.parent.mkdir(exist_ok=True)
    STATUS.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")


def run_step(name, args, timeout):
    """Runs one collector. Returns (outcome, seconds, its last line)."""
    started = time.monotonic()
    log(f"--- {name}: python {' '.join(args)}")
    try:
        done = subprocess.run([sys.executable, "-u", *args], cwd=HERE, capture_output=True, timeout=timeout,
                              env={**os.environ, "PYTHONIOENCODING": "utf-8"},
                              creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        output = (done.stdout + done.stderr).decode("utf-8", "replace")
        code = done.returncode
    except subprocess.TimeoutExpired as error:
        output = ((error.stdout or b"") + (error.stderr or b"")).decode("utf-8", "replace")
        output += f"\nStopped after {timeout} seconds."
        code = -1
    if output.strip():
        log(output.rstrip())
    result = outcome(code, output)
    seconds = round(time.monotonic() - started)
    log(f"    {name}: {result} in {seconds} s")
    return result, seconds, last_words(output)


def x_accounts():
    """The X accounts the sources table says are collected, without the @."""
    try:
        rows = collect.read("sources?platform=eq.x&status=eq.collected&select=handle&order=source_id")
    except Exception as error:  # no internet: the round goes on without X
        log(f"Could not read the X accounts: {error}")
        return []
    return [row["handle"].lstrip("@") for row in rows if row.get("handle")]


def one_round(skip, notes_limit):
    state = read_state()
    now = datetime.now()
    state["round_started"] = now.isoformat(timespec="seconds")
    state.setdefault("last_success", {})
    log(f"=== Round started {now:%Y-%m-%d %H:%M}")
    results, steps = {}, {}
    accounts = [] if "x" in skip else x_accounts()
    for name, args, timeout in commands(state, skip, accounts, notes_limit, now):
        if args is None:
            log(f"--- {name}: {timeout}")
            steps[name] = {"result": timeout}
            continue
        if name == "info":
            args = info_args(args, results)
        result, seconds, last = run_step(name, args, timeout)
        family = name.split(" ")[0]
        results[family] = worst(results.get(family, result), result)
        steps[name] = {"result": result, "seconds": seconds, "last_line": last,
                       "at": datetime.now().isoformat(timespec="seconds")}
        if result in ("sent", "saved", "nothing new"):
            state["last_success"][family] = datetime.now().isoformat(timespec="seconds")
    if results.get("x") == "limited":
        state["x_rest"] = X_REST_ROUNDS
    elif "x" not in skip and state.get("x_rest", 0) > 0:
        state["x_rest"] -= 1
    state["steps"] = steps
    state["round_finished"] = datetime.now().isoformat(timespec="seconds")
    write_state(state)
    summary = ", ".join(f"{name} {step['result']}" for name, step in steps.items())
    log(f"=== Round finished {datetime.now():%H:%M}: {summary}")
    return state


def alive(pid):
    """True when a process with this id is running. (os.kill(pid, 0) would end it on Windows.)"""
    if os.name == "nt":
        import ctypes
        kernel = ctypes.windll.kernel32
        handle = kernel.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not handle:
            return False
        code = ctypes.c_ulong()
        kernel.GetExitCodeProcess(handle, ctypes.byref(code))
        kernel.CloseHandle(handle)
        return code.value == 259  # STILL_ACTIVE
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def take_lock():
    LOCK.parent.mkdir(exist_ok=True)
    try:
        pid = int(LOCK.read_text().strip())
        if pid != os.getpid() and alive(pid):
            sys.exit(f"The autopilot is already running (process {pid}). Close it first, "
                     f"or delete {LOCK} if that process is not the autopilot.")
    except (OSError, ValueError):
        pass
    LOCK.write_text(str(os.getpid()))


def drop_lock():
    try:
        if LOCK.read_text().strip() == str(os.getpid()):
            LOCK.unlink()
    except OSError:
        pass


def forever(every, skip, notes_limit):
    log(f"WeshFatak autopilot: a round every {every:g} hours. Stop it with Ctrl+C or by closing this window.")
    while True:
        started = time.time()
        try:
            state = one_round(skip, notes_limit)
        except Exception as error:  # a surprise in one round must not stop the next ones
            log(f"=== The round stopped early: {error.__class__.__name__}: {error}")
            state = read_state()
        next_at = started + every * 3600
        state["next_round"] = datetime.fromtimestamp(next_at).isoformat(timespec="seconds")
        write_state(state)
        log(f"Next round at {datetime.fromtimestamp(next_at):%H:%M}.")
        while time.time() < next_at:  # by the clock, so a round that was due while the PC slept runs on waking
            time.sleep(min(30, max(1, next_at - time.time())))


# ---------------------------------------------------------------------------
# Status, install
# ---------------------------------------------------------------------------

def show_status():
    state = read_state()
    if not state:
        print("No round has finished yet.")
    else:
        print(f"Last round: {state.get('round_started', '?')} to {state.get('round_finished', 'still running')}")
        if state.get("next_round"):
            print(f"Next round: {state['next_round']}")
        for name, step in state.get("steps", {}).items():
            line = f"  {name:22} {step['result']}"
            if "seconds" in step:
                line += f" in {step['seconds']} s"
            if step.get("last_line") and step["result"] != "sent":
                line += f"  ({step['last_line']})"
            print(line)
        print(f"Log: {LOGS / f'autopilot-{datetime.now():%Y-%m-%d}.log'}")
    try:
        pid = int(LOCK.read_text().strip())
        print(f"Running now as process {pid}." if alive(pid) else "Not running now.")
    except (OSError, ValueError):
        print("Not running now.")


def install():
    pythonw = Path(sys.executable).with_name("pythonw.exe")
    program = pythonw if pythonw.exists() else Path(sys.executable)
    LAUNCHER.write_text(
        "@echo off\r\n"
        "rem Starts the WeshFatak autopilot hidden at sign-in. Delete this file to stop that.\r\n"
        f'cd /d "{HERE}"\r\n'
        f'start "" "{program}" "{HERE / "autopilot.py"}"\r\n', encoding="utf-8")
    print(f"Installed: {LAUNCHER}\nIt starts hidden the next time you sign in to Windows. "
          "To start it now without a window, run:\n"
          f'  start "" "{program}" "{HERE / "autopilot.py"}"\n'
          "Check on it with: python autopilot.py status")


def uninstall():
    try:
        LAUNCHER.unlink()
        print(f"Removed {LAUNCHER}. It will no longer start at sign-in.")
    except FileNotFoundError:
        print("It was not installed.")


def main():
    env = collect.read_env()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--every", type=float, default=float(env.get("AUTOPILOT_EVERY_HOURS") or 2.5),
                        help="hours between rounds (default 2.5)")
    parser.add_argument("--once", action="store_true", help="one round, then stop")
    parser.add_argument("--skip", action="append", default=[], choices=NAMES, metavar="STEP",
                        help="leave a step out: " + ", ".join(NAMES))
    parser.add_argument("command", nargs="?", choices=["status", "install", "uninstall"])
    args = parser.parse_args()
    if args.command == "status":
        return show_status()
    if args.command == "install":
        return install()
    if args.command == "uninstall":
        return uninstall()

    skip = set(args.skip) | {name.strip() for name in (env.get("AUTOPILOT_SKIP") or "").split(",") if name.strip()}
    notes_limit = int(env.get("NOTES_LIMIT") or 30)
    if not env.get("SUPABASE_SECRET_KEY"):
        if not args.once:
            log("SUPABASE_SECRET_KEY is empty in collector/.env, so nothing would reach the app. "
                "Paste the secret key (Supabase dashboard -> Project Settings -> API Keys) and start "
                "again. python autopilot.py --once still runs one round that only saves files.")
            sys.exit(1)  # logged too, since a hidden start at sign-in has no window to show it
        log("No SUPABASE_SECRET_KEY: this round only saves its files in data/. Codex is not asked, "
            "because notes it cannot save would be asked for again next time.")
        skip.add("notes")
    take_lock()
    try:
        if args.once:
            one_round(skip, notes_limit)
        else:
            forever(args.every, skip, notes_limit)
    except KeyboardInterrupt:
        log("Stopped.")
    finally:
        drop_lock()


if __name__ == "__main__":
    sys.exit(main())
