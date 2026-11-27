"""Shared helpers for the host-ids scripts: configuration and EVE file access."""
import glob
import gzip
import json
import os
import re
from datetime import datetime

CONFIG_PATH = os.environ.get("HOST_IDS_CONFIG", "/usr/local/lib/host-ids/config.json")
EVE_PATH = os.environ.get("HOST_IDS_EVE", "/var/log/suricata/eve.json")
# How much of the end of EVE is searched for the newest stats record.
TAIL_BYTES = 1 << 20


def load_config():
    with open(CONFIG_PATH) as handle:
        return json.load(handle)


def rotated_eve_files():
    """Rotated EVE files, oldest first: eve.json.7.gz ... eve.json.2.gz, eve.json.1."""

    def age(path):
        match = re.search(r"\.(\d+)(?:\.gz)?$", path)
        return int(match.group(1)) if match else 0

    return sorted(glob.glob(f"{EVE_PATH}.*"), key=age, reverse=True)


def open_eve(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", errors="replace")
    return open(path, errors="replace")


def last_stats_event(path=None):
    """Returns the newest stats event in the tail of an EVE file, or None."""
    path = path or EVE_PATH
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            handle.seek(max(0, handle.tell() - TAIL_BYTES))
            tail = handle.read().decode(errors="replace")
    except FileNotFoundError:
        return None
    for line in reversed(tail.splitlines()):
        if '"event_type":"stats"' not in line:
            continue
        try:
            return json.loads(line)
        except ValueError:
            continue
    return None


def stats_values(event):
    """The counters the scripts use, from one stats event."""
    stats = event.get("stats", {})
    engine = stats.get("detect", {}).get("engine", {})
    capture = stats.get("capture", {})
    return {
        "timestamp": event.get("timestamp", ""),
        "packets": capture.get("kernel_packets"),
        "drops": capture.get("kernel_drops"),
        "rules_loaded": engine.get("rules_loaded"),
        "rules_failed": engine.get("rules_failed"),
    }


def parse_time(text):
    """Unix seconds from Suricata's 2026-11-26T10:00:00.123456+0000 timestamp, 0 if unreadable."""
    try:
        return int(datetime.strptime(text, "%Y-%m-%dT%H:%M:%S.%f%z").timestamp())
    except ValueError:
        return 0
