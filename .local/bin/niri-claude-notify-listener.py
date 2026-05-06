#!/usr/bin/env python3
"""Niri port of awesome's claude-notify-listener.

Listens for UDP messages on two ports (plain + ARC-encrypted), and on
"interesting" status events:
  - finds the niri window for the originating ARC session by walking /proc
    for ARC_SESSION_ID
  - sets niri's urgent flag on that window (so Mod+U jumps to it)
  - shows a desktop notification (mako) with a clickable "Open" action that
    focuses the window when clicked
  - suppresses the notification if the alerting workspace is already focused
"""
import glob
import json
import os
import socket
import subprocess
import sys
import threading

KEY_PATH = os.path.expanduser("~/.arc/status.key")
PLAIN_PORT = 19874
ARC_PORT = 19876
NOTIFY_STATUSES = {"idle", "blocked", "shutdown"}
SOUND = "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"


def decrypt_aes_gcm(data, key):
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    nonce = data[:12]
    ciphertext_and_tag = data[12:]
    return AESGCM(key).decrypt(nonce, ciphertext_and_tag, None)


def read_key():
    try:
        with open(KEY_PATH, "rb") as f:
            key = f.read()
        return key if len(key) == 32 else None
    except Exception:
        return None


def niri_msg_json(*args):
    """Run `niri msg --json <args>` and return parsed JSON, or None on error."""
    try:
        r = subprocess.run(
            ["niri", "msg", "--json", *args],
            capture_output=True, text=True, timeout=2,
        )
        if r.returncode != 0:
            return None
        return json.loads(r.stdout)
    except Exception:
        return None


def find_niri_window_for_session(session_id):
    """Find the niri window id whose process tree contains ARC_SESSION_ID."""
    # Collect (pid, app_id) of all niri windows for fast lookup
    windows = niri_msg_json("windows") or []
    pid_to_window = {}
    for w in windows:
        if w.get("pid"):
            pid_to_window[w["pid"]] = w["id"]
    if not pid_to_window:
        return None, None

    # Find any process with ARC_SESSION_ID matching, then walk up parents
    target = f"ARC_SESSION_ID={session_id}".encode()
    for env_path in glob.glob("/proc/[0-9]*/environ"):
        try:
            with open(env_path, "rb") as f:
                if target not in f.read():
                    continue
            pid = int(env_path.split("/")[2])
            # Walk up parent chain looking for a niri window
            while pid > 1:
                if pid in pid_to_window:
                    win_id = pid_to_window[pid]
                    # Find which workspace it's on
                    for w in windows:
                        if w["id"] == win_id:
                            return win_id, w.get("workspace_id")
                    return win_id, None
                # Get parent pid
                try:
                    with open(f"/proc/{pid}/stat") as sf:
                        stat = sf.read()
                    pid = int(stat.split(")")[1].split()[1])
                except Exception:
                    break
        except (PermissionError, FileNotFoundError, ProcessLookupError, ValueError):
            continue
    return None, None


def focused_workspace_id():
    workspaces = niri_msg_json("workspaces") or []
    for ws in workspaces:
        if ws.get("is_focused"):
            return ws.get("id")
    return None


def notify_and_focus(title, body, win_id):
    """Spawn a notify-send that waits for click; focus window on click.
    Runs detached so the listener can process more events."""
    if win_id:
        cmd = (
            f'a=$(notify-send -a Claude -A focus=Open -t 20000 '
            f'"{title}" "{body}" 2>/dev/null); '
            f'[ "$a" = focus ] && niri msg action focus-window --id {win_id} '
            f'&& niri msg action unset-window-urgent --id {win_id} 2>/dev/null; '
            f'makoctl dismiss --all 2>/dev/null'
        )
    else:
        cmd = (
            f'notify-send -a Claude -t 20000 "{title}" "{body}" 2>/dev/null'
        )
    subprocess.Popen(["sh", "-c", cmd])


def play_sound():
    try:
        subprocess.Popen(
            ["paplay", SOUND],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def handle_status(msg):
    status = msg.get("status", "")
    if status not in NOTIFY_STATUSES:
        return
    project = msg.get("project", "") or "unknown"
    session_id = msg.get("sessionID", "")

    win_id, ws_id = (None, None)
    if session_id:
        win_id, ws_id = find_niri_window_for_session(session_id)

    # Suppress notification if user is already on the alerting workspace
    if ws_id and ws_id == focused_workspace_id():
        # Still set urgent so Mod+U works if they leave
        if win_id:
            try:
                subprocess.run(
                    ["niri", "msg", "action", "set-window-urgent", "--id", str(win_id)],
                    timeout=2,
                )
            except Exception:
                pass
        return

    # Set urgent flag
    if win_id:
        try:
            subprocess.run(
                ["niri", "msg", "action", "set-window-urgent", "--id", str(win_id)],
                timeout=2,
            )
        except Exception:
            pass

    title = f"Claude Code [{project}]"
    body = f"Ready for input ({status})"
    notify_and_focus(title, body, win_id)
    play_sound()


def listen_plain(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", port))
    while True:
        data, _ = s.recvfrom(4096)
        try:
            msg = json.loads(data)
            handle_status(msg)
        except Exception:
            pass


def listen_arc(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", port))
    while True:
        data, _ = s.recvfrom(8192)
        try:
            key = read_key()
            if key:
                plaintext = decrypt_aes_gcm(data, key)
                msg = json.loads(plaintext)
            else:
                msg = json.loads(data)
            handle_status(msg)
        except Exception:
            pass


if __name__ == "__main__":
    t1 = threading.Thread(target=listen_plain, args=(PLAIN_PORT,), daemon=True)
    t2 = threading.Thread(target=listen_arc, args=(ARC_PORT,), daemon=True)
    t1.start()
    t2.start()
    t1.join()
