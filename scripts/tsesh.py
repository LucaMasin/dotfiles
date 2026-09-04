from pathlib import Path
import subprocess
import os
import sys
import argparse

CONFIG_PATH = os.path.expanduser("~/scripts/.tsesh.folders")


def get_folders() -> list[str]:
    with open(CONFIG_PATH, "r") as f:
        lines = f.read().splitlines()
    return [line for line in lines if line and not line.startswith("#")]


def get_subfolders(folders: list[str]) -> list[str]:
    subfolders_set = set()
    for folder in folders:
        folder_path = os.path.expanduser(folder)
        try:
            with os.scandir(folder_path) as it:
                for entry in it:
                    if entry.name.startswith("."):
                        continue
                    if entry.is_dir(follow_symlinks=True):
                        subfolders_set.add(entry.path)
        except OSError:
            continue
    return list(subfolders_set)


def run_tmux_session(folder: str):
    folder_name = Path(folder).name
    tmux_session_name = folder_name.replace(" ", "_").replace("-", "_")
    session_exists = subprocess.run(
        ["tmux", "has-session", "-t", tmux_session_name], capture_output=True, text=True
    )
    if session_exists.returncode == 0:
        switch_client = subprocess.run(
            ["tmux", "switch-client", "-t", tmux_session_name],
            capture_output=True,
            text=True,
        )
        if switch_client.returncode != 0:
            subprocess.run(["tmux", "attach-session", "-t", tmux_session_name])
    else:
        subprocess.run(["tmux", "new-session", "-s", tmux_session_name, "-c", folder])


def _herdr_label(folder: str) -> str:
    # basename with ' ', '.', '-' -> '_' (mirrors tmux-sessionizer.sh naming)
    name = Path(folder).name
    return name.replace(" ", "_").replace(".", "_").replace("-", "_")


def _herdr_find_workspace_id(label: str) -> str | None:
    # `herdr workspace list` prints JSON even without a --json flag:
    # {"id": ..., "result": {"type": "workspace_list", "workspaces": [...]}}
    try:
        result = subprocess.run(
            ["herdr", "workspace", "list"], capture_output=True, text=True, timeout=3
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None
        import json

        data = json.loads(result.stdout)
        candidates = []
        if isinstance(data, dict):
            if "workspaces" in data:
                candidates = data["workspaces"]
            elif isinstance(data.get("result"), dict) and "workspaces" in data["result"]:
                candidates = data["result"]["workspaces"]
            else:
                return None
        elif isinstance(data, list):
            candidates = data

        for entry in candidates:
            if not isinstance(entry, dict):
                continue
            # entry may be {label, workspace_id} or {workspace: {label, workspace_id}}
            ws = entry.get("workspace", entry)
            if ws.get("label") == label:
                return ws.get("workspace_id") or ws.get("id") or entry.get("workspace_id") or entry.get("id")
    except Exception:
        return None
    return None


def _herdr_ensure_server():
    # tmux `new-session` auto-starts the server; herdr `workspace create`
    # requires it. Ensure it's up before any workspace call.
    import time

    result = subprocess.run(["herdr", "status"], capture_output=True, text=True)
    combined = (result.stdout or "") + (result.stderr or "")
    if "not running" not in combined:
        return

    # start headless server detached
    try:
        subprocess.Popen(
            ["herdr", "server"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        return

    for _ in range(20):
        time.sleep(0.25)
        r = subprocess.run(["herdr", "status"], capture_output=True, text=True)
        c = (r.stdout or "") + (r.stderr or "")
        if "not running" not in c:
            return


def run_herdr_workspace(folder: str):
    label = _herdr_label(folder)
    if subprocess.run(["which", "herdr"], capture_output=True).returncode != 0:
        print("herdr not found — install with: curl -fsSL https://herdr.dev/install.sh | sh", file=sys.stderr)
        sys.exit(1)

    _herdr_ensure_server()

    existing_id = _herdr_find_workspace_id(label)

    if existing_id:
        focused = subprocess.run(["herdr", "workspace", "focus", existing_id], capture_output=True, text=True)
        if focused.returncode == 0:
            if not os.environ.get("HERDR_PANE_ID") and not os.environ.get("HERDR_ENV") and sys.stdin.isatty() and sys.stdout.isatty():
                os.execvp("herdr", ["herdr"])
            return
        # focus failed (maybe stale id) — fall through to create

    # create (focus makes UI jump inside herdr; outside it just creates)
    create = subprocess.run(
        ["herdr", "workspace", "create", "--cwd", folder, "--label", label, "--focus"],
        capture_output=True,
        text=True,
    )
    # if server raced and wasn't ready, ensure and retry once
    combined = (create.stdout or "") + (create.stderr or "")
    if create.returncode != 0 and "server_not_running" in combined:
        _herdr_ensure_server()
        subprocess.run(["herdr", "workspace", "create", "--cwd", folder, "--label", label, "--focus"])

    if not os.environ.get("HERDR_PANE_ID") and not os.environ.get("HERDR_ENV") and sys.stdin.isatty() and sys.stdout.isatty():
        os.execvp("herdr", ["herdr"])


def parse_args():
    parser = argparse.ArgumentParser(
        description="Select a folder and open a tmux session (or Herdr workspace with --herdr)."
    )
    parser.add_argument(
        "query", nargs="?", default=None, help="Initial fzf search term"
    )
    parser.add_argument(
        "-q",
        "--query",
        dest="explicit_query",
        default=None,
        help="Explicit fzf query flag",
    )
    parser.add_argument(
        "-1",
        "--select-1",
        action="store_true",
        help="Auto-select if only one match",
    )
    parser.add_argument(
        "--herdr",
        action="store_true",
        help="Open a Herdr workspace instead of a tmux session",
    )
    args = parser.parse_args()
    query = args.explicit_query if args.explicit_query is not None else args.query
    return query, args.select_1, args.herdr


def main():
    query, select_1, use_herdr = parse_args()

    # Direct-path shortcut (mirrors tmux-sessionizer.sh): if the query itself
    # is an existing directory, skip fzf and open it directly.
    if query and os.path.isdir(os.path.expanduser(query)):
        folder = os.path.expanduser(query)
        if use_herdr:
            run_herdr_workspace(folder)
        else:
            run_tmux_session(folder)
        return

    folders = get_folders()
    subfolders = get_subfolders(folders)
    folders_str = "\n".join(subfolders)

    try:
        base_command = ["fzf"]
        if query:
            base_command.append(f"--query={query}")
        if select_1:
            base_command.extend(["--bind=change:first,enter:first", "--exit-0"])
        process = subprocess.Popen(
            base_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
        )

        selected, _ = process.communicate(input=folders_str)

        if process.returncode == 0:
            selected = selected.strip()
            if use_herdr:
                run_herdr_workspace(selected)
            else:
                run_tmux_session(selected)
        else:
            print("No selection made")

    except FileNotFoundError:
        print("Error: fzf is not installed")


if __name__ == "__main__":
    main()
