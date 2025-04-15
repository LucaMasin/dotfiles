from pathlib import Path
import subprocess
import os

def get_folders() -> list[str]:
    with open(os.path.expanduser("~/scripts/.tsesh.folders"), "r") as f:
        return f.read().splitlines()


def get_subfolders(folders: list[str]) -> list[str]:
    subfolders = []
    for folder in folders:
        folder_path = Path(folder)
        folder_path = folder_path.expanduser().resolve()
        for subfolder in folder_path.glob("*"):
            if subfolder.is_dir():
                subfolders.append(str(subfolder))
    return subfolders


def run_tmux_session(folder: str):
    folder_name = Path(folder).name
    tmux_session_name = folder_name.replace(" ", "_").replace("-", "_")
    session_exists = subprocess.run(
        ["tmux", "has-session", "-t", tmux_session_name], capture_output=True, text=True
    )
    if session_exists.returncode == 0:
        # if switch-client fails, attach to the session
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
        # Run fzf without capture_output to allow terminal interaction
        process = subprocess.Popen(
            ["fzf"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
        )

        # Send the folders to fzf's stdin
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
