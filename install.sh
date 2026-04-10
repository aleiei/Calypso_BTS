#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LIBOSMO_DSP_DIR="$SCRIPT_DIR/libosmo-dsp"
LIBOSMOCORE_DIR="$SCRIPT_DIR/libosmocore"
STATE_DIR="/var/lib/calypsobts-install"
PRE_PKG_LIST="/tmp/calypsobts-pkgs-before.$$"
POST_PKG_LIST="/tmp/calypsobts-pkgs-after.$$"
NEW_PKG_LIST="/tmp/calypsobts-pkgs-new.$$"
LOCAL_DEB_PKG_LIST="/tmp/calypsobts-local-deb-pkgs.$$"

export DEBIAN_FRONTEND=noninteractive

show_help() {
	cat <<'EOF'
Usage: ./install.sh

Options:
  -h, --help  Show this help.
EOF
}

log_info() {
	echo "[INFO] $*"
}

log_warn() {
	echo "[WARN] $*"
}

fatal() {
	echo "ERROR: $*" >&2
	exit 1
}

cleanup_tmp_lists() {
	rm -f "$PRE_PKG_LIST" "$POST_PKG_LIST" "$NEW_PKG_LIST" "$LOCAL_DEB_PKG_LIST"
}

trap cleanup_tmp_lists EXIT

repair_deb_state() {
	sudo dpkg --configure -a || true
	sudo apt install -f -y || true
	sudo apt --fix-broken install -y || true
	sudo dpkg --configure -a || true
}

apt_retry() {
	attempt=1
	while [ "$attempt" -le 3 ]; do
		if sudo apt -o DPkg::Lock::Timeout=120 "$@"; then
			return 0
		fi
		log_warn "apt command failed (attempt $attempt/3): apt $*"
		repair_deb_state
		attempt=$((attempt + 1))
	done
	return 1
}

retry_step() {
	desc="$1"
	shift
	attempt=1
	while [ "$attempt" -le 3 ]; do
		if "$@"; then
			return 0
		fi
		log_warn "Step failed (attempt $attempt/3): $desc"
		repair_deb_state
		attempt=$((attempt + 1))
	done
	fatal "$desc failed after multiple attempts."
}

have_osmo_runtime_libs() {
	sudo ldconfig
	ldconfig -p | grep -Eq "libosmocoding\.so(\.|$)" && ldconfig -p | grep -Eq "libosmocodec\.so(\.|$)"
}

install_first_available_pkg() {
	for pkg in "$@"; do
		if apt-cache show "$pkg" >/dev/null 2>&1; then
			apt_retry install -y "$pkg" && return 0
		fi
	done
	return 1
}

osmo_bts_trx_libs_ok() {
	if ! command -v osmo-bts-trx >/dev/null 2>&1; then
		return 0
	fi
	! ldd "$(command -v osmo-bts-trx)" | grep -Eq "libosmo.* => not found"
}

for arg in "$@"; do
	case "$arg" in
		-h|--help)
			show_help
			exit 0
			;;
		*)
			fatal "Unknown option: $arg"
			;;
	esac
done

if ! command -v sudo >/dev/null 2>&1; then
	fatal "sudo not found. Install sudo and rerun."
fi

for cmd in git autoreconf make ldconfig dpkg-query dpkg-deb; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		fatal "Required command not found: $cmd"
	fi
done

if ! sudo -v; then
	fatal "Unable to authenticate with sudo."
fi

printf '\033[30;41m\nInstalling CalypsoBTS + osmo-nitb\n\033[0m\n'

dpkg-query -W -f='${binary:Package}\n' | sort -u > "$PRE_PKG_LIST"

log_info "Installing required base packages..."
apt_retry install osmo-ggsn osmo-sgsn osmo-pcu libfftw3-dev libsofia-sip-ua-glib-dev asterisk sqlite3 telnet python3-pip python3-tk libtool autoconf automake pkg-config build-essential libtalloc-dev liburing-dev libpcsclite-dev libusb-1.0-0-dev libmnl-dev libsctp-dev -y || fatal "Failed to install base packages."

if ! dpkg -s gnutls-dev >/dev/null 2>&1; then
	if ! dpkg -s libgnutls28-dev >/dev/null 2>&1; then
		apt_retry install -y gnutls-dev || apt_retry install -y libgnutls28-dev || fatal "Failed to install gnutls development package."
	fi
fi
if ! python3 -c "import smpplib" >/dev/null 2>&1; then
	sudo pip3 install smpplib || fatal "Failed to install Python package smpplib."
fi

if ! python3 -c "import tkinter" >/dev/null 2>&1; then
	apt_retry install python3.10-tk -y || true
fi

if ! python3 -c "import tkinter" >/dev/null 2>&1; then
	echo "ERROR: tkinter is not available. Install python3-tk (or python3.10-tk) and run again." >&2
	exit 1
fi

if [ ! -d "$LIBOSMO_DSP_DIR" ]; then
	retry_step "Clone libosmo-dsp" git clone https://gitea.osmocom.org/sdr/libosmo-dsp.git "$LIBOSMO_DSP_DIR"
fi

cd "$LIBOSMO_DSP_DIR"
if ! autoreconf -i -f; then
	if [ -f "$LIBOSMO_DSP_DIR/../ltmain.sh" ] && [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ]; then
		cp -f "$LIBOSMO_DSP_DIR/../ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
	fi

	if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ] && [ -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" ]; then
		cp -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
	fi

	retry_step "autoreconf libosmo-dsp" autoreconf -i -f
fi

if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ]; then
	echo "ERROR: ltmain.sh not found in $LIBOSMO_DSP_DIR (not even in build-aux)." >&2
	echo "Check autotools/libtool packages and run again." >&2
	exit 1
fi

retry_step "configure libosmo-dsp" ./configure
retry_step "build libosmo-dsp" make
retry_step "install libosmo-dsp" sudo make install

if ! have_osmo_runtime_libs; then
	log_warn "osmo runtime libs not visible yet; trying distro libosmocore packages from APT"
	install_first_available_pkg libosmocore0 libosmocore22 libosmocore23 libosmocore24 libosmocore25 || true
	install_first_available_pkg libosmocodec0 libosmocodec1 libosmocodec2 libosmocodec3 libosmocodec4 libosmocodec5 || true
	install_first_available_pkg libosmocoding0 libosmocoding1 libosmocoding2 || true
	sudo ldconfig
fi

sudo cp -r "$SCRIPT_DIR/CalypsoBTS" /usr/src
sudo cp -r "$SCRIPT_DIR/osmo-nitb" /usr/src
sudo cp -r "$SCRIPT_DIR/auto" /usr/src

cd /usr/src/CalypsoBTS
if ! ls ./*.deb >/dev/null 2>&1; then
	fatal "No .deb packages found in /usr/src/CalypsoBTS"
fi

for deb in ./*.deb; do
	[ -f "$deb" ] || continue
	dpkg-deb -f "$deb" Package >> "$LOCAL_DEB_PKG_LIST"
done

if ! apt_retry install -y ./*.deb; then
	printf '\033[33m\nLocal .deb install had dependency/configuration issues, trying automatic recovery...\n\033[0m\n'
	repair_deb_state
	apt_retry install -y ./*.deb || fatal "Failed to install local .deb packages."
fi
repair_deb_state

dpkg-query -W -f='${binary:Package}\n' | sort -u > "$POST_PKG_LIST"
comm -13 "$PRE_PKG_LIST" "$POST_PKG_LIST" > "$NEW_PKG_LIST" || true
sudo install -d -m 755 "$STATE_DIR"
sudo cp "$NEW_PKG_LIST" "$STATE_DIR/new-packages.txt"
if [ -s "$LOCAL_DEB_PKG_LIST" ]; then
	sort -u "$LOCAL_DEB_PKG_LIST" | sudo tee "$STATE_DIR/local-deb-packages.txt" >/dev/null
else
	: | sudo tee "$STATE_DIR/local-deb-packages.txt" >/dev/null
fi

ARCH_LIBDIR="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)"
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local-lib.conf >/dev/null
if [ -n "$ARCH_LIBDIR" ]; then
	echo "/usr/local/lib/$ARCH_LIBDIR" | sudo tee /etc/ld.so.conf.d/local-lib-$ARCH_LIBDIR.conf >/dev/null
fi

sudo ldconfig

if command -v osmo-bts-trx >/dev/null 2>&1; then
	if ! have_osmo_runtime_libs; then
		printf '\033[33m\nRuntime libraries not visible yet, retrying ldconfig and dependency recovery...\n\033[0m\n'
		repair_deb_state
		sudo ldconfig
	fi

	if ! osmo_bts_trx_libs_ok; then
		printf '\033[33m\nosmo-bts-trx reports missing runtime libraries; trying distro runtime packages...\n\033[0m\n'
		repair_deb_state
		install_first_available_pkg libosmocore0 libosmocore22 libosmocore23 libosmocore24 libosmocore25 || true
		install_first_available_pkg libosmocodec0 libosmocodec1 libosmocodec2 libosmocodec3 libosmocodec4 libosmocodec5 || true
		install_first_available_pkg libosmocoding0 libosmocoding1 libosmocoding2 || true
		sudo ldconfig
	fi

	if ! osmo_bts_trx_libs_ok; then
		echo "ERROR: osmo-bts-trx has unresolved runtime libs after APT recovery." >&2
		echo "Do not force symlink .so.0 -> .so.4: ABI mismatch is unsafe." >&2
		echo "Diagnostic: ldd \"$(command -v osmo-bts-trx)\" | grep -E 'libosmo|not found'" >&2
		echo "Your local .deb set is likely built against a different libosmocore ABI than available on this OS." >&2
		exit 1
	fi
fi

cd /usr/src/osmo-nitb
sudo cp services/osmo-nitb.service /lib/systemd/system
sudo cp services/osmo-bts-trx.service /lib/systemd/system
sudo cp services/osmo-trx-lms.service /lib/systemd/system
sudo cp services/osmo-pcu.service /lib/systemd/system
sudo cp services/osmo-sgsn.service /lib/systemd/system
sudo cp services/osmo-ggsn.service /lib/systemd/system
sudo cp services/osmo-sip-connector.service /lib/systemd/system
sudo systemctl daemon-reload

sudo rm -f /usr/src/osmo-nitb/services/*.service

sudo rm -f /usr/src/CalypsoBTS/*.deb /usr/src/osmo-nitb/*.deb

sudo find /usr/src/CalypsoBTS /usr/src/osmo-nitb /usr/src/auto -type f -exec chmod +x {} \;

printf '\033[32m\nDone !\n\033[0m\n'
printf '\033[30;41m\nTo run osmo-nitb-scripts-calypsobts:\ncd /usr/src/auto && sudo python3 auto.py\n\033[0m\n'
