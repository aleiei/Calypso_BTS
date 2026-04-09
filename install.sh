#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

printf '\033[30;41m\nInstalling CalypsoBTS + osmo-nitb\n\033[0m\n'

sudo apt install osmo-ggsn osmo-sgsn osmo-pcu libfftw3-dev libsofia-sip-ua-glib-dev asterisk sqlite3 telnet python3-pip -y
sudo pip3 install smpplib

if [ ! -d "$SCRIPT_DIR/libosmo-dsp" ]; then
	git clone https://gitea.osmocom.org/sdr/libosmo-dsp.git "$SCRIPT_DIR/libosmo-dsp"
fi

cd "$SCRIPT_DIR/libosmo-dsp"
autoreconf -i -f
./configure
make
sudo make install

sudo cp -r "$SCRIPT_DIR/CalypsoBTS" /usr/src
sudo cp -r "$SCRIPT_DIR/osmo-nitb" /usr/src
sudo cp -r "$SCRIPT_DIR/auto" /usr/src

cd /usr/src/CalypsoBTS
sudo dpkg -i *.deb
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

# Pulizia ridondanze: i file sono gia installati in /lib/systemd/system
sudo rm -f /usr/src/osmo-nitb/services/*.service

# Pulizia ridondanze: i pacchetti .deb sono gia installati
sudo rm -f /usr/src/CalypsoBTS/*.deb /usr/src/osmo-nitb/*.deb

# Richiesto: permessi di esecuzione su tutti i file copiati in /usr/src
sudo find /usr/src/CalypsoBTS /usr/src/osmo-nitb /usr/src/auto -type f -exec chmod +x {} \;

printf '\033[32m\nDone !\n\033[0m\n'
printf '\033[30;41m\nFor run osmo-nitb-scripts-calypsobts just:\ncd /usr/src/auto && sudo python3 auto.py\n\033[0m\n'
