# Design overview

> **English** | [Türkçe](tr/DESIGN.md) · [README](../README.md)

SAP polls an existing IMAP mailbox. PowerShell and curl prepare messages as files on the SAP application server; ABAP programs manage configuration, the business action and monitoring. No separate integration server is required.

Business success and mailbox movement are recorded separately. If moving mail is interrupted after business success, a later run attempts to finish the move. This depends on the handler's transaction contract; external effects need their own duplicate protection.

The sources target older ABAP compatibility. Actual SAP runtime and older/non-Unicode verification status are documented in the [technical reference](TECHNICAL-REFERENCE.md#what-has-been-verified).

Current details:

- [Installation and first trial](WALKTHROUGH.md)
- [Files, permissions, limits and operations](TECHNICAL-REFERENCE.md)
- [Handler interface and transaction contract](TECHNICAL-GUIDE.md)

These current guides replace the earlier 1.0 design descriptions.
