# Calypso_BTS - GSM Base Station (EN/IT)

## English

![WARNING](https://img.shields.io/badge/WARNING-Legal%20Notice-red?style=for-the-badge)

Warning: this software is intended for education and security research on GSM networks. The author is not responsible for illegal use, including unauthorized interception, IMSI-catcher activity, or any operation forbidden by local law.

### Overview
This project sets up a GSM base station on Raspberry Pi using CalypsoBTS, Osmocom components, and a local Tkinter GUI.

### Requirements
- Raspberry Pi (Raspberry Pi 3+ recommended)
- Debian/Ubuntu based Linux (Ubuntu Mate 22.04.5 LTS 64-bit recommended)
- OsmocomBB compatible phones (for example Motorola C123/C121/C118)
- CP2102 USB-TTL adapter

### Installation
1. Install git:

```bash
sudo apt install git -y
```

2. Clone the repository:

```bash
git clone https://github.com/aleiei/Calypso_BTS.git
```

3. Enter the project directory:

```bash
cd Calypso_BTS
```

4. Run the installer:

```bash
sudo sh install.sh
```

The installer:
- installs system and Python dependencies
- builds and installs libosmo-dsp and required runtime libraries
- copies components to /usr/src/CalypsoBTS, /usr/src/osmo-nitb, and /usr/src/auto
- installs .deb packages from /usr/src/CalypsoBTS
- copies service files to /lib/systemd/system

### Uninstall
To remove the BTS installation from the system, run:

```bash
./uninstall.sh --apply --purge-deps
```

### Start With GUI
After installation, start the GUI:

```bash
cd /usr/src/auto
sudo python3 auto.py
```

Recommended sequence in GUI:
- TRX1 (and TRX2 if using two phones)
- Clock
- Database
- BTS

### Manual BTS Startup
If you want to start the stack manually, run the commands in this exact order.

Replace ARFCN with your channel number (for example 62, 75, 124).

```bash
sudo /usr/src/CalypsoBTS/osmocon -m c123xor -p /dev/ttyUSB0 -s /tmp/osmocom_l2 -c /usr/src/CalypsoBTS/firmwares/compal_e88/trx.highram.bin
sudo /usr/src/CalypsoBTS/transceiver -e 1 -a ARFCN -r99
sudo osmo-nitb --yes-i-really-want-to-run-prehistoric-software -c /usr/src/CalypsoBTS/openbsc.cfg -l /usr/src/CalypsoBTS/hlr.sqlite3 -P -C
sudo osmo-bts-trx -c /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg -d DRSL:DOML:DLAPDM
```

Notes:
- Keep one terminal per process.
- Start the next command only after the previous one is running correctly.
- NITB and BTS settings are in openbsc.cfg and osmo-bts-trx-calypso.cfg.

### ARFCN And Config Files
When using auto.py, configure parameters in:

```bash
sudo nano /usr/src/auto/transceiver.sh
sudo nano /usr/src/CalypsoBTS/openbsc.cfg
sudo nano /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg
```

### Notes
- The installer requires sudo privileges.
- If osmo-bts-trx reports missing libosmocoding/libosmocodec, rerun install.sh and then run sudo ldconfig.

## Italiano

![AVVISO](https://img.shields.io/badge/AVVISO-Nota%20Legale-red?style=for-the-badge)

Avviso: questo software e pensato per studio e ricerca sulla sicurezza delle reti GSM. L'autore non e responsabile per usi illeciti, incluse intercettazioni non autorizzate, attivita IMSI-catcher o qualsiasi uso vietato dalla normativa locale.

### Panoramica
Questo progetto configura una BTS GSM su Raspberry Pi usando CalypsoBTS, componenti Osmocom e una GUI locale in Tkinter.

### Requisiti
- Raspberry Pi (consigliato Raspberry Pi 3 o superiore)
- Linux Debian/Ubuntu (consigliato Ubuntu Mate 22.04.5 LTS 64-bit)
- Telefoni compatibili OsmocomBB (esempio Motorola C123/C121/C118)
- Adattatore USB-TTL CP2102

### Installazione
1. Installa git:

```bash
sudo apt install git -y
```

2. Clona il repository:

```bash
git clone https://github.com/aleiei/Calypso_BTS.git
```

3. Entra nella cartella del progetto:

```bash
cd Calypso_BTS
```

4. Esegui lo script di installazione:

```bash
sudo sh install.sh
```

Lo script:
- installa dipendenze di sistema e Python
- compila e installa libosmo-dsp e librerie runtime richieste
- copia i componenti in /usr/src/CalypsoBTS, /usr/src/osmo-nitb e /usr/src/auto
- installa i pacchetti .deb da /usr/src/CalypsoBTS
- copia i file service in /lib/systemd/system

### Disinstallazione
Per rimuovere il sistema BTS dalla macchina, esegui:

```bash
./uninstall.sh --apply --purge-deps
```

### Avvio Con GUI
Dopo l'installazione, avvia la GUI:

```bash
cd /usr/src/auto
sudo python3 auto.py
```

Sequenza consigliata nella GUI:
- TRX1 (e TRX2 se usi due telefoni)
- Clock
- Database
- BTS

### Avvio Manuale BTS
Se vuoi avviare tutto manualmente, esegui i comandi in questo ordine esatto.

Sostituisci ARFCN con il canale desiderato (ad esempio 62, 75, 124).

```bash
sudo /usr/src/CalypsoBTS/osmocon -m c123xor -p /dev/ttyUSB0 -s /tmp/osmocom_l2 -c /usr/src/CalypsoBTS/firmwares/compal_e88/trx.highram.bin
sudo /usr/src/CalypsoBTS/transceiver -e 1 -a ARFCN -r99
sudo osmo-nitb --yes-i-really-want-to-run-prehistoric-software -c /usr/src/CalypsoBTS/openbsc.cfg -l /usr/src/CalypsoBTS/hlr.sqlite3 -P -C
sudo osmo-bts-trx -c /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg -d DRSL:DOML:DLAPDM
```

Note:
- Usa un terminale separato per ogni processo.
- Avvia il comando successivo solo quando il precedente e in esecuzione correttamente.
- Le impostazioni NITB e BTS sono in openbsc.cfg e osmo-bts-trx-calypso.cfg.

### ARFCN E File Di Configurazione
Quando usi auto.py, modifica i parametri qui:

```bash
sudo nano /usr/src/auto/transceiver.sh
sudo nano /usr/src/CalypsoBTS/openbsc.cfg
sudo nano /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg
```

### Note
- Lo script di installazione richiede privilegi sudo.
- Se osmo-bts-trx segnala librerie mancanti libosmocoding/libosmocodec, riesegui install.sh e poi sudo ldconfig.

## License

This project is licensed under the MIT License.
Copyright (c) 2026 Alessandro Orlando.
