"""Shared helpers for the host scanners: node_exporter textfile metrics and state.

Every scanner exports <scanner>_last_success_timestamp_seconds and
<scanner>_last_run_status. A failed run keeps the previous success time, so a
scanner that keeps failing goes stale instead of looking fresh.
"""
import json
import os
import tempfile
import time
import traceback

TEXTFILE_DIR = os.environ.get("HOST_SCANNING_TEXTFILE_DIR", "/var/lib/node_exporter/textfile")
STATE_DIR = os.environ.get("HOST_SCANNING_STATE_DIR", "/var/lib/host-scanning")
# Test runs set this so their series never mix with the real ones.
TEST_LABEL = os.environ.get("HOST_SCANNING_TEST") == "1"


def _escape(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


class Metrics:
    """Collects samples grouped by metric family, as the text format requires."""

    def __init__(self):
        self._families = {}

    def add(self, name, value, help_text, metric_type="gauge", **labels):
        family = self._families.setdefault(name, {"help": help_text, "type": metric_type, "samples": []})
        if TEST_LABEL:
            labels["test"] = "true"
        family["samples"].append((labels, value))

    def render(self):
        lines = []
        for name, family in self._families.items():
            lines.append(f"# HELP {name} {family['help']}")
            lines.append(f"# TYPE {name} {family['type']}")
            for labels, value in family["samples"]:
                label_text = ",".join(f'{k}="{_escape(v)}"' for k, v in sorted(labels.items()))
                lines.append(f"{name}{{{label_text}}} {value}" if label_text else f"{name} {value}")
        return "\n".join(lines) + "\n"


def _atomic_write(path, text, mode=0o644):
    directory = os.path.dirname(path)
    # The temporary name ends in .tmp, outside node_exporter's *.prom pattern.
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def write_metrics(scanner, metrics):
    _atomic_write(os.path.join(TEXTFILE_DIR, f"{scanner}{test_suffix()}.prom"), metrics.render())


def test_suffix():
    """Suffix for every file a test run writes, so it never touches real ones."""
    return "-test" if TEST_LABEL else ""


def state_path(scanner):
    return os.path.join(STATE_DIR, f"{scanner}{test_suffix()}-state.json")


def load_state(scanner):
    """Returns the saved state; a corrupt file is moved aside and state starts over."""
    path = state_path(scanner)
    try:
        with open(path) as handle:
            return json.load(handle)
    except FileNotFoundError:
        return {}
    except (ValueError, OSError):
        traceback.print_exc()
        os.replace(path, f"{path}.corrupt-{int(time.time())}")
        return {}


def save_state(scanner, state):
    os.makedirs(STATE_DIR, exist_ok=True)
    _atomic_write(state_path(scanner), json.dumps(state, indent=2, sort_keys=True), mode=0o600)


def run_scanner(scanner, collect):
    """Runs collect(metrics, state), then exports freshness metrics either way.

    collect fills metrics and may update state. On an exception the run counts
    as failed, the previous success time is kept, and the scanner's other
    metrics are not rewritten.
    """
    state = load_state(scanner)
    metrics = Metrics()
    status = 1
    try:
        collect(metrics, state)
        state["last_success"] = time.time()
    except Exception:
        traceback.print_exc()
        status = 0
        metrics = Metrics()
    metrics.add(f"{scanner}_last_run_status", status, "1 if the last run of this scanner succeeded")
    if "last_success" in state:
        metrics.add(
            f"{scanner}_last_success_timestamp_seconds",
            int(state["last_success"]),
            "Unix time of this scanner's last successful run",
        )
    if status:
        save_state(scanner, state)
        write_metrics(scanner, metrics)
    else:
        # State changes from a failed run (first-seen times, baselines) are
        # dropped, so only successful observations are recorded.
        _write_failure(scanner, metrics)
    return 0 if status else 1


def _write_failure(scanner, failure_metrics):
    """Keeps the last good results and updates only the freshness series."""
    path = os.path.join(TEXTFILE_DIR, f"{scanner}{test_suffix()}.prom")
    kept = []
    try:
        with open(path) as handle:
            for line in handle:
                if f"{scanner}_last_run_status" in line or f"{scanner}_last_success_timestamp_seconds" in line:
                    continue
                kept.append(line.rstrip("\n"))
    except FileNotFoundError:
        pass
    text = "\n".join(kept) + ("\n" if kept else "") + failure_metrics.render()
    _atomic_write(path, text)
