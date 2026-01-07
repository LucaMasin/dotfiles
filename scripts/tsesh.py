from pathlib import Path
import subprocess
import os
import sys

CONFIG_PATH = os.path.expanduser("~/scripts/.tsesh.folders")

QUERY = sys.argv[1] if len(sys.argv) > 1 else None


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


def main():
    folders = get_folders()
    subfolders = get_subfolders(folders)
    folders_str = "\n".join(subfolders)

    try:
        base_command = ["fzf"]
        if QUERY:
            base_command.append(f"--query={QUERY}")
        process = subprocess.Popen(
            base_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
        )

        selected, _ = process.communicate(input=folders_str)

        if process.returncode == 0:
            selected = selected.strip()
            run_tmux_session(selected)
        else:
            print("No selection made")

    except FileNotFoundError:
        print("Error: fzf is not installed")


if __name__ == "__main__":
    main()
