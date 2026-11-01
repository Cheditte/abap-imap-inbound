# Server preparation

> **English** | [Türkçe](tr/SERVER-SETUP.md) · [Walkthrough](WALKTHROUGH.md)

Prepare the Windows/Linux machine running SAP. The server administrator can do this, or you can do it yourself if you have the necessary administration permissions.

1. Check PowerShell and curl with encrypted IMAP support.
2. Transfer both `server` and `script` folders from the same version.
3. Use the setup script to prepare the protected working folder and SAP service-account permissions.
4. Run the self-test and record the server and folder path SAP will use.

Commands and checks are in the [current server setup section](TECHNICAL-REFERENCE.md#server-setup-commands-and-checks). For RDP/SSH access, follow the [self-managed setup guide](SELF-MANAGED-SETUP.md).

Profile files are scoped by SID, client and profile. Setup, configuration, processing and monitoring are pinned to the same application server. Credential files are protected by OS permissions; the SAP account and privileged administrators can access them.

The linked current commands replace the earlier 1.0 setup examples.
