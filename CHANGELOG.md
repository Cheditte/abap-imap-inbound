# Changelog

## 0.9.1 — release candidate

- Fix: 0.9.0 could not save a profile or process mail. The installer now writes the handler prefix (`ZCHE_IMAP_HANDLER_`) and retry limit (`3`) on first run and keeps existing values on a rerun.
- Server setup checks for curl 8.0.0 or newer at the start; Linux setup accepts `--curl-path`.
- Guides: authorization step with `S_LOG_COM` and `S_DATASET`, curl 8 requirement, handler template without the duplicate include, retry limit, setup commands for elevated sessions.

Upgrade from 0.9.0: stop processing and follow the [upgrade route](docs/WALKTHROUGH.md#upgrade). Replace and activate the SAP installer source, deploy both matching server modules, then rerun `ZCHE_IMAP_INSTALL` with **Programs, Overwrite existing programs (update), and Server check** selected after backup/review. Overwrite can replace local source changes.

## 0.9.0 — release candidate

- Rename SAP objects and commands to ZCHE_IMAP_; target classic ABAP 7.00.
- Preserve long profile arguments, tolerate nonrepresentable display text and bound long headers/attachment metadata.
- Check downloaded sizes, require curl 8.0.0+, use the declared codepage and ignore environment policy overrides.
- Restrict handler programs and profile access; disable table maintenance and group tables under ZCHI.
- Retire old credentials after successful publication; default to Basis-managed credentials.
- Bound retries and failed-cache retention while preserving committed move recovery.
- Add local regression checks, cross-platform CI and concise English/Turkish onboarding.

Tag/release publication follows PR approval; SAP acceptance was excluded by the operator.
