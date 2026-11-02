# Changelog

## Unreleased — SAP installation correction

- Shorten the profile database table name from the invalid 17-character `ZCHE_IMAP_PROFILE` to `ZCHE_IMAP_PROF` throughout the installer, ABAP sources, authorization guidance and development fixture. The profile domain retains its original name.
- Reject database table names longer than 16 characters before creating any DDIC objects.
- Serialize installers separately and take the profile runtime lock after DDIC maintenance. Stop processing jobs before an upgrade.
- SAP installation of this correction has not yet been verified. Published v0.9.2 stops while creating the profile table; do not use its installer for a new installation.

## 0.9.2 — 2026-11-02 (release candidate)

- Fix: a failed profile save (for example "Mail identity in use") could be reported as successful. The success flag is now set only after the profile is saved.
- The profile value help lists only profiles the user may display (`ZCHE_IMAP` activity `03`).
- The processing log shows a profile's description only after the run authorization check (`16`).

Upgrade from 0.9.x: stop scheduled processing and back up as in [update an existing installation](docs/TECHNICAL-REFERENCE.md#8-update-an-existing-installation). Copy the new `imap.ps1` and `mime.ps1` to the server's `bin` folder (the script version must match). In SE38, replace the source of `ZCHE_IMAP_INSTALL` with the new file and activate it. Run it with **Programs**, **Overwrite existing programs (update)** and **Server check** selected.

## 0.9.1 — 2026-11-02 (release candidate)

- Fix: 0.9.0 could not save a profile or process mail. The installer now writes the handler prefix (`ZCHE_IMAP_HANDLER_`) and retry limit (`3`) on first run and keeps existing values on a rerun.
- Server setup checks for curl 8.0.0 or newer at the start; Linux setup accepts `--curl-path`.
- Guides: authorization step with `S_LOG_COM` and `S_DATASET`, curl 8 requirement, handler template without the duplicate include, retry limit, setup commands for elevated sessions.

## 0.9.0 — 2026-11-02 (release candidate)

- Rename SAP objects and commands to ZCHE_IMAP_; target classic ABAP 7.00.
- Preserve long profile arguments, tolerate nonrepresentable display text and bound long headers/attachment metadata.
- Check downloaded sizes, require curl 8.0.0+, use the declared codepage and ignore environment policy overrides.
- Restrict handler programs and profile access; disable table maintenance and group tables under ZCHI.
- Retire old credentials after successful publication; default to Basis-managed credentials.
- Bound retries and failed-cache retention while preserving committed move recovery.
- Add local regression checks, cross-platform CI and concise English/Turkish onboarding.
