#!/bin/sh
# Tests for src/common/install-uv.sh
# curl and pip are stubbed (tests/shell/stubs/) so no real network/PyPI
# access happens, and the "downloaded" installer is a script we control.

. "$(dirname "$0")/../support/shell/harness.sh"

SCRIPT="${COMMON_DIR}/install-uv.sh"

setup_stub_bin
use_stub curl
use_stub pip

CURL_LOG="${STUB_BIN_DIR}/curl-calls.log"

UV_HOME_DIR="$(mktemp -d)"
UV_BIN_DIR="$(mktemp -d)"

test_case 'a fully-qualified X.Y.Z version skips PyPI lookup entirely'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.8.13/install.sh'
rm -rf "${UV_HOME_DIR}"; UV_HOME_DIR="$(mktemp -d)"

test_case "'latest' (default) resolves via 'pip index versions' and picks the first entry"
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" PIP_STUB_VERSIONS='0.9.2, 0.9.1, 0.8.0' UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.9.2/install.sh'
rm -rf "${UV_HOME_DIR}"; UV_HOME_DIR="$(mktemp -d)"

test_case 'a partial version (X.Y) resolves to the newest matching patch release'
: > "${CURL_LOG}"
output=$(CURL_STUB_LOG="${CURL_LOG}" PIP_STUB_VERSIONS='0.9.0, 0.8.5, 0.8.1' UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_contains "$(cat "${CURL_LOG}")" 'astral.sh/uv/0.8.5/install.sh'
rm -rf "${UV_HOME_DIR}"; UV_HOME_DIR="$(mktemp -d)"

test_case 'no matching version available errors out clearly'
output=$(PIP_STUB_VERSIONS='0.9.0, 0.8.5' UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.5' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" "Failed to find a valid uv version for '0.5'"

test_case 'a curl failure while downloading the installer errors out'
output=$(CURL_STUB_EXIT_CODE=1 UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 1
assert_contains "${output}" 'Failed to install uv version 0.8.13'

test_case 'a failing installer script propagates its exit code and prints an error'
output=$(CURL_STUB_INSTALLER='#!/bin/sh
exit 7' UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 7
assert_contains "${output}" 'Failed to install uv.'

test_case 'the installer is invoked with UV_NO_MODIFY_PATH and UV_UNMANAGED_INSTALL exported to UV_HOME'
output=$(CURL_STUB_INSTALLER='#!/bin/sh
echo "modify=${UV_NO_MODIFY_PATH} install=${UV_UNMANAGED_INSTALL}"' UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8.13' 2>&1)
assert_contains "${output}" "modify=1 install=${UV_HOME_DIR}"

test_case 'installed uv/uvx binaries get a symlink in UV_BIN_DIR and UV_HOME is world-accessible'
rm -rf "${UV_HOME_DIR}" "${UV_BIN_DIR}"
UV_HOME_DIR="$(mktemp -d)"; UV_BIN_DIR="$(mktemp -d)"
printf '#!/bin/sh\ntouch "%s/uv"; touch "%s/uvx"; chmod +x "%s/uv" "%s/uvx"\n' \
	"${UV_HOME_DIR}" "${UV_HOME_DIR}" "${UV_HOME_DIR}" "${UV_HOME_DIR}" > "${STUB_BIN_DIR}/fake-installer.sh"
output=$(CURL_STUB_INSTALLER="$(cat "${STUB_BIN_DIR}/fake-installer.sh")" UV_HOME="${UV_HOME_DIR}" UV_BIN_DIR="${UV_BIN_DIR}" sh "${SCRIPT}" '0.8.13' 2>&1)
code=$?
assert_exit_code "${code}" 0 "${output}"
assert_equal "$(readlink "${UV_BIN_DIR}/uv")" "${UV_HOME_DIR}/uv"
assert_equal "$(readlink "${UV_BIN_DIR}/uvx")" "${UV_HOME_DIR}/uvx"
perms="$(stat -c '%a' "${UV_HOME_DIR}")"
assert_equal "${perms}" '777'
rm -rf "${UV_HOME_DIR}" "${UV_BIN_DIR}"
UV_HOME_DIR="$(mktemp -d)"; UV_BIN_DIR="$(mktemp -d)"

test_case 'defaults UV_HOME to /opt/uv when unset'
skip_case 'mkdir/chmod are not stubbed; exercising the real default would write to /opt/uv on this host'

rm -rf "${UV_HOME_DIR}" "${UV_BIN_DIR}"

summary
