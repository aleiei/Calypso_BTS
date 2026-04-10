#!/bin/sh
set -e

STATE_DIR="/var/lib/calypsobts-install"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APPLY=0
PURGE_DEPS=0
FAILED=0

show_help() {
	cat <<'EOF'
Usage: ./uninstall.sh [--apply] [--purge-deps]

Default behavior:
  - Dry-run only (prints planned actions).

Options:
  --apply       Execute uninstall actions.
  --purge-deps  Also purge base dependency packages installed by install.sh.
  -h, --help    Show this help.

Examples:
  ./uninstall.sh
  ./uninstall.sh --apply
  ./uninstall.sh --apply --purge-deps
EOF
}

log_warn() {
	echo "[WARN] $*"
}

apt_retry() {
	attempt=1
	while [ "$attempt" -le 3 ]; do
		if sudo apt -o DPkg::Lock::Timeout=120 "$@"; then
			return 0
		fi
		echo "[WARN] apt command failed (attempt $attempt/3): apt $*"
		sudo dpkg --configure -a || true
		sudo apt install -f -y || true
		attempt=$((attempt + 1))
	done
	return 1
}

run_cmd() {
	if [ "$APPLY" -eq 1 ]; then
		echo "+ $*"
		if ! "$@"; then
			echo "[WARN] command failed: $*"
			FAILED=1
		fi
	else
		echo "[dry-run] $*"
	fi
}

for arg in "$@"; do
	case "$arg" in
		--apply) APPLY=1 ;;
		--purge-deps) PURGE_DEPS=1 ;;
		-h|--help)
			show_help
			exit 0
			;;
		*)
			echo "Unknown option: $arg" >&2
			show_help >&2
			exit 1
			;;
	esac
done

printf '\033[30;41m\nCalypsoBTS uninstall/cleanup\n\033[0m\n'
if [ "$APPLY" -eq 0 ]; then
	echo "Running in dry-run mode. Add --apply to execute."
fi

SERVICES="\
osmo-nitb.service \
osmo-bts-trx.service \
osmo-trx-lms.service \
osmo-pcu.service \
osmo-sgsn.service \
osmo-ggsn.service \
osmo-sip-connector.service"

for svc in $SERVICES; do
	run_cmd sudo systemctl disable --now "$svc" || true
	run_cmd sudo rm -f "/lib/systemd/system/$svc"
done
run_cmd sudo systemctl daemon-reload

if [ -s "$STATE_DIR/local-deb-packages.txt" ]; then
	PKGS="$(tr '\n' ' ' < "$STATE_DIR/local-deb-packages.txt")"
	if [ -n "$PKGS" ]; then
		if [ "$APPLY" -eq 1 ]; then
			if ! apt_retry purge -y $PKGS; then
				FAILED=1
			fi
		else
			echo "[dry-run] sudo apt purge -y $PKGS"
		fi
	fi
elif [ -s "$STATE_DIR/new-packages.txt" ]; then
	PKGS="$(tr '\n' ' ' < "$STATE_DIR/new-packages.txt")"
	if [ -n "$PKGS" ]; then
		if [ "$APPLY" -eq 1 ]; then
			if ! apt_retry purge -y $PKGS; then
				FAILED=1
			fi
		else
			echo "[dry-run] sudo apt purge -y $PKGS"
		fi
	fi
else
	log_warn "No package manifest found in $STATE_DIR (local-deb-packages.txt/new-packages.txt)."
fi

if [ "$PURGE_DEPS" -eq 1 ]; then
	# Keep generic build tools installed (autoconf/automake/libtool/pkg-config/build-essential)
	# to avoid forcing manual reinstall for subsequent runs.
	BASE_DEPS="osmo-ggsn osmo-sgsn osmo-pcu libfftw3-dev libsofia-sip-ua-glib-dev asterisk sqlite3 telnet libtalloc-dev liburing-dev libpcsclite-dev libusb-1.0-0-dev libmnl-dev libsctp-dev gnutls-dev libgnutls28-dev"
	if [ "$APPLY" -eq 1 ]; then
		if ! apt_retry purge -y $BASE_DEPS; then
			FAILED=1
		fi
	else
		echo "[dry-run] sudo apt purge -y $BASE_DEPS"
	fi
fi

run_cmd sudo apt autoremove -y
run_cmd sudo apt autoclean -y
run_cmd sudo dpkg --configure -a
run_cmd sudo apt install -f -y

run_cmd sudo rm -f /etc/ld.so.conf.d/local-lib.conf
run_cmd sudo rm -f /etc/ld.so.conf.d/local-lib-*.conf
if [ "$APPLY" -eq 1 ]; then
	if [ -L /usr/local/lib/libosmocodec.so.0 ]; then
		link_target="$(readlink /usr/local/lib/libosmocodec.so.0 || true)"
		case "$link_target" in
			libosmocodec.so.*)
				run_cmd sudo rm -f /usr/local/lib/libosmocodec.so.0
				;;
		esac
	fi
else
	echo "[dry-run] conditional remove /usr/local/lib/libosmocodec.so.0 if it is a compatibility symlink"
fi
run_cmd sudo ldconfig

run_cmd sudo rm -rf /usr/src/CalypsoBTS /usr/src/osmo-nitb /usr/src/auto
run_cmd sudo rm -rf "$SCRIPT_DIR/libosmo-dsp" "$SCRIPT_DIR/libosmocore"
run_cmd sudo rm -rf "$STATE_DIR"

printf '\033[32m\nCleanup completed.\n\033[0m\n'
if [ "$FAILED" -eq 1 ]; then
	log_warn "Cleanup completed with warnings. Re-run the same command once more to finish remaining items."
fi
