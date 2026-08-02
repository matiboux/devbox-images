"""
Runs every tests/node/test_*.sh suite (one per src/node/*.sh script) as
a pytest test, so the whole project can be tested -- Python and shell alike
-- with a single `pytest` invocation.

Each .sh file is its own suite (see tests/support/shell/harness.sh) with its
own assertions; a failure here means one of them failed. Re-run the script
directly (`sh tests/node/test_xxx.sh`) to see the per-assertion output.
"""

from pathlib import Path

import pytest

from tests.support.shell_runner import discover_shell_tests, run_shell_test

HERE = Path(__file__).resolve().parent
SHELL_TESTS = discover_shell_tests(HERE)


@pytest.mark.parametrize('script', SHELL_TESTS, ids=lambda p: p.name)
def test_node_shell_script(script):
	result = run_shell_test(script)
	assert result.returncode == 0, (
		f'{script.name} failed:\n--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}'
	)
