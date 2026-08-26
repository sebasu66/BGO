#!/usr/bin/env python3
import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TERMINAL = {"completed", "rejected"}


def request_json(url: str, method: str = "GET", payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        raw = response.read().decode("utf-8")
        return None if raw == "" else json.loads(raw)


def firebase_job_url(base: str, session_id: str, job_id: str) -> str:
    session = urllib.parse.quote(session_id, safe="")
    job = urllib.parse.quote(job_id, safe="")
    return f"{base.rstrip('/')}/games/{session}/github_jobs/{job}.json"


def process_job(job_path: Path, result_path: Path, database_url: str, poll_seconds: float, timeout_seconds: int):
    job = json.loads(job_path.read_text(encoding="utf-8"))
    session_id = str(job.get("session_id", "")).strip()
    job_id = str(job.get("job_id", "")).strip()
    if not session_id or not job_id:
        raise ValueError(f"Invalid BGO job file {job_path}: session_id and job_id are required")

    url = firebase_job_url(database_url, session_id, job_id)
    existing = request_json(url)
    if not isinstance(existing, dict) or str(existing.get("status", "")) not in TERMINAL:
        request_json(url, "PUT", job)

    deadline = time.time() + timeout_seconds
    current = existing if isinstance(existing, dict) else {}
    while time.time() < deadline:
        current = request_json(url)
        if isinstance(current, dict) and str(current.get("status", "")) in TERMINAL:
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_text(
                json.dumps(
                    {
                        "relay": "github-actions-rtdb",
                        "session_id": session_id,
                        "job_id": job_id,
                        "status": current.get("status"),
                        "job": current,
                    },
                    indent=2,
                    sort_keys=True,
                ) + "\n",
                encoding="utf-8",
            )
            return
        time.sleep(poll_seconds)

    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(
        json.dumps(
            {
                "relay": "github-actions-rtdb",
                "session_id": session_id,
                "job_id": job_id,
                "status": "timeout",
                "last_job_snapshot": current,
            },
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobs-root", default="bgo_jobs")
    parser.add_argument("--results-root", default="bgo_results")
    parser.add_argument("--poll-seconds", type=float, default=1.0)
    parser.add_argument("--timeout-seconds", type=int, default=90)
    args = parser.parse_args()

    database_url = os.environ.get(
        "BGO_FIREBASE_DATABASE_URL",
        "https://board-game-online-68c3f-default-rtdb.firebaseio.com",
    )
    jobs_root = Path(args.jobs_root)
    results_root = Path(args.results_root)

    if not jobs_root.exists():
        return

    for job_path in sorted(jobs_root.rglob("*.json")):
        relative = job_path.relative_to(jobs_root)
        result_path = results_root / relative
        if result_path.exists():
            continue
        try:
            process_job(
                job_path,
                result_path,
                database_url,
                args.poll_seconds,
                args.timeout_seconds,
            )
        except (ValueError, urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as exc:
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_text(
                json.dumps(
                    {
                        "relay": "github-actions-rtdb",
                        "status": "relay_error",
                        "error": repr(exc),
                        "job_path": str(job_path),
                    },
                    indent=2,
                    sort_keys=True,
                ) + "\n",
                encoding="utf-8",
            )


if __name__ == "__main__":
    main()
