#!/bin/sh
set -e

CURRENT_DIR="${0%/*}"
[ "${CURRENT_DIR}" = "$0" ] && CURRENT_DIR='.'
COMMON_LIB_DIR="$(CDPATH= cd -- "${CURRENT_DIR}/lib" && pwd)"
. "${COMMON_LIB_DIR}/distro.sh"
. "${COMMON_LIB_DIR}/group.sh"

USERNAME="$1"
USER_ID="$2"
GROUP_ID="$3"
SUDO_USER="$4"

if [ -z "${USERNAME}" ]; then
	USERNAME='user'
fi

if [ -z "${USER_ID}" ]; then
	USER_ID='1000'
fi

if [ -z "${GROUP_ID}" ]; then
	GROUP_ID='1000'
fi

if [ -z "${SUDO_USER}" ]; then
	SUDO_USER='false'
fi

# Create or reuse group
GROUP_READY='false'
EXISTING_GROUP="$(getent group "${GROUP_ID}" | cut -d: -f1)"
if [ -n "${EXISTING_GROUP}" ]; then
	if [ "${EXISTING_GROUP}" = "${USERNAME}" ]; then
		GROUP_READY='true'
	elif command -v groupmod > /dev/null 2>&1; then
		groupmod -n "${USERNAME}" "${EXISTING_GROUP}"
		GROUP_READY='true'
	elif command -v groupdel > /dev/null 2>&1; then
		groupdel "${EXISTING_GROUP}"
	elif command -v delgroup > /dev/null 2>&1; then
		delgroup "${EXISTING_GROUP}"
	fi
fi
if [ "${GROUP_READY}" = 'false' ]; then
	if command -v groupadd > /dev/null 2>&1; then
		groupadd -g "${GROUP_ID}" "${USERNAME}"
	elif command -v addgroup > /dev/null 2>&1; then
		addgroup -g "${GROUP_ID}" "${USERNAME}"
	else
		echo "No suitable command found to create group" >&2
		exit 1
	fi
fi

USER_SHELL="$(command -v bash || command -v sh)"

# Create or reuse user
USER_READY='false'
EXISTING_USER="$(getent passwd "${USER_ID}" | cut -d: -f1)"
if [ -n "${EXISTING_USER}" ]; then
	if [ "${EXISTING_USER}" = "${USERNAME}" ]; then
		USER_READY='true'
	elif command -v usermod > /dev/null 2>&1; then
		usermod -l "${USERNAME}" -g "${GROUP_ID}" -d "/home/${USERNAME}" -m -s "${USER_SHELL}" "${EXISTING_USER}"
		USER_READY='true'
	elif command -v userdel > /dev/null 2>&1; then
		userdel "${EXISTING_USER}"
	elif command -v deluser > /dev/null 2>&1; then
		deluser "${EXISTING_USER}"
	fi
fi

if [ "${USER_READY}" = 'false' ]; then
	if command -v useradd > /dev/null 2>&1; then
		useradd -lm -u "${USER_ID}" -g "${GROUP_ID}" -s "${USER_SHELL}" "${USERNAME}"
	elif command -v adduser > /dev/null 2>&1; then
		adduser -D -u "${USER_ID}" -G "${USERNAME}" -s "${USER_SHELL}" "${USERNAME}"
	else
		echo "No suitable command found to create user" >&2
		exit 1
	fi
fi

# Add user to Docker group if it exists
add_user_to_group "${USERNAME}" docker

# Add user to sudoers
if [ "${SUDO_USER}" = 'true' ]; then

	# Detect Linux distribution
	DISTRO="$(detect_distro)"

	# Detect sudo command based on distribution
	SUDO_COMMAND=''
	case "${DISTRO}" in
		alpine)
			SUDO_COMMAND="$(command -v doas || command -v sudo)"
			;;
		debian|ubuntu)
			SUDO_COMMAND="$(command -v sudo || command -v doas)"
			;;
	esac

	if [ -z "${SUDO_COMMAND}" ]; then
		echo "Unsupported distribution: ${DISTRO}" >&2
		exit 1
	fi

	SUDO_COMMAND_NAME="$(basename "${SUDO_COMMAND}")"

	if [ "${SUDO_COMMAND_NAME}" = 'sudo' ]; then

		add_user_to_group "${USERNAME}" sudo 1 || exit 1

	elif [ "${SUDO_COMMAND_NAME}" = 'doas' ]; then

		add_user_to_group "${USERNAME}" wheel 1 || exit 1

	else

		echo "Unsupported sudo command: ${SUDO_COMMAND_NAME}" >&2
		exit 1

	fi

fi
