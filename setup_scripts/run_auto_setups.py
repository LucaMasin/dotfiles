import re
import platform
import os

def get_distro_name():
    """Get the Linux distribution name."""
    try:
        # Try to use /etc/os-release first (most modern distros)
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release", "r") as f:
                os_release = f.read()

            id_match = re.search(r"^ID=(.*)$", os_release, re.MULTILINE)
            if id_match:
                return id_match.group(1).strip("\"'")

            name_match = re.search(r"^NAME=(.*)$", os_release, re.MULTILINE)
            if name_match:
                return name_match.group(1).strip("\"'")

        # Fallback to platform module
        return (
            platform.linux_distribution()[0].lower()
            if hasattr(platform, "linux_distribution")
            else platform.system().lower()
        )
    except Exception as e:
        # Last resort
        return platform.system().lower()


if __name__ == "__main__":
    distro_name = get_distro_name()

    setup_scripts = [file for file in os.listdir(f"setup_scripts/auto_setup/{distro_name}") if file.endswith(".sh")]
    setup_scripts = sorted(setup_scripts)
    for script in setup_scripts:
        print(f"\nRunning {script}...")
        os.system(f"bash setup_scripts/auto_setup/{distro_name}/{script}")
