#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LIBOSMO_DSP_DIR="$SCRIPT_DIR/libosmo-dsp"

printf '\033[30;41m\nInstalling CalypsoBTS + osmo-nitb\n\033[0m\n'

sudo apt install osmo-ggsn osmo-sgsn osmo-pcu libfftw3-dev libsofia-sip-ua-glib-dev asterisk sqlite3 telnet python3-pip libtool autoconf -y
sudo pip3 install smpplib

if [ ! -d "$LIBOSMO_DSP_DIR" ]; then
	git clone https://gitea.osmocom.org/sdr/libosmo-dsp.git "$LIBOSMO_DSP_DIR"
fi

cd "$LIBOSMO_DSP_DIR"
libtoolize --force --copy
autoreconf -i -f

if [ -f "$SCRIPT_DIR/ltmain.sh" ]; then
	mv -f "$SCRIPT_DIR/ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
fi

if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ] && [ -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" ]; then
	cp -f "$LIBOSMO_DSP_DIR/build-aux/ltmain.sh" "$LIBOSMO_DSP_DIR/ltmain.sh"
fi

if [ ! -f "$LIBOSMO_DSP_DIR/ltmain.sh" ]; then
	echo "ERROR: ltmain.sh non trovato in $LIBOSMO_DSP_DIR (neanche in build-aux)." >&2
	echo "Controlla i pacchetti autotools/libtool installati e riesegui." >&2
	exit 1
fi

./configure
make
sudo make install

sudo cp -r "$SCRIPT_DIR/CalypsoBTS" /usr/src
sudo cp -r "$SCRIPT_DIR/osmo-nitb" /usr/src
sudo cp -r "$SCRIPT_DIR/auto" /usr/src

cd /usr/src/CalypsoBTS
sudo dpkg -i *.deb
sudo apt install -f -y
sudo ldconfig

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
printf '\033[30;41m\nFor run osmo-nitb-scripts-calypsobts just:\ncd /usr/src/auto && sudo python3 auto.py\n\033[0m\n'
