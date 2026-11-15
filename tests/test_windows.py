from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
WINDOWS = ROOT / "windows"
SKILLS = ROOT / ".agents" / "skills"


class WindowsDeploymentTests(unittest.TestCase):
    def test_tools_file_is_app_and_command_pairs(self):
        entries = [line for line in (WINDOWS / "tools.txt").read_text().splitlines()
                   if line.strip() and not line.startswith("#")]
        self.assertTrue(entries)
        for line in entries:
            self.assertRegex(line, r"^[a-z0-9._-]+\|[A-Za-z0-9._-]+$")
        self.assertIn("go|go", entries)

    def test_setup_script_reads_files_that_exist(self):
        script = (WINDOWS / "setup.ps1").read_text()
        for name in re.findall(r"\$PSScriptRoot '([^']+)'", script):
            if name != "..":
                self.assertTrue((WINDOWS / name).is_file(), name)

    def test_setup_script_is_ascii_for_windows_powershell(self):
        (WINDOWS / "setup.ps1").read_text().encode("ascii")

    def test_heimdall_script_is_ascii_for_windows_powershell(self):
        (WINDOWS / "heimdall.ps1").read_text().encode("ascii")

    def test_default_exclusions_name_real_skills(self):
        script = (WINDOWS / "setup.ps1").read_text()
        match = re.search(r"\$ExcludeSkills = @\(([^)]*)\)", script)
        self.assertIsNotNone(match)
        for name in re.findall(r"'([^']+)'", match.group(1)):
            self.assertTrue((SKILLS / name).exists() or (SKILLS / name).is_symlink(), name)

    def test_gitattributes_keeps_scripts_lf_and_cmd_crlf(self):
        attributes = (ROOT / ".gitattributes").read_text()
        self.assertIn("* text=auto eol=lf", attributes)
        self.assertIn("*.cmd text eol=crlf", attributes)

    def test_agent_notes_cover_script_launchers(self):
        notes = (WINDOWS / "agent-notes.md").read_text()
        for needle in ("statechart.ts", "watch-pr", "check-plan.mjs", "impeccable.cmd", "uv run python", "Git Bash"):
            self.assertIn(needle, notes)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_windows_command_registration_and_dispatch(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "repo with spaces"
            home = Path(temp) / "home"
            shutil.copytree(WINDOWS, root / "windows")
            (root / ".agents" / "skills" / "example").mkdir(parents=True)
            (root / ".agents" / "skills" / "example" / "SKILL.md").write_text("example")
            (root / ".config" / "opencode" / "commands").mkdir(parents=True)
            (root / ".config" / "starship.toml").write_text("[conda]\nignore_base = true\n")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            setup = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                     str(root / "windows" / "setup.ps1"), "-SkipTools", "-HomeDir", str(home)]
            subprocess.run(setup + ["-DryRun"], check=True, capture_output=True, text=True)
            self.assertFalse(home.exists())
            subprocess.run(setup, check=True, capture_output=True, text=True)
            shim = home / ".local" / "bin" / "dot.cmd"
            self.assertTrue(shim.exists())
            profile = home / "Documents" / "WindowsPowerShell" / "profile.ps1"
            self.assertIn("starship init powershell", profile.read_text())
            config = home / ".config" / "starship.toml"
            self.assertIn("ignore_base", config.read_text())
            self.assertTrue((home / "Documents" / "PowerShell" / "profile.ps1").exists())
            config.write_text("# personal config\n")
            help_result = subprocess.run([str(shim), "help"], capture_output=True, text=True)
            self.assertEqual(help_result.returncode, 0, help_result.stderr)
            self.assertIn("Windows commands", help_result.stdout)
            bad = subprocess.run([str(shim), "apply"], capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("not supported", bad.stderr)
            original = shim.read_bytes()
            subprocess.run(setup, check=True, capture_output=True, text=True)
            self.assertEqual(shim.read_bytes(), original)
            self.assertEqual(profile.read_text().count("starship init powershell"), 1)
            self.assertEqual(config.read_text(), "# personal config\n")

            shim.write_text("@echo foreign\n")
            result = subprocess.run(setup, check=True, capture_output=True, text=True)
            self.assertIn("not managed", result.stdout)
            self.assertEqual(shim.read_text(), "@echo foreign\n")

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_windows_command_rejects_unknown_option(self):
        result = subprocess.run(["powershell.exe", "-NoProfile", "-File", str(WINDOWS / "dot.ps1"),
                                 "init", "--invalid"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown option", result.stderr)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_windows_command_dry_run_dispatch(self):
        result = subprocess.run(["powershell.exe", "-NoProfile", "-File", str(WINDOWS / "dot.ps1"),
                                 "update", "--dry-run", "--skip-tools"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pull --ff-only", result.stdout)
        self.assertIn("skip: tools", result.stdout)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_upgrade_only_updates_listed_scoop_apps(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            mock = temp / "scoop.ps1"
            log = temp / "calls.txt"
            mock.write_text(
                "param($action, $app)\n"
                "Add-Content -LiteralPath $env:DOT_TEST_LOG -Value \"$action $app\"\n"
                "if ($action -eq 'prefix' -and $app -ne 'git') { $global:LASTEXITCODE = 1; return }\n"
                "$global:LASTEXITCODE = 0\n"
            )
            env = os.environ.copy()
            env["PATH"] = str(temp) + os.pathsep + env["PATH"]
            env["DOT_TEST_LOG"] = str(log)
            env["USERPROFILE"] = str(temp / "home")
            command = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       str(WINDOWS / "dot.ps1"), "upgrade"]
            preview = subprocess.run(command + ["--dry-run"], env=env, capture_output=True, text=True)
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertIn("dry-run: scoop update git", preview.stdout)
            self.assertNotIn("update git", log.read_text())
            log.unlink()
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            updates = [line for line in log.read_text().splitlines() if line.startswith("update ")]
            self.assertEqual(updates, ["update git"])
            self.assertIn("skip: heimdall is not installed", result.stdout)

    def heimdall_env(self, temp):
        bin_dir = temp / "bin"
        bin_dir.mkdir()
        for name in ("gh", "go"):
            (bin_dir / f"{name}.cmd").write_text("@exit /b 0\r\n")
        env = os.environ.copy()
        env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
        return env

    def run_heimdall(self, env, *args):
        return subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                               str(WINDOWS / "heimdall.ps1"), *args], env=env, capture_output=True, text=True)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_heimdall_dry_run_previews_clone_and_writes_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            home = temp / "home"
            result = self.run_heimdall(self.heimdall_env(temp), "-DryRun", "-HomeDir", str(home))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("gh repo clone LucaMasin/heimdall", result.stdout)
            self.assertFalse(home.exists())

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_heimdall_forwards_flags_to_the_repo_installer(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            home = temp / "home"
            checkout = home / "repos" / "heimdall"
            (checkout / ".git").mkdir(parents=True)
            (checkout / "scripts").mkdir()
            (checkout / "scripts" / "install-windows.ps1").write_text(
                "param([switch]$DryRun, [switch]$IfChanged)\n"
                "Write-Host \"installer dry=$DryRun changed=$IfChanged\"\n")
            result = self.run_heimdall(self.heimdall_env(temp), "-DryRun", "-IfChanged", "-HomeDir", str(home))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pull --ff-only", result.stdout)
            self.assertIn("installer dry=True changed=True", result.stdout)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_heimdall_refuses_to_install_a_service_for_another_home(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            result = self.run_heimdall(self.heimdall_env(temp), "-HomeDir", str(temp / "home"))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("only runs against the real home", result.stderr + result.stdout)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_dot_heimdall_controls_the_service_through_the_repo_script(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            env = os.environ.copy()
            env["USERPROFILE"] = str(temp)
            command = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       str(WINDOWS / "dot.ps1"), "heimdall"]
            missing = subprocess.run(command + ["start"], env=env, capture_output=True, text=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("not installed", missing.stderr)
            bad = subprocess.run(command + ["explode"], env=env, capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("usage: dot heimdall", bad.stderr)
            scripts = temp / "repos" / "heimdall" / "scripts"
            scripts.mkdir(parents=True)
            (scripts / "heimdall-service.ps1").write_text("param($Action)\nWrite-Host \"action=$Action\"\n")
            ok = subprocess.run(command + ["stop"], env=env, capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stderr)
            self.assertIn("action=stop", ok.stdout)
            default = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertIn("action=status", default.stdout)

    @unittest.skipUnless(os.name == "nt", "requires Windows PowerShell")
    def test_heimdall_flag_is_rejected_by_upgrade(self):
        result = subprocess.run(["powershell.exe", "-NoProfile", "-File", str(WINDOWS / "dot.ps1"),
                                 "upgrade", "--heimdall"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not valid for upgrade", result.stderr)


if __name__ == "__main__":
    unittest.main()
