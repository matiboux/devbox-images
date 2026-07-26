import subprocess
from pathlib import Path


def discover_shell_tests(directory: Path) -> list[Path]:
    """Return the test_*.sh suites in a directory, sorted for stable output."""
    return sorted(directory.glob('test_*.sh'))


def run_shell_test(path: Path) -> subprocess.CompletedProcess:
    """Run a single shell test suite (its own harness handles assertions)."""
    return subprocess.run(
        ['sh', str(path)],
        capture_output=True,
        text=True,
    )
