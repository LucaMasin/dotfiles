import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DotTests(unittest.TestCase):
    def setUp(self):
        temp_root = "/tmp/opencode" if Path("/tmp/opencode").is_dir() else None
        self.temp = tempfile.TemporaryDirectory(prefix="dot-tests-", dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo with spaces"
        self.home = self.base / "home"
        self.bin = self.base / "bin"
        self.tmp = self.base / "tmp"
        for directory in (self.repo, self.home, self.bin, self.tmp):
            directory.mkdir()
        for name in ("dot", "auto_install.sh", "dotfiles-manifest.conf", "shell_config"):
            shutil.copy2(ROOT / name, self.repo / name)
        for name in ("scripts/dotfiles.sh", "setup_scripts/setup.sh", "setup_scripts/update.sh", "setup_scripts/upgrade.sh"):
            target = self.repo / name
            target.parent.mkdir(exist_ok=True)
            shutil.copy2(ROOT / name, target)
        for line in (self.repo / "dotfiles-manifest.conf").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            for source in line.split("|")[2].split(","):
                target = self.repo / source
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text("fixture\n")
        self.env = dict(os.environ, HOME=str(self.home), TMPDIR=str(self.tmp),
                        XDG_STATE_HOME=str(self.home / ".local/state"),
                        PATH=f"{self.bin}:/usr/bin:/bin")
        for name in ("BASH_ENV", "ENV", "EDITOR"):
            self.env.pop(name, None)
        self.mock("npm", 'if [[ "$*" == "config get prefix" ]]; then printf "/usr\\n"; else printf "%s\\n" "$*" >> "$HOME/.npmrc"; fi')
        self.mock("git", 'printf "%s\\n" "$*" >> "$HOME/git-calls"')
        self.mock("sudo", 'printf "%s\\n" "$*" >> "$HOME/sudo-calls"; exit 97')
        self.mock("omarchy", 'printf "%s\\n" "$*" >> "$HOME/omarchy-calls"; exit 97')
        self.mock("chsh", 'printf "%s\\n" "$*" >> "$HOME/chsh-calls"')
        self.mock("getent", 'printf "testuser:x:1000:1000::/home/testuser:/bin/bash\\n"')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body + "\n")
        path.chmod(0o755)
        return path

    def run_dot(self, *args, success=True, executable=None):
        result = subprocess.run([str(executable or self.repo / "dot"), *args],
                                env=self.env, cwd=self.base, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def snapshot(self, directory):
        result = {}
        for path in sorted(directory.rglob("*")):
            if path.is_symlink():
                result[str(path.relative_to(directory))] = ("link", os.readlink(path))
            elif path.is_file():
                info = path.stat()
                result[str(path.relative_to(directory))] = (path.read_bytes(), info.st_mode, info.st_mtime_ns, info.st_ino)
            else:
                result[str(path.relative_to(directory))] = "directory"
        return result

    def source_block(self):
        return ("# >>> dotfiles managed: zsh\n"
                f'[[ -f "{self.repo}/zsh_config" ]] && source "{self.repo}/zsh_config"\n'
                f'[[ -f "{self.repo}/shell_config" ]] && source "{self.repo}/shell_config"\n'
                "# <<< dotfiles managed: zsh\n")

    def test_help_and_unknown_command(self):
        self.assertIn("Usage: dot <command>", self.run_dot())
        self.assertIn("unknown command: stow", self.run_dot("stow", success=False))

    def test_apply_creates_link_and_no_git_pull(self):
        self.run_dot("apply", "nvim")
        self.assertEqual(os.readlink(self.home / ".config/nvim"), str(self.repo / ".config/nvim"))
        self.assertFalse((self.home / "git-calls").exists())
        before = self.snapshot(self.home)
        self.assertIn("already linked", self.run_dot("apply", "nvim"))
        self.assertEqual(self.snapshot(self.home), before)

    def test_source_block_preserves_content_mode_and_is_idempotent(self):
        rc = self.home / ".zshrc"
        rc.write_text("export CUSTOM=yes\n")
        rc.chmod(0o640)
        self.run_dot("apply", "zsh")
        self.assertEqual(rc.read_text(), "export CUSTOM=yes\n\n" + self.source_block())
        self.assertEqual(rc.stat().st_mode & 0o777, 0o640)
        backups = list((self.home / ".local/state/dotfiles-backup").glob("*/.zshrc"))
        self.assertEqual([p.read_text() for p in backups], ["export CUSTOM=yes\n"])
        before = self.snapshot(self.home)
        self.assertIn("already configured", self.run_dot("apply", "zsh"))
        self.assertEqual(self.snapshot(self.home), before)

    def test_source_block_updates_in_place(self):
        rc = self.home / ".zshrc"
        rc.write_text("before\n# >>> dotfiles managed: zsh\nold\n# <<< dotfiles managed: zsh\nafter\n")
        self.run_dot("apply", "zsh")
        self.assertEqual(rc.read_text(), "before\n" + self.source_block() + "after\n")

    def test_malformed_blocks_are_rejected_before_any_changes(self):
        for content in ("before\n# >>> dotfiles managed: zsh\nkeep me\n",
                        "# <<< dotfiles managed: zsh\nkeep me\n",
                        self.source_block() + self.source_block()):
            with self.subTest(content=content):
                (self.home / ".zshrc").write_text(content)
                before = self.snapshot(self.home)
                self.run_dot("apply", "nvim", "zsh", success=False)
                self.assertEqual(self.snapshot(self.home), before)

    def test_rc_symlink_is_not_replaced(self):
        original = self.home / "personal-rc"
        original.write_text("personal\n")
        (self.home / ".zshrc").symlink_to(original)
        before = self.snapshot(self.home)
        self.assertIn("is a symlink", self.run_dot("apply", "zsh", success=False))
        self.assertEqual(self.snapshot(self.home), before)

    def test_invalid_selection_is_rejected_before_changes(self):
        for args in (("apply", "nvim", "nonexistent"), ("apply", "all", "nvim"),
                     ("apply", "--unknown"), ("apply", "i3"),
                     ("list", "unexpected"), ("list", "--dry-run"),
                     ("update", "--configs", "nvim", "tmux"),
                     ("update", "nvim", "--configs", "tmux"),
                     ("update", "--configs", "nvim", "--configs", "tmux")):
            with self.subTest(args=args):
                before = self.snapshot(self.home)
                self.run_dot(*args, success=False)
                self.assertEqual(self.snapshot(self.home), before)

    def test_disabled_config_requires_explicit_opt_in(self):
        self.run_dot("apply", "i3", "--force-disabled")
        self.assertEqual(os.readlink(self.home / ".config/i3"), str(self.repo / ".config/i3"))

    def test_backups_do_not_collide_when_timestamp_is_identical(self):
        self.mock("date", "printf '20261010-120000\\n'")
        target = self.home / ".config/nvim"
        target.parent.mkdir()
        target.write_text("first\n")
        self.run_dot("apply", "nvim")
        target.unlink()
        target.write_text("second\n")
        self.run_dot("apply", "nvim")
        backups = list((self.home / ".local/state/dotfiles-backup").glob("*/.config/nvim"))
        self.assertEqual(sorted(p.read_text() for p in backups), ["first\n", "second\n"])

    def test_directory_and_broken_symlink_backups_share_one_run(self):
        target = self.home / ".config/nvim"
        target.mkdir(parents=True)
        (target / "personal.lua").write_text("personal settings\n")
        (self.home / ".config/herdr").symlink_to("/missing/personal-herdr")
        self.run_dot("apply", "nvim", "herdr")
        runs = list((self.home / ".local/state/dotfiles-backup").iterdir())
        self.assertEqual(len(runs), 1)
        self.assertEqual((runs[0] / ".config/nvim/personal.lua").read_text(), "personal settings\n")
        self.assertEqual(os.readlink(runs[0] / ".config/herdr"), "/missing/personal-herdr")
        self.assertEqual(os.readlink(target), str(self.repo / ".config/nvim"))

    def test_duplicate_selection_is_applied_once(self):
        output = self.run_dot("apply", "zsh", "zsh")
        self.assertEqual(output.count("Updated "), 1)
        self.assertEqual((self.home / ".zshrc").read_text(), self.source_block())

    def test_apply_and_update_dry_runs_have_no_writes(self):
        before = self.snapshot(self.home)
        for command in ("apply", "update"):
            output = self.run_dot(command, "--dry-run")
            self.assertIn("write managed source block", output)
            self.assertNotIn("Linking wezterm", output)
            self.assertEqual(self.snapshot(self.home), before)
            self.assertEqual(self.snapshot(self.tmp), {})
        self.assertIn("Linking wezterm", self.run_dot("apply", "all", "--dry-run"))

    def test_init_dry_runs_all_platforms_without_writes(self):
        before = self.snapshot(self.home)
        for platform in ("ubuntu", "omarchy", "raspberrypi"):
            with self.subTest(platform=platform):
                output = self.run_dot("init", "--platform", platform, "--dry-run")
                self.assertIn("configure a user-owned npm prefix", output)
                self.assertIn("npm install -g @opencode/cli", output)
                self.assertIn("npm install -g @earendil-works/pi-coding-agent --ignore-scripts", output)
                self.assertIn("npm install -g @anthropic-ai/claude-code", output)
                self.assertIn("Linking nvim", output)
                self.assertIn("dry-run: link", output)
                self.assertEqual(self.snapshot(self.home), before)
                self.assertEqual(self.snapshot(self.tmp), {})

    def test_raspberrypi_init_configures_systemd_resolved_only_there(self):
        for platform in ("ubuntu", "omarchy", "raspberrypi"):
            with self.subTest(platform=platform):
                output = self.run_dot("init", "--platform", platform, "--dry-run")
                if platform == "raspberrypi":
                    self.assertIn("systemd-resolved", output)
                    self.assertIn("enable --now systemd-resolved", output)
                    self.assertIn("ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf", output)
                else:
                    self.assertNotIn("systemd-resolved", output)

    def test_raspberrypi_default_init_previews_obsidian_configs_and_appimage(self):
        output = self.run_dot("init", "--platform", "raspberrypi", "--dry-run")
        for config in ("obsidian-bin", "obsidian-desktop", "obsidian-icon"):
            self.assertIn(f"Linking {config}", output)
        self.assertIn("Obsidian-1.14.4-arm64.AppImage", output)
        self.assertIn("github.com/obsidianmd/obsidian-releases", output)
        narrow = self.run_dot("init", "--platform", "raspberrypi", "--dry-run", "--configs", "zsh")
        self.assertNotIn("Linking obsidian", narrow)
        for platform in ("ubuntu", "omarchy"):
            self.assertNotIn("Linking obsidian", self.run_dot("init", "--platform", platform, "--dry-run"))

    def test_obsidian_appimage_installer_downloads_pinned_arm64_asset(self):
        self.mock("curl", '''
out=""
while (($#)); do
  if [[ $1 == -o ]]; then
    out=$2
    shift 2
    continue
  fi
  shift
done
printf '#!/bin/sh\\necho obsidian\\n' > "$out"
printf '%s\\n' "$out" >> "$HOME/curl-calls"
''')
        script = (f"source '{self.repo}/setup_scripts/setup.sh'\n"
                  "install_obsidian_appimage\n"
                  "install_obsidian_appimage\n")
        result = subprocess.run(["bash", "-c", script], env=self.env, cwd=self.base,
                                text=True, capture_output=True)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        target = self.home / "Applications/Obsidian-1.14.4-arm64.AppImage"
        self.assertTrue(target.is_file())
        self.assertTrue(os.access(target, os.X_OK))
        self.assertTrue(target.read_text().startswith("#!/bin/sh"))
        # The second call is a no-op, so curl only ran once.
        self.assertEqual((self.home / "curl-calls").read_text().splitlines(), [str(target)])
        self.assertEqual(output.count("already installed"), 1)

    def test_obsidian_pinned_version_matches_launcher_wrapper(self):
        setup_lines = (ROOT / "setup_scripts/setup.sh").read_text().splitlines()
        version = [line.split('"')[1] for line in setup_lines if line.startswith('OBSIDIAN_VERSION=')][0]
        self.assertIn(f'Obsidian-{version}-arm64.AppImage', (ROOT / ".local/bin/obsidian").read_text())

    def test_setup_default_configs_mirror_dotfiles_defaults(self):
        dotfiles_line = [line for line in (ROOT / "scripts/dotfiles.sh").read_text().splitlines()
                         if line.startswith("DEFAULT_CONFIGS=")][0]
        setup_line = [line for line in (ROOT / "setup_scripts/setup.sh").read_text().splitlines()
                      if line.startswith("DEFAULT_SETUP_CONFIGS=")][0]
        self.assertEqual(dotfiles_line.split("=", 1)[1], setup_line.split("=", 1)[1])

    def test_omarchy_machine_settings_are_unchanged_by_preview_and_update(self):
        settings = {
            ".config/uwsm/env": "export CUSTOM=yes\n",
            ".config/ghostty/config": "font-size = 14\n",
            ".config/hypr/monitors.lua": "local omarchy_monitor_scale = 2\n",
            ".config/hypr/looknfeel.lua": 'layout = "dwindle"\n',
        }
        for name, content in settings.items():
            target = self.home / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
        self.mock("hyprctl", 'printf "reload\\n" > "$HOME/hypr-reload"')
        before = self.snapshot(self.home)
        self.run_dot("init", "--platform", "omarchy", "--skip-packages", "--dry-run")
        self.assertEqual(self.snapshot(self.home), before)
        self.run_dot("update", "nvim")
        for name, content in settings.items():
            self.assertEqual((self.home / name).read_text(), content)
        self.assertFalse((self.home / "hypr-reload").exists())
        self.assertFalse((self.home / ".config/xdg-terminals.list").exists())

    def test_i3_retains_defaults_and_all_works(self):
        for selection in ((), ("--configs", "all")):
            output = self.run_dot("init", "--platform", "ubuntu", "--desktop", "i3",
                                  "--skip-packages", "--dry-run", *selection)
            self.assertIn("Linking nvim", output)
            self.assertIn("Linking i3", output)
            self.assertEqual(self.snapshot(self.home), {})

    def test_init_preflight_rejects_bad_configs_and_desktop(self):
        for args in (("--configs", "nvim,unknown"), ("--configs", "nvim,"),
                     ("--configs", ""), ("--desktop", "invalid")):
            with self.subTest(args=args):
                self.run_dot("init", "--platform", "ubuntu", *args, success=False)
                self.assertEqual(self.snapshot(self.home), {})
        self.run_dot("init", "--platform", "omarchy", "--desktop", "i3", success=False)
        self.assertEqual(self.snapshot(self.home), {})

    def test_update_pulls_then_applies_without_desktop_changes(self):
        self.run_dot("update", "--configs", "nvim")
        self.assertEqual((self.home / "git-calls").read_text(), f"-C {self.repo} pull --ff-only\n")
        self.assertEqual(os.readlink(self.home / ".config/nvim"), str(self.repo / ".config/nvim"))
        self.assertFalse((self.home / ".config/xdg-terminals.list").exists())

    def test_failed_pull_does_not_apply_configs(self):
        self.mock("git", "printf 'diverged\\n' >&2; exit 1")
        self.assertIn("diverged", self.run_dot("update", "nvim", success=False))
        self.assertEqual(self.snapshot(self.home), {})

    def test_legacy_update_delegates_and_skip_pull_works(self):
        self.run_dot("nvim", "--skip-pull", executable=self.repo / "setup_scripts/update.sh")
        self.assertEqual(os.readlink(self.home / ".config/nvim"), str(self.repo / ".config/nvim"))
        self.assertFalse((self.home / "git-calls").exists())

    def test_upgrade_defaults_skip_neovim_and_missing_tools(self):
        for name in ("bash", "dirname", "readlink"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env["PATH"] = str(self.bin)
        output = self.run_dot("upgrade", "--dry-run")
        self.assertIn("opencode: not installed, skipping", output)
        self.assertNotIn("Neovim", output)
        output = self.run_dot("upgrade", "--dry-run", "--with", "neovim")
        self.assertIn("neovim: not installed, skipping", output)
        self.assertIn("unknown tool", self.run_dot("upgrade", "bogus", success=False))

    def test_upgrade_user_installed_tool_only(self):
        local = self.home / ".local/bin"
        local.mkdir(parents=True)
        for name in ("opencode", "nvim"):
            (local / name).write_text("#!/usr/bin/env bash\n")
            (local / name).chmod(0o755)
        self.env["PATH"] = f"{local}:{self.env['PATH']}"
        output = self.run_dot("upgrade", "--dry-run")
        self.assertIn("npm install -g @opencode/cli@latest --allow-scripts=@opencode/cli", output)
        self.assertNotIn("Neovim", output)
        self.assertIn("Building the latest stable Neovim", self.run_dot("upgrade", "--dry-run", "neovim"))
        self.assertFalse((self.home / "sudo-calls").exists())

    def test_browser_control_upgrade_finds_pnpm_in_custom_npm_prefix(self):
        for name in ("bash", "dirname", "readlink", "mkdir"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env["PATH"] = str(self.bin)
        (self.home / "repos/browser-control/.git").mkdir(parents=True)
        tools = self.home / "tools"
        tools.mkdir()
        shutil.move(self.mock("browser-control", "exit 0"), tools / "browser-control")
        self.env["PATH"] = f"{tools}:{self.env['PATH']}"
        self.mock("bun", "exit 0")
        self.mock("npm", '''
if [[ "$*" == "config get prefix" ]]; then
  printf '%s/.local\\n' "$HOME"
elif [[ "$*" == "install -g pnpm" ]]; then
  mkdir -p "$HOME/.local/bin"
  printf '#!/usr/bin/env bash\\nprintf "pnpm %%s\\\\n" "$*" >> "$HOME/build-calls"\\n' > "$HOME/.local/bin/pnpm"
  chmod +x "$HOME/.local/bin/pnpm"
else
  exit 1
fi''')
        (self.bin / "chmod").symlink_to(shutil.which("chmod"))
        self.run_dot("upgrade", "browser-control")
        self.assertEqual((self.home / "build-calls").read_text().splitlines(), [
            "pnpm install", "pnpm build",
        ])

    def test_link_symlink_resolution_and_unlink(self):
        self.run_dot("link")
        link = self.home / ".local/bin/dot"
        self.assertEqual(os.readlink(link), str(self.repo / "dot"))
        self.run_dot("apply", "nvim", executable=link)
        self.assertEqual(os.readlink(self.home / ".config/nvim"), str(self.repo / ".config/nvim"))
        self.run_dot("unlink", "--dry-run")
        self.assertTrue(link.is_symlink())
        self.run_dot("unlink")
        self.assertFalse(link.is_symlink())
        self.assertTrue((self.home / ".config/nvim").is_symlink())

    def test_foreign_command_is_never_overwritten(self):
        link = self.home / ".local/bin/dot"
        link.parent.mkdir(parents=True)
        link.write_text("foreign command\n")
        before = self.snapshot(self.home)
        for args in (("link",), ("unlink",), ("init", "--platform", "ubuntu")):
            self.run_dot(*args, success=False)
            self.assertEqual(self.snapshot(self.home), before)

    def test_doctor_reports_healthy_and_broken_configuration(self):
        tpm = self.home / ".config/tmux/plugins/tpm/bin/install_plugins"
        tpm.parent.mkdir(parents=True)
        tpm.write_text("#!/bin/bash\nexit 0\n")
        tpm.chmod(0o755)
        for tool in ("zsh", "nvim", "tmux", "herdr", "node", "gh", "fzf", "rg", "btop",
                     "zoxide", "starship", "yazi", "tokei", "uv", "opencode", "pi", "claude", "tailscale", "browser-control"):
            self.mock(tool, "exit 0")
        self.run_dot("apply")
        self.run_dot("link")
        self.env["PATH"] = f"{self.home}/.local/bin:{self.env['PATH']}"
        before = self.snapshot(self.home)
        self.assertIn("ok: dot resolves to this repo", self.run_dot("doctor"))
        self.assertEqual(self.snapshot(self.home), before)
        (self.home / ".config/nvim").unlink()
        self.assertIn("Repair: dot apply nvim", self.run_dot("doctor", success=False))

    def test_edit_passes_editor_arguments_and_repo_path(self):
        self.mock("editor", 'printf "%s\\n" "$@" > "$HOME/editor-args"')
        self.env["EDITOR"] = "editor --wait"
        self.run_dot("edit")
        self.assertEqual((self.home / "editor-args").read_text(), f"--wait\n{self.repo}\n")

    def test_bash_completion_returns_config_names(self):
        self.run_dot("link")
        self.env["PATH"] = f"{self.home}/.local/bin:{self.env['PATH']}"
        script = ('source <(dot completions bash)\n'
                  'COMP_WORDS=(dot apply nv); COMP_CWORD=2\n'
                  '_dot_complete\nprintf "%s\\n" "${COMPREPLY[@]}"\n')
        result = subprocess.run(["bash", "-c", script], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "nvim\n")

    def test_bootstrap_dry_run_and_invalid_flags(self):
        output = self.run_dot("--platform", "ubuntu", "--configs", "nvim", "--dry-run",
                              executable=self.repo / "auto_install.sh")
        self.assertIn("--configs nvim --dry-run", output)
        self.assertEqual(self.snapshot(self.home), {})
        self.run_dot("--unknown", executable=self.repo / "auto_install.sh", success=False)
        self.assertEqual(self.snapshot(self.home), {})

    @unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
    def test_zsh_completion_returns_config_names(self):
        self.run_dot("link")
        self.env["PATH"] = f"{self.home}/.local/bin:{self.env['PATH']}"
        script = ('autoload -Uz compinit; compinit -D\n'
                  'eval "$(dot completions zsh)"\n'
                  'compadd() { printf "%s\\n" "$@"; }\n'
                  'words=(dot apply nv); CURRENT=3\n'
                  '_dot_complete\n')
        result = subprocess.run(["zsh", "-f", "-c", script], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nvim", result.stdout.splitlines())

    def test_init_config_only_installs_global_command(self):
        self.run_dot("init", "--platform", "ubuntu", "--configs", "nvim", "--skip-packages")
        self.assertEqual(os.readlink(self.home / ".local/bin/dot"), str(self.repo / "dot"))
        self.assertEqual(os.readlink(self.home / ".config/nvim"), str(self.repo / ".config/nvim"))
        self.assertFalse((self.home / "sudo-calls").exists())

    def test_source_block_temp_is_removed_after_failed_write(self):
        self.mock("mv", "exit 1")
        self.run_dot("apply", "zsh", success=False)
        self.assertEqual(self.snapshot(self.home), {})

    def test_setup_dry_run_does_not_invoke_npm(self):
        self.mock("npm", 'printf "invoked\\n" > "$HOME/npm-query"; printf "/usr\\n"')
        self.run_dot("init", "--platform", "ubuntu", "--dry-run")
        self.assertEqual(self.snapshot(self.home), {})

    def test_ai_tools_install_on_all_platforms_with_user_owned_prefix(self):
        for tool in ("starship", "zoxide", "uv", "yazi", "cargo", "tokei", "poetry",
                     "browser-control", "herdr", "make", "cmake", "curl", "wget", "gpg"):
            self.mock(tool, "exit 0")
        self.mock("curl", '''
out=""
while (($#)); do
  if [[ $1 == -o ]]; then
    out=$2
    shift 2
    continue
  fi
  shift
done
printf '#!/bin/sh\\n' > "$out" 2>/dev/null || true
exit 0
''')
        self.mock("sudo", 'if [[ "$1" == tee ]]; then cat >/dev/null; fi')
        self.mock("omarchy", "exit 0")
        self.mock("git", 'if [[ "$1" == ls-remote ]]; then printf "abc\\trefs/tags/v0.11.0\\n"; fi')
        self.mock("npm", '''
if [[ "$*" == "config get prefix" ]]; then
  if [[ -f "$HOME/npm-prefix" ]]; then cat "$HOME/npm-prefix"; else printf "/usr\\n"; fi
else
  printf "%s\\n" "$*" >> "$HOME/npm-calls"
  if [[ "$1" == config && "$2" == set ]]; then printf "%s\\n" "$4" > "$HOME/npm-prefix"; fi
fi''')
        for platform in ("ubuntu", "omarchy", "raspberrypi"):
            with self.subTest(platform=platform):
                for name in ("npm-calls", "npm-prefix"):
                    (self.home / name).unlink(missing_ok=True)
                self.run_dot("init", "--platform", platform, "--configs", "nvim")
                self.assertEqual((self.home / "npm-calls").read_text().splitlines(), [
                    f"config set prefix {self.home}/.npm-global",
                    "install -g @opencode/cli --allow-scripts=@opencode/cli",
                    "install -g @earendil-works/pi-coding-agent --ignore-scripts",
                    "install -g @anthropic-ai/claude-code --allow-scripts=@anthropic-ai/claude-code",
                ])

    def test_existing_ai_tools_are_not_reinstalled(self):
        for tool in ("opencode", "pi", "claude"):
            self.mock(tool, "exit 0")
        output = self.run_dot("init", "--platform", "ubuntu", "--dry-run")
        for tool in ("opencode", "pi", "claude"):
            self.assertIn(f"{tool} already installed", output)
        self.assertNotIn("npm install -g", output)

    def test_skip_packages_skips_ai_tool_installation(self):
        output = self.run_dot("init", "--platform", "ubuntu", "--skip-packages", "--dry-run")
        self.assertNotIn("npm install", output)
        self.assertFalse((self.home / ".npmrc").exists())

    def test_opencode_config_ships_claude_plugin(self):
        config = json.loads((ROOT / ".config/opencode/opencode.jsonc").read_text())
        self.assertEqual(config["plugins"], ["@openchamber/opencode-claude@1.4.1"])
        target = self.repo / ".config/opencode/opencode.jsonc"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / ".config/opencode/opencode.jsonc", target)
        self.run_dot("apply", "opencode")
        installed = self.home / ".config/opencode/opencode.jsonc"
        self.assertEqual(json.loads(installed.read_text())["plugins"],
                         ["@openchamber/opencode-claude@1.4.1"])


if __name__ == "__main__":
    unittest.main()
