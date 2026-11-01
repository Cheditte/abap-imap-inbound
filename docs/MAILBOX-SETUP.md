# Prepare the mail account

> **English** | [Türkçe](tr/MAILBOX-SETUP.md) · [Walkthrough](WALKTHROUGH.md)

If you administer the account, confirm the items below; otherwise ask the responsible team. Use a separate mailbox for the first trial.

## Required settings and permissions

- Actual IMAP hostname, port and connection security.
- Username, approved password method and IMAP access to the intended mailbox.
- Read and move permissions, and server support for **UID MOVE**. COPY fallback is not supported.
- Network access from the SAP machine and trusted server certificates.
- Actual names/paths of the source and a different destination folder for processed mail. Names differing only in letter case are also rejected.

The default source is `INBOX`. You may select an existing destination folder; the name `SAP-Processed` is not required. Both folders must belong to the same account.

## Sign-in method

A correct email address and password may not be enough. IMAP access must be allowed and the provider must accept the username/password sign-in implemented by this project. OAuth-only accounts cannot be used with this version. App-password availability with two-step verification depends on the provider and organizational policy; keep security protections enabled.

Provider panels and permission boundaries are explained in the [self-managed setup guide](SELF-MANAGED-SETUP.md#5-prepare-the-mailbox-without-an-email-team); see the [technical reference](TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable) for full requirements.

## A request for the mail administrator

> Please share the IMAP connection details, supported sign-in method and actual source/destination folder names for the dedicated SAP test account. Confirm read/move permissions, UID MOVE support and access from the SAP machine. Share the password through our approved secret-sharing method.

## Final check

Save the actual settings in `ZIMAP_CONFIG` and press F8 to test the connection. Saved settings alone are not enough; the connection test must pass too. Inspect any failed step's error text. Keep passwords out of support tickets and screenshots.
