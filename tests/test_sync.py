import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "sync.sh"
CHECK_SCRIPT = SCRIPT.parent / "scripts/check-versions.sh"


class SyncTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "templates repo"
        self.packages = self.root / "packages repo"
        self.remote = self.root / "remote.git"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.gh_log = self.root / "gh.log"
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "PACKAGES_REPO": str(self.packages),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "SYNC_TEST_GH_LOG": str(self.gh_log),
            "SYNC_TEST_GH_STATUS": "0",
            "SYNC_TEST_SOURCE": str(self.source),
            "SYNC_TEST_ROOT": str(self.root),
        }
        self.write_executable(
            self.bin / "gh",
            '#!/bin/bash\nprintf "%s\\n" "$*" >> "$SYNC_TEST_GH_LOG"\n'
            'exit "$SYNC_TEST_GH_STATUS"\n',
        )
        for repo in (self.source, self.packages):
            repo.mkdir()
            self.git(repo, "init", "-q", "-b", "main")
            self.git(repo, "config", "user.name", "Sync test")
            self.git(repo, "config", "user.email", "sync@example.com")
            self.git(repo, "config", "commit.gpgsign", "false")
        shutil.copy2(SCRIPT, self.source / "sync.sh")
        (self.source / "scripts").mkdir()
        shutil.copy2(CHECK_SCRIPT, self.source / "scripts/check-versions.sh")
        (self.source / "LICENSE").write_text("Test license\n")
        for template, version in (("thesis", "1.2.3"), ("assignment", "0.4.0")):
            path = self.source / "templates" / template
            (path / "example").mkdir(parents=True)
            (path / ".DS_Store").write_bytes(b"macOS folder metadata")
            (path / "typst.toml").write_text(
                f'[package]\nname = "modern-whs-{template}"\nversion = "{version}"\n'
                'compiler = "0.15.0"\n'
            )
            (path / "example" / "main.typ").write_text(
                f'#import "@preview/modern-whs-{template}:{version}": *\n'
                '#import "@preview/dependency:9.9.9": *\n'
            )
        self.commit(self.source)
        self.published = self.packages / "packages/preview/modern-whs-thesis/1.2.3"
        self.published.mkdir(parents=True)
        (self.published / "original.txt").write_text("Published content\n")
        self.commit(self.packages)
        self.git(self.root, "init", "-q", "--bare", "-b", "main", str(self.remote))
        self.git(self.packages, "remote", "add", "origin", str(self.remote))
        self.git(self.packages, "push", "-q", "-u", "origin", "main")
        self.source_head = self.git(self.source, "rev-parse", "HEAD")
        self.packages_head = self.git(self.packages, "rev-parse", "HEAD")

    def git(self, repo, *args):
        return subprocess.run(
            ["git", "-C", str(repo), *args], env=self.env,
            text=True, capture_output=True, check=True,
        ).stdout.strip()

    def commit(self, repo):
        self.git(repo, "add", ".")
        self.git(repo, "commit", "-qm", "Fixture")

    @staticmethod
    def write_executable(path, content):
        path.write_text(content)
        path.chmod(0o755)

    def sync(self, *args, success=True, stdin="n\n"):
        result = subprocess.run(
            [str(self.source / "sync.sh"), *args], cwd=self.root, env=self.env,
            input=stdin, text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def check_versions(self, success=True):
        result = subprocess.run(
            ["bash", str(self.source / "scripts/check-versions.sh")],
            cwd=self.root, env=self.env, text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def assert_unchanged(self):
        self.assertEqual(self.git(self.source, "rev-parse", "HEAD"), self.source_head)
        self.assertEqual(self.git(self.packages, "rev-parse", "HEAD"), self.packages_head)
        self.assertEqual(self.git(self.packages, "branch", "--show-current"), "main")

    def assert_bump(self, version):
        self.write_executable(
            self.packages / ".git/hooks/pre-commit",
            '#!/bin/bash\n'
            'git --git-dir="$SYNC_TEST_SOURCE/.git" rev-parse HEAD '
            '> "$SYNC_TEST_ROOT/source-head-at-package-commit"\n',
        )
        self.sync("thesis")
        source_head = self.git(self.source, "rev-parse", "HEAD")
        self.assertNotEqual(source_head, self.source_head)
        self.assertEqual(
            (self.root / "source-head-at-package-commit").read_text().strip(), source_head
        )
        self.assertEqual(
            self.git(self.source, "show", "--format=", "--name-only", "HEAD").splitlines(),
            ["templates/thesis/example/main.typ", "templates/thesis/typst.toml"],
        )
        self.assertEqual(
            self.git(self.source, "log", "-1", "--format=%s"),
            f"chore: bump modern-whs-thesis:{version}",
        )
        self.assertEqual(
            self.git(self.packages, "log", "-1", "--format=%s"),
            f"modern-whs-thesis:{version}",
        )
        target = self.packages / "packages/preview/modern-whs-thesis" / version
        for relative in ("typst.toml", "example/main.typ"):
            self.assertEqual(
                (target / relative).read_bytes(),
                (self.source / "templates/thesis" / relative).read_bytes(),
            )
        self.assertIn(f'version = "{version}"', (target / "typst.toml").read_text())
        self.assertIn(f"modern-whs-thesis:{version}", (target / "example/main.typ").read_text())
        self.assertIn("dependency:9.9.9", (target / "example/main.typ").read_text())
        self.assertIn('compiler = "0.15.0"', (target / "typst.toml").read_text())
        self.assertEqual((target / "LICENSE").read_text(), "Test license\n")
        self.assertFalse((target / ".DS_Store").exists())
        self.assertEqual((self.published / "original.txt").read_text(), "Published content\n")
        self.assertEqual(self.git(self.source, "status", "--porcelain"), "")
        self.assertEqual(self.git(self.packages, "status", "--porcelain"), "")

    def test_check_is_local_and_read_only(self):
        output = self.check_versions()
        self.assertIn("thesis: manifest and example use 1.2.3", output)
        self.assertIn("assignment: manifest and example use 0.4.0", output)
        self.assertFalse(self.gh_log.exists())
        self.assert_unchanged()

    def test_check_rejects_mismatch(self):
        example = self.source / "templates/assignment/example/main.typ"
        example.write_text(example.read_text().replace("0.4.0", "0.3.0"))
        self.assertIn("imports 0.3.0", self.check_versions(success=False))
        self.assertFalse(self.gh_log.exists())

    def test_missing_import_is_rejected(self):
        (self.source / "templates/thesis/example/main.typ").write_text("// No import\n")
        self.assertIn("Expected one versioned import", self.check_versions(success=False))
        self.commit(self.source)
        self.assertIn("Expected one versioned import", self.sync("thesis", success=False))
        self.assertFalse(self.gh_log.exists())

    def test_invalid_arguments_are_rejected(self):
        for args in (("--bump", "patch"), ("--check",),
                     ("../thesis",), ("thesis", "assignment"), ("--unknown",)):
            with self.subTest(args=args):
                self.sync(*args, success=False)
        self.assertFalse(self.gh_log.exists())
        self.assert_unchanged()

    def test_sync_always_bumps_patch(self):
        self.assert_bump("1.2.4")

    def test_repeated_sync_bumps_again(self):
        self.assert_bump("1.2.4")
        self.source_head = self.git(self.source, "rev-parse", "HEAD")
        self.assert_bump("1.2.5")

    def test_bump_repairs_stale_example(self):
        example = self.source / "templates/thesis/example/main.typ"
        example.write_text(example.read_text().replace("1.2.3", "1.0.0"))
        self.commit(self.source)
        self.source_head = self.git(self.source, "rev-parse", "HEAD")
        self.assert_bump("1.2.4")

    def test_bump_only_updates_package_version(self):
        manifest = self.source / "templates/thesis/typst.toml"
        manifest.write_text(
            manifest.read_text().replace('version = "1.2.3"', '  version = "1.2.3" # Release')
            + '\n[tool.metadata]\nversion = "9.9.9"\n'
        )
        self.commit(self.source)
        self.source_head = self.git(self.source, "rev-parse", "HEAD")
        self.assert_bump("1.2.4")
        self.assertIn('  version = "1.2.4" # Release', manifest.read_text())
        self.assertIn('[tool.metadata]\nversion = "9.9.9"', manifest.read_text())

    def test_already_published_patch_is_skipped(self):
        target = self.published.parent / "1.2.4"
        target.mkdir()
        (target / "original.txt").write_text("Already released\n")
        self.commit(self.packages)
        self.git(self.packages, "push", "-q")
        self.packages_head = self.git(self.packages, "rev-parse", "HEAD")
        self.assert_bump("1.2.5")
        self.assertEqual((target / "original.txt").read_text(), "Already released\n")

    def test_version_follows_latest_published_release(self):
        for version in ("1.9.9", "1.10.0", "1.3.20"):
            target = self.published.parent / version
            target.mkdir()
            (target / "original.txt").write_text("Already released\n")
        self.commit(self.packages)
        self.git(self.packages, "push", "-q")
        self.assert_bump("1.10.1")

    def test_version_follows_newer_published_major(self):
        target = self.published.parent / "2.0.0"
        target.mkdir()
        (target / "original.txt").write_text("Already released\n")
        self.commit(self.packages)
        self.git(self.packages, "push", "-q")
        self.assert_bump("2.0.1")

    def test_dirty_source_is_rejected_before_network(self):
        (self.source / "uncommitted.txt").write_text("Unrelated work\n")
        self.assertIn("Commit or stash", self.sync("thesis", success=False))
        self.assertFalse(self.gh_log.exists())
        self.assert_unchanged()

    def test_dirty_packages_are_rejected_before_network(self):
        (self.packages / "uncommitted.txt").write_text("Unrelated work\n")
        self.assertIn("Commit or stash", self.sync("thesis", success=False))
        self.assertFalse(self.gh_log.exists())
        self.assert_unchanged()

    def test_upstream_failure_does_not_bump(self):
        self.env["SYNC_TEST_GH_STATUS"] = "1"
        self.sync("thesis", success=False)
        self.assertTrue(self.gh_log.exists())
        self.assert_unchanged()
        self.assertEqual(self.git(self.source, "status", "--porcelain"), "")

    def test_version_includes_releases_fetched_by_pull(self):
        peer = self.root / "upstream checkout"
        self.git(self.root, "clone", "-q", str(self.remote), str(peer))
        self.git(peer, "config", "user.name", "Sync test")
        self.git(peer, "config", "user.email", "sync@example.com")
        target = peer / "packages/preview/modern-whs-thesis/1.2.4"
        target.mkdir()
        (target / "original.txt").write_text("New upstream release\n")
        self.commit(peer)
        self.git(peer, "push", "-q")
        self.assert_bump("1.2.5")
        self.assertEqual(
            (self.published.parent / "1.2.4/original.txt").read_text(), "New upstream release\n"
        )

    def test_source_commit_failure_stops_package_copy(self):
        self.write_executable(self.source / ".git/hooks/pre-commit", "#!/bin/bash\nexit 1\n")
        self.sync("thesis", success=False)
        self.assert_unchanged()
        self.assertFalse((self.published.parent / "1.2.4").exists())

    def test_newer_local_version_is_also_bumped(self):
        for relative in ("typst.toml", "example/main.typ"):
            path = self.source / "templates/thesis" / relative
            path.write_text(path.read_text().replace("1.2.3", "1.3.0"))
        self.commit(self.source)
        self.source_head = self.git(self.source, "rev-parse", "HEAD")
        self.assert_bump("1.3.1")

    def test_interactive_selection_and_optional_push(self):
        self.sync(stdin="1\ny\n")
        self.assertEqual(self.git(self.packages, "branch", "--show-current"), "whs-assignment")
        self.assertIn(
            'version = "0.4.1"',
            (self.source / "templates/assignment/typst.toml").read_text(),
        )
        self.assertEqual(
            self.git(self.remote, "rev-parse", "refs/heads/whs-assignment"),
            self.git(self.packages, "rev-parse", "HEAD"),
        )


if __name__ == "__main__":
    unittest.main()
