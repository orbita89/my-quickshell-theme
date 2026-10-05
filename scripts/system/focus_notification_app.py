#!/usr/bin/env python3
"""Переключиться на окно приложения, чьё уведомление нажали.

Зачем. По клику оболочка вызывает действие уведомления «default»: Telegram
открывает нужный чат, браузер — вкладку, из которой пришло сообщение. Но под
Wayland приложению, чтобы поднять своё окно, нужен токен активации, а без него
niri только помечает окно как требующее внимания (is_urgent) и фокус не
отдаёт. Поэтому через мгновение после клика этот скрипт проверяет, получило
ли окно приложения фокус, и если нет — переключается на него сам:

  1. окно этого приложения, которое просит внимания (его подняло действие —
     у браузера это окно с нужной вкладкой);
  2. иначе окно этого приложения, бывшее в фокусе последним;
  3. окна нет совсем, а запуск разрешён (--launch) — запускает приложение
     по его .desktop-файлу.

Использование:
  focus_notification_app.py [--delay СЕК] [--launch DESKTOP_ID] [--dry-run] КЛЮЧ...
КЛЮЧ — desktop-entry уведомления или имя приложения; совпадение с app_id окна
ищется без учёта регистра, суффикс вида «._<хэш>» (Telegram) отбрасывается.
"""

import json
import subprocess
import sys
import time


def niri_windows():
    out = subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True, timeout=3)
    return json.loads(out.stdout or "[]")


def normalize(value):
    value = (value or "").strip().lower()
    if value.endswith(".desktop"):
        value = value[: -len(".desktop")]
    # org.telegram.desktop._023d4009… → org.telegram.desktop
    marker = value.find("._")
    if marker > 0:
        value = value[:marker]
    return value


def matches(app_id, keys):
    app = normalize(app_id)
    if not app:
        return False
    return any(app == key or key.startswith(app + ".") or app.startswith(key + ".") for key in keys)


def main(argv):
    delay = 0.35
    launch = ""
    dry_run = False
    keys = []
    args = iter(argv)
    for arg in args:
        if arg == "--delay":
            delay = float(next(args, "0.35"))
        elif arg == "--dry-run":
            dry_run = True
        elif arg == "--launch":
            launch = next(args, "")
        else:
            key = normalize(arg)
            if key:
                keys.append(key)
    if not keys:
        return 0

    # Даём приложению самому обработать нажатие и поднять окно.
    time.sleep(delay)
    windows = niri_windows()
    own = [w for w in windows if matches(w.get("app_id"), keys)]
    if any(w.get("is_focused") for w in own):
        return 0

    target = None
    urgent = [w for w in own if w.get("is_urgent")]
    pool = urgent or own
    if pool:
        target = max(pool, key=lambda w: (w.get("focus_timestamp") or {}).get("secs", 0) * 1e9
                     + (w.get("focus_timestamp") or {}).get("nanos", 0))
    if dry_run:
        print("target:", target and (target["id"], target.get("app_id"), target.get("title")), "launch:", launch)
        return 0
    if target is not None:
        subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(target["id"])], timeout=3)
        return 0

    if launch:
        subprocess.Popen(["gtk-launch", launch], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as error:  # оболочке нужен только факт, без трассировки
        print("focus_notification_app:", error, file=sys.stderr)
        sys.exit(1)
