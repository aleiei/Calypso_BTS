# Calypso_BTS - GSM Base Station (EN/IT)

## English

![WARNING](https://img.shields.io/badge/WARNING-Legal%20Notice-red?style=for-the-badge)

**Warning:** This software was designed for educational and research purposes on GSM network security, including vulnerability assessment. The author assumes no responsibility for illegal use, including but not limited to unauthorized interception, IMSI-catcher activities, or any operation not permitted by applicable law.

### Overview
This project sets up a GSM base station on Raspberry Pi using CalypsoBTS, Osmocom components, and a local Tkinter GUI.

### Requirements
- Raspberry Pi (Raspberry Pi 3+ recommended)
- Debian/Ubuntu based Linux (Ubuntu Mate 22.04.5 LTS 64-bit recommended)
- OsmocomBB compatible phones (for example Motorola C123/C121/C118)
- CP2102 USB-TTL adapter

### Installation
1. Clone the repository.
2. Enter the project directory.
3. Run the installer:

```bash
sudo sh install.sh
```

The installer:
- installs system and Python dependencies
- builds and installs libosmo-dsp
- copies components to /usr/src/CalypsoBTS, /usr/src/osmo-nitb, and /usr/src/auto
- installs .deb packages from /usr/src/CalypsoBTS
- copies service files to /lib/systemd/system
- removes leftover .deb and .service files in /usr/src to avoid redundancy

### Start
After installation, start the GUI:

```bash
cd /usr/src/auto
sudo python3 auto.py
```

Recommended run order in the GUI:
- TRX1 (and TRX2 if using two phones)
- Clock
- DB
- BTS

### ARFCN change (Clock)
When using auto.py, do not edit the osmo-trx-lms systemd service.
Configuration is driven by the scripts and files opened/used by auto.py:

```bash
sudo nano /usr/src/auto/transceiver.sh
sudo nano /usr/src/CalypsoBTS/openbsc.cfg
sudo nano /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg
```

Notes:
- ARFCN (Clock) must be edited manually in /usr/src/auto/transceiver.sh (option -a of transceiver).
- NITB and BTS parameters are in /usr/src/CalypsoBTS/openbsc.cfg and /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg.
- These two cfg files are directly opened/editable from auto.py GUI using OpenBSC.cfg and OsmoBTS.cfg buttons.

### Notes
- The installer requires sudo privileges.
- After automatic cleanup, service templates are not kept in /usr/src/osmo-nitb/services.

## Italiano

![AVVERTENZA](https://img.shields.io/badge/AVVERTENZA-Nota%20Legale-red?style=for-the-badge)

**Avvertenza:** Questo software e stato concepito per finalita di studio e ricerca sulla sicurezza delle reti GSM, inclusa la verifica delle vulnerabilita. L'autore non si assume alcuna responsabilita per utilizzi illeciti, incluse, a titolo esemplificativo, intercettazioni non autorizzate, attivita di IMSI catcher o qualsiasi uso non consentito dalla normativa vigente.

### Panoramica
Questo progetto configura una base station GSM su Raspberry Pi usando CalypsoBTS, Osmocom e una GUI locale in Tkinter.

### Requisiti
- Raspberry Pi (consigliato Raspberry Pi 3 o superiore)
- Linux Debian/Ubuntu (Ubuntu Mate 22.04.5 LTS 64-bit consigliato)
- Telefoni compatibili OsmocomBB (es. Motorola C123/C121/C118)
- Adattatore USB-TTL CP2102

### Installazione
1. Clona il repository.
2. Entra nella cartella del progetto.
3. Avvia lo script di installazione:

```bash
sudo sh install.sh
```

Lo script:
- installa dipendenze di sistema e Python
- compila e installa libosmo-dsp
- copia i componenti in /usr/src/CalypsoBTS, /usr/src/osmo-nitb e /usr/src/auto
- installa i pacchetti .deb da /usr/src/CalypsoBTS
- copia i file service in /lib/systemd/system
- rimuove i .deb e i file .service residui in /usr/src per ridurre ridondanze

### Avvio
Dopo l'installazione, avvia la GUI:

```bash
cd /usr/src/auto
sudo python3 auto.py
```

Sequenza operativa consigliata nella GUI:
- TRX1 (e TRX2 se usi due telefoni)
- Clock
- DB
- BTS

### Modifica ARFCN (Clock)
Quando usi auto.py, non devi modificare il servizio systemd osmo-trx-lms.
La configurazione passa dagli script e dai file aperti/usati da auto.py:

```bash
sudo nano /usr/src/auto/transceiver.sh
sudo nano /usr/src/CalypsoBTS/openbsc.cfg
sudo nano /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg
```

Note:
- ARFCN (Clock) va impostato manualmente in /usr/src/auto/transceiver.sh (opzione -a del comando transceiver).
- I parametri NITB e BTS sono in /usr/src/CalypsoBTS/openbsc.cfg e /usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg.
- Questi due file cfg sono apribili/modificabili direttamente dalla GUI di auto.py con i pulsanti OpenBSC.cfg e OsmoBTS.cfg.

### Note
- Lo script di installazione usa sudo e richiede privilegi amministrativi.
- Dopo la pulizia automatica, i template service non restano in /usr/src/osmo-nitb/services.

## License

This project is licensed under the MIT License.
Copyright (c) 2026 Alessandro Orlando.
