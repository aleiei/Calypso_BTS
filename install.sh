#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LIBOSMO_DSP_DIR="$SCRIPT_DIR/libosmo-dsp"
LIBOSMOCORE_DIR="$SCRIPT_DIR/libosmocore"

printf '\033[30;41m\nInstalling CalypsoBTS + osmo-nitb\n\033[0m\n'

sudo apt install osmo-ggsn osmo-sgsn osmo-pcu libfftw3-dev libsofia-sip-ua-glib-dev asterisk sqlite3 telnet python3-pip python3-tk libtool autoconf automake pkg-config build-essential libtalloc-dev -y
sudo pip3 install smpplib

if ! python3 -c "import tkinter" >/dev/null 2>&1; then
	sudo apt install python3.10-tk -y || true
fi

if ! python3 -c "import tkinter" >/dev/null 2>&1; then
	echo "ERROR: tkinter is not available. Install python3-tk (or python3.10-tk) and run again." >&2
	exit 1
fi

if [ ! -d "$LIBOSMO_DSP_DIR" ]; then
	git clone https://gitea.osmocom.org/sdr/libosmo-dsp.git "$LIBOSMO_DSP_DIR"
fi

cd "$LIBOSMO_DSP_DIR"
if ! autoreconf -i -f; then
	if [ -f "$LIBOSMO_DSP_DIR/../ltmain.sh" ] && [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ]; then
		cp -f "$LIBOSMO_DSP_DIR/../ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
	fi

	if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ] && [ -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" ]; then
		cp -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
	fi

	autoreconf -i -f
fi

if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ]; then
	echo "ERROR: ltmain.sh not found in $LIBOSMO_DSP_DIR (not even in build-aux)." >&2
	echo "Check autotools/libtool packages and run again." >&2
	exit 1
fi

./configure
make
sudo make install

if ! ldconfig -p | grep -q "libosmocoding.so.0" || ! ldconfig -p | grep -q "libosmocodec.so.0"; then
	printf '\033[33m\nlibosmocore runtime libs not found, building libosmocore...\n\033[0m\n'

	if [ ! -d "$LIBOSMOCORE_DIR" ]; then
		git clone https://gitea.osmocom.org/osmocom/libosmocore.git "$LIBOSMOCORE_DIR"
	fi

	cd "$LIBOSMOCORE_DIR"
	autoreconf -i -f
	./configure --prefix=/usr/local
	make
	sudo make install
fi

sudo cp -r "$SCRIPT_DIR/CalypsoBTS" /usr/src
sudo cp -r "$SCRIPT_DIR/osmo-nitb" /usr/src
sudo cp -r "$SCRIPT_DIR/auto" /usr/src

cd /usr/src/CalypsoBTS
sudo dpkg -i *.deb
sudo apt install -f -y

ARCH_LIBDIR="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)"
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local-lib.conf >/dev/null
if [ -n "$ARCH_LIBDIR" ]; then
	echo "/usr/local/lib/$ARCH_LIBDIR" | sudo tee /etc/ld.so.conf.d/local-lib-$ARCH_LIBDIR.conf >/dev/null
fi

sudo ldconfig

if command -v osmo-bts-trx >/dev/null 2>&1; then
	if ldd "$(command -v osmo-bts-trx)" | grep -Eq "libosmocoding\.so\.0 => not found|libosmocodec\.so\.0 => not found"; then
		echo "ERROR: osmo-bts-trx is missing runtime libraries (libosmocoding.so.0/libosmocodec.so.0)." >&2
		echo "Run: ldconfig -p | grep -E 'libosmocoding|libosmocodec'" >&2
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
