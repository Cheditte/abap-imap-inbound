# Changelog

## 0.9.0 — release candidate

- Rename SAP objects and commands to ZCHE_IMAP_; target classic ABAP 7.00.
- Preserve long profile arguments, tolerate nonrepresentable display text and bound long headers/attachment metadata.
- Check downloaded sizes, require curl 8.0.0+, use the declared codepage and ignore environment policy overrides.
- Restrict handler programs and profile access; disable table maintenance and group tables under ZCHI.
- Retire old credentials after successful publication; default to Basis-managed credentials.
- Bound retries and failed-cache retention while preserving committed move recovery.
- Add local regression checks, cross-platform CI and concise English/Turkish onboarding.

Tag/release publication follows PR approval; SAP acceptance was excluded by the operator.
