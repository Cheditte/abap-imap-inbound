# Demo environment on Google Cloud
> **English** | [Türkçe](../docs/tr/GCP-DEMO.md)

A disposable demo environment for learning and screenshots. Check your cloud account's costs and trial-credit conditions before creating resources. The current SAP 0.9.0 runtime still needs target-system validation.

```
Windows (SAP GUI) ──SSH tunnel──► Google Cloud VM (Ubuntu 24.04)
                                   ├─ a4h        SAP ABAP Cloud Developer Trial 2025
                                   │              └─ /usr/sap/sapimap  (imap.ps1, PowerShell 7)
                                   └─ greenmail  test mail server (IMAPS 3993, SMTP 3025)
```

SAP ports are not opened to the internet. Everything listens only inside the VM (127.0.0.1) and is reached from Windows through an SSH tunnel.

## 1. SSH key (Windows, once)

```bat
ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\sapimap -C demo
```
```bat
type %USERPROFILE%\.ssh\sapimap.pub
```
Copy the output line (`ssh-ed25519 AAAA... demo`).

## 2. Create the VM (Google Cloud Console → Cloud Shell, top right)

```bash
gcloud config set project PROJECT_ID
```
```bash
gcloud services enable compute.googleapis.com
```
```bash
gcloud compute instances create sapimap-demo \
  --zone=europe-west3-c \
  --machine-type=e2-highmem-4 \
  --image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud \
  --boot-disk-size=200GB --boot-disk-type=pd-balanced \
  --metadata=ssh-keys="demo:PASTE_PUBLIC_KEY_LINE_HERE"
```

- `e2-highmem-4`: 4 vCPU, 32 GB RAM (the memory SAP recommends).
- 200 GB disk: SAP recommends 150 GB; the unpacked image alone is over 53 GB.
- Note the `EXTERNAL_IP` from the output.

## 3. Copy the files and install (Windows)

```bat
scp -i %USERPROFILE%\.ssh\sapimap -r imap demo@EXTERNAL_IP:~/
```
```bat
ssh -i %USERPROFILE%\.ssh\sapimap demo@EXTERNAL_IP
```
On the VM, run the setup inside `tmux` so a dropped connection does not stop it:
```bash
tmux new -s setup
```
```bash
cd ~/imap && sudo bash cloud/setup-vm.sh
```
If the connection drops, reconnect and continue with `tmux attach -t setup`.

The script installs Docker, sets kernel parameters, asks you to accept the SAP license, logs in to Docker Hub (a free Docker Hub account is needed), starts GreenMail, pulls and starts the SAP image, installs PowerShell 7, runs the server setup, and sends sample mails. The longest step is pulling the image and the first SAP start.

The script ends by running the same server setup Basis would run ([WALKTHROUGH.md](../docs/WALKTHROUGH.md)), sends six sample mails, and runs the self-test as the SAP user (`a4hadm`). The last lines must show `STEP POLICY OK`, `STEP CURL OK`, `STEP FOLDERS OK` and `OK`.

## 4. SAP GUI connection (Windows)

Keep the tunnel open in a separate window:
```bat
ssh -i %USERPROFILE%\.ssh\sapimap -N -L 3200:127.0.0.1:3200 -L 3300:127.0.0.1:3300 -L 50001:127.0.0.1:50001 demo@EXTERNAL_IP
```

SAP Logon → new connection: application server `127.0.0.1`, instance number `00`, system ID `A4H`. Client `001`, user `DEVELOPER`; the password is on SAP's [trial image page](https://github.com/SAP-docs/abap-platform-trial-image).

## 5. Install in SAP

Follow the [SAP installation steps](../docs/WALKTHROUGH.md#31-create-the-installer-program). On this demo the server root folder is `/usr/sap/sapimap`; `ZCHE_IMAP_INSTALL` detects Linux and Unicode by itself.

In `ZCHE_IMAP_CONFIG`, the demo mailbox is: server `greenmail`, port `3993`, IMAPS, certificate check off, user `sap@demo.local`, password `sapdemo` (GreenMail test values only).

## 6. Screenshots

| # | Screen | What it should show |
|---|---|---|
| 1 | `ZCHE_IMAP_INSTALL` output | DDIC, programs, syntax checks, SM69 commands, server test OK |
| 2 | `ZCHE_IMAP_CONFIG` | Profile and the step-by-step connection test |
| 3 | `ZCHE_IMAP_INBOUND`, list-only | Eligible message numbers only; no body or attachment preview |
| 4 | Same report, test mode off | Processed mails |
| 5 | `ZCHE_IMAP_MONITOR` | List, mail details, a PDF and an image opened on the PC |
| 6 | Error scenario | A mail with `TEST-ERROR` in the subject: status `E`, then reprocessing |
| 7 | SM37 | Periodic job and spool output |
| 8 | Windows PowerShell | `test\run-tests.ps1` and `test\run-imap-tests.ps1` output |

No real server, customer or person names in screenshots; the demo uses `demo.local`.

Add a note under the screenshots: *"Run on ABAP Platform Trial 2025 (Linux, Unicode). Old non-Unicode releases use the LEGACY include and need to be verified separately."*

## 7. Shutting down

If you will use it again, stop it (only the disk is charged):
```bash
sudo docker stop -t 7200 a4h
```
```bash
gcloud compute instances stop sapimap-demo --zone=europe-west3-c
```

When you are done, delete it (all charges stop):
```bash
gcloud compute instances delete sapimap-demo --zone=europe-west3-c
```

The long timeout in `docker stop` (`-t 7200`) lets SAP HANA write its data to disk; do not power off the machine directly.
