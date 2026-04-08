#!/usr/bin/env python3
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


def decrypt_aes_gcm(data, key):
    """Decrypt AES-256-GCM: nonce (12) || ciphertext || tag (16)."""
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


def find_window_for_session(session_id):
    """Find the X window ID for a terminal running an ARC session."""
    try:
        # Search /proc for processes with this ARC_SESSION_ID
        for env_file in glob.glob("/proc/[0-9]*/environ"):
            try:
                with open(env_file, "rb") as f:
                    env_data = f.read()
                if f"ARC_SESSION_ID={session_id}".encode() not in env_data:
                    continue
                # Found a process with this session — walk up to find terminal window
                pid = int(env_file.split("/")[2])
                while pid > 1:
                    result = subprocess.run(
                        ["xdotool", "search", "--pid", str(pid)],
                        capture_output=True, text=True, timeout=1
                    )
                    windows = result.stdout.strip()
                    if windows:
                        return int(windows.split("\n")[0])
                    # Walk to parent
                    with open(f"/proc/{pid}/stat") as f:
                        stat = f.read()
                    pid = int(stat.split(")")[1].split()[1])
                break
            except (PermissionError, FileNotFoundError, ProcessLookupError,
                    ValueError, subprocess.TimeoutExpired):
                continue
    except Exception:
        pass
    return 0


def listen_plain(port):
    """Listen for plain-text messages (direct Claude hooks)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", port))
    while True:
        data, _ = s.recvfrom(4096)
        print(data.decode().strip(), flush=True)


def listen_arc(port):
    """Listen for ARC encrypted status messages."""
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
            status = msg.get("status", "")
            if status in NOTIFY_STATUSES:
                project = msg.get("project", "")
                session_id = msg.get("sessionID", "")
                wid = find_window_for_session(session_id) if session_id else 0
                print(f"{wid}|{project}", flush=True)
        except Exception:
            pass


t1 = threading.Thread(target=listen_plain, args=(PLAIN_PORT,), daemon=True)
t2 = threading.Thread(target=listen_arc, args=(ARC_PORT,), daemon=True)
t1.start()
t2.start()
t1.join()
