import os
import subprocess

# Hardcoded path to the configuration file you want to source
config_file = "../shell_config"
bash_config_file = "../bash_config"
zsh_config_file = "../zsh_config"

# Resolve the configuration file path to an absolute path
config_file = os.path.abspath(config_file)
bash_config_file = os.path.abspath(bash_config_file)
zsh_config_file = os.path.abspath(zsh_config_file)

# Check if the configuration file exists
if not os.path.isfile(config_file):
    print(f"Error: File {config_file} does not exist.")
    exit(1)

# Print the configuration file contents
with open(config_file, "r") as file:
    print(f"Contents of {config_file}:")
    print(file.read())
    print("\n")

# Line to add to shell configuration file
source_line = f"source {config_file}\n"

# Determine the shell and the corresponding config file
shell = os.environ.get("SHELL", "")
if "bash" in shell:
    config_path = os.path.expanduser("~/.bashrc")
    source_command = f"bash -c 'source {config_path}'"
    source_line = f"source {bash_config_file}\n" + source_line
elif "zsh" in shell:
    config_path = os.path.expanduser("~/.zshrc")
    source_command = f"zsh -c 'source {config_path}'"
    source_line = f"source {zsh_config_file}\n" + source_line
else:
    print("Unsupported shell. Only bash and zsh are supported.")
    exit(1)

# Read the existing lines in the config file
with open(config_path, "r") as config_file:
    lines = config_file.readlines()

# Check if the source line is already in the config file
if source_line in lines:
    print(f"The source line is already present in {config_path}.")
else:
    # Add the source line to the config file
    with open(config_path, "r") as config_file:
        existing_content = config_file.read()
    with open(config_path, "w") as config_file:
        config_file.write("# Custom configuration\n")
        config_file.write(source_line)
        config_file.write(existing_content)
    print(f"Added the source line to the start of {config_path}.")

# Source the updated config file
subprocess.run(source_command, shell=True, check=True)
print(f"Sourced the updated {config_path}.")
