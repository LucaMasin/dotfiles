from pathlib import Path
import re
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

    def test_setup_script_reads_files_that_exist(self):
        script = (WINDOWS / "setup.ps1").read_text()
        for name in re.findall(r"\$PSScriptRoot '([^']+)'", script):
            if name != "..":
                self.assertTrue((WINDOWS / name).is_file(), name)

    def test_setup_script_is_ascii_for_windows_powershell(self):
        (WINDOWS / "setup.ps1").read_text().encode("ascii")

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


if __name__ == "__main__":
    unittest.main()
