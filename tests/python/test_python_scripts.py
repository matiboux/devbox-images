"""
Runs every tests/python/test_*.sh suite (one per src/python/*.sh script)
as a pytest test, so the whole project's tests -- Python and shell alike --
can be run with a single `pytest` invocation.

Each .sh file is its own self-contained suite (see
tests/support/shell/harness.sh) with many assertions inside; a failure here
means at least one assertion in that suite failed. Re-run the script
directly (`sh tests/python/test_xxx.sh`) for the detailed per-assertion
FAIL/SKIP output.
"""

from pathlib import Path

import pytest

from tests.support.shell_runner import discover_shell_tests, run_shell_test

HERE = Path(__file__).resolve().parent
SHELL_TESTS = discover_shell_tests(HERE)


@pytest.mark.parametrize("script", SHELL_TESTS, ids=lambda p: p.name)
def test_python_shell_script(script):
    result = run_shell_test(script)
    assert result.returncode == 0, (
        f"{script.name} failed:\n"
        f"--- stdout ---\n{result.stdout}\n"
        f"--- stderr ---\n{result.stderr}"
    )
