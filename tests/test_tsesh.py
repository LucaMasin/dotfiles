import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tsesh", ROOT / "scripts" / "tsesh.py")
tsesh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tsesh)


class SessionFolderTests(unittest.TestCase):
    def test_rust_and_go_projects_are_discovered(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            projects = [home / "rust" / "rust-project", home / "go" / "go-project"]
            for project in projects:
                project.mkdir(parents=True)
            with patch.dict(os.environ, {"HOME": temp}), patch.object(
                tsesh, "CONFIG_PATH", str(ROOT / "scripts" / ".tsesh.folders")
            ):
                folders = tsesh.get_folders()
                discovered = tsesh.get_subfolders(folders)
            for project in projects:
                self.assertIn(str(project), discovered)


if __name__ == "__main__":
    unittest.main()
