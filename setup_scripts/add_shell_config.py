import os
from os.path import expanduser, expandvars
import subprocess
import shutil

# Hardcoded path to the configuration file you want to source
config_file = "../shell_config"
bash_config_file = "../bash_config"
zsh_config_file = "../zsh_config"

# Resolve the configuration file path to an absolute path
config_file = os.path.abspath(config_file)
bash_config_file = os.path.abspath(bash_config_file)
zsh_config_file = os.path.abspath(zsh_config_file)
# Add sources to the shell configuration files
bash_config = f"""
# Custom configuration
source {bash_config_file}
source {config_file}

"""
zsh_config = f"""
# Custom configuration
source {zsh_config_file}
source {config_file}

"""

if not os.path.exists(bash_config_file):
    # create empty file
    with open(bash_config_file, "w") as f:
        f.write("")
if not os.path.exists(zsh_config_file):
    # create empty file
    with open(zsh_config_file, "w") as f:
        f.write("")

# Update ~/.bashrc
bashrc_path = os.path.expanduser("~/.bashrc")
with open(bashrc_path, "r") as f:
    content = f.read()

if bash_config not in content:
    with open(bashrc_path, "a") as f:
        f.write(bash_config)

# Update ~/.zshrc
zshrc_path = os.path.expanduser("~/.zshrc")
with open(zshrc_path, "r") as f:
    content = f.read()

if zsh_config not in content:
    with open(zshrc_path, "a") as f:
        f.write(zsh_config)

# Source the configuration file in the current shell
subprocess.run("bash -c 'source ~/.bashrc'", shell=True, check=True)
subprocess.run("zsh -c 'source ~/.zshrc'", shell=True, check=True)
