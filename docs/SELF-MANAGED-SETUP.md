# Prepare the system yourself when you do not have a separate support team

> **English** | [Türkçe](tr/SELF-MANAGED-SETUP.md) · [Walkthrough](WALKTHROUGH.md) · [Technical reference](TECHNICAL-REFERENCE.md)

A separate Basis or email team is not required. If you are **authorized to administer** the machine running SAP and the mail account, you can prepare them yourself. This guide adds project files to an existing SAP installation; it does not install a new SAP server.

You are assumed to have the skills and permissions to create, activate and run programs in SE38; you will perform those SAP steps yourself. This guide covers the additional preparation when you also take responsibility for server and email administration.

Being able to sign in to SAP GUI does not give you Windows/Linux administrator rights. Opening a mailbox in webmail does not give you mail-server administration rights either. If access is missing, involve the machine or email service owner.

**Start with a test system and test mailbox.** [Verification status](../VALIDATION.md).

## 1. Which machine should you connect to?

The computer where you open SAP screens may differ from the machine running SAP. The project's server setup runs **on the machine running SAP**. Installing helper tools on your own computer does not complete this step.

Confirm the hostname/IP address, operating system and assigned remote account with the owner or your installation records. If SAP has several application servers, select one; configuration, processing and monitoring must run on that same server.

- For a **Windows** machine, follow the Remote Desktop route below.
- For **Linux**, follow the SSH route.
- If a hosted service does not give you machine access, the hosting provider must prepare it.

## 2a. Connect to a Windows machine

These steps assume that an authorized Remote Desktop connection to the machine already exists.

1. Connect to your organization's VPN first if it is required.
2. On your own Windows computer, press **Win + R**, enter `mstsc` and press Enter.
3. In **Computer**, enter the confirmed name or IP address of the SAP machine.
4. Use **Show Options** to select your assigned account, then choose **Connect** and sign in.

Check that the desktop belongs to the intended machine. Resolve denied access with the owner; this guide does not require enabling remote services or opening firewall rules. [Microsoft's Remote Desktop guidance](https://support.microsoft.com/en-us/windows/experience/connectivity-networking/how-to-use-remote-desktop).

### Open administrator PowerShell on the remote machine

In the remote desktop's **Start** menu, search for **Windows PowerShell**, right-click it and choose **Run as administrator**. Approve the Windows prompt with your authorized account.

Membership in the administrators group does not mean every PowerShell window is elevated. Run this check **inside that remote window**:

```powershell
$SetupIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$SetupPrincipal = New-Object Security.Principal.WindowsPrincipal($SetupIdentity)
$SetupPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

`True` indicates that this process has administrator rights. If it returns `False`, open the window with the correct permissions before running setup. Being able to copy files is not proof of elevation. [Microsoft: WindowsPrincipal and UAC behavior](https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole?view=netframework-4.8.1).

### Check the tools

```powershell
$PSVersionTable.PSVersion
curl.exe --version
```

Windows PowerShell must be **5.1**. This project's Windows SAP command uses `powershell.exe`; installing PowerShell 7 alongside it does not replace this check. curl must be **7.66.0 or newer** (first line of the output), and its **Protocols** line must include `imaps`. If the built-in `curl.exe` is older, install a current build and pass its path to setup with `-CurlPath`. Use `curl.exe` in Windows PowerShell; `curl` can refer to a different command.

If a tool is missing or unsuitable, follow the approved installation method for your operating system: [Windows PowerShell preparation](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/install/installing-windows-powershell), [curl Windows downloads](https://curl.se/windows/). Do not overwrite Windows system files with another curl build. For a separate installation, supply its actual executable path through setup's `-CurlPath` option.

## 2b. Connect to a Linux machine over SSH

Open a PowerShell tab in Windows Terminal on your computer. This block **asks for the actual SAP Linux hostname/IP address and your assigned login name**, rather than using an example address:

```powershell
& {
  $SapLinuxHost = (Read-Host 'SAP Linux hostname or IP address').Trim()
  $LinuxLogin = (Read-Host 'Your assigned authorized Linux login').Trim()
  if (@($SapLinuxHost, $LinuxLogin) -contains '') {
    throw 'Hostname and login are required.'
  }
  ssh -l $LinuxLogin $SapLinuxHost
}
```

On first connection, verify the displayed host-key fingerprint with the machine owner. Enter your password when prompted, or use your assigned SSH key. If `ssh` is unavailable, check that **OpenSSH Client** is installed; [Microsoft's SSH guide](https://learn.microsoft.com/en-us/windows/terminal/tutorials/ssh) explains this. Connect to your organization's VPN first if required.

After SSH connects, commands run **on the Linux machine**. Use your existing authorized administrator/root account or assigned `sudo` permissions. Have the owner resolve denied access.

### Check the tools

```bash
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
command -v pwsh
curl --version
```

You need **PowerShell 7** and **curl 7.66.0 or newer** with `imaps` support. SLES 15 ships a suitable version; if yours is older, install a newer curl and pass its path to setup with `--curl-path`. The command started by SAP uses `/usr/bin/pwsh`; confirm that this path exists and works in your installation.

If PowerShell is missing, identify the Linux distribution and version, then follow [Microsoft's instructions for that distribution](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux). Install curl through the distribution's approved package manager; [curl's distribution packages](https://curl.se/download.html) provide a reference. Do not copy another distribution's commands or upgrade the operating system in place for this project.

## 3. Transfer the whole project to the SAP machine

Transfer the **entire** archive downloaded using **Code → Download ZIP** from the [repository](https://github.com/Cheditte/abap-imap-inbound). Download it in a browser on the remote machine or use your approved file-transfer method. SSH-based transfer (`scp`/SFTP) can be used for Linux. Do not transfer only a single `.ps1` file.

Extract the ZIP on the SAP machine. The **project root folder** must contain `server`, `script` and `ZCHE_IMAP_INSTALL.abap` together. Run server setup commands from that root. This extracted project folder is separate from the protected working folder that will hold mail.

In administrator PowerShell on Windows, change to the project folder:

```powershell
& {
  $ProjectFolder = (Read-Host 'Full path of the extracted project root on the SAP machine').Trim()
  if ($ProjectFolder -eq '') { throw 'Project folder is required.' }
  Set-Location -LiteralPath $ProjectFolder -ErrorAction Stop
  Get-Item server, script, ZCHE_IMAP_INSTALL.abap -ErrorAction Stop
}
```

In the Linux SSH session:

```bash
{
  read -r -p 'Full path of the project root on the SAP machine: ' project_folder
  cd -- "${project_folder:?Project folder is required}" &&
    ls server script ZCHE_IMAP_INSTALL.abap
}
```

## 4. Complete server setup and its check

First confirm **the operating-system account that runs SAP**. Your personal remote administrator account is not necessarily the SAP service account. On Windows, inspect **Log On** for the relevant SAP service in **Services**. On Linux, check the SAP installation records and the owner of the running SAP processes. Do not guess the account name.

Follow the instructions for your operating system:

- [Windows server setup block and self-test](TECHNICAL-REFERENCE.md#windows)
- [Linux server setup block and self-test](TECHNICAL-REFERENCE.md#linux)

The blocks ask for the actual IMAP server, SAP service account and chosen working folder. They prepare protected folders and permissions and deploy both `imap.ps1` and `mime.ps1`. Confirm that the self-test ends in `OK` and reports protocol `2` and version `0.9.3`. Record the full working-folder path; use the same path in the SAP installer.

The mail server must be reachable **from the SAP machine**. For certificate errors, correct the actual hostname and trusted certificates; keep certificate verification enabled.

## 5. Prepare the mailbox without an email team

If you have an email team, ask them for the settings and checks below. Without a team, proceed as the service's authorized administrator or use provider support.

If **you are an authorized administrator of the email service**, use the provider's administration panel to check IMAP access, the sign-in method and folder permissions. Some settings are available to the account owner in webmail, while others require the administration panel. **An ordinary webmail session does not provide server administration rights.**

If you administer your own mail server, use the administration interface for that mail product. If you need to connect to its machine, use its own address and your authorized RDP/SSH connection. **The mail server and SAP server may be different machines.** This project's PowerShell/curl and file preparation belongs on the SAP machine; account access and folders are prepared on the mail side. Menu names and settings vary by product, so follow its current administrator guide.

Obtain the actual IMAP hostname, port and security type, login username, permitted password method and actual IMAP folder names/paths from your provider's documentation. Do not enter the email address as the server name. If you lack authorized panel access, contact the provider's support.

This version connects with a username and password; **OAuth-only accounts are not supported**. With two-step verification, a normal password may not work. An app password may be usable where the provider permits it; it is not available for every account. Keep two-step verification enabled. Example provider requirements: [Microsoft's IMAP connection information](https://support.microsoft.com/en-us/outlook/pop-imap-and-smtp-settings-for-outlook-com), [Google app passwords](https://support.google.com/mail/answer/185833?hl=en).

Confirm the account can read and move messages. The server must support **UID MOVE**; this version has no COPY fallback.

- **Folder to read:** The default `INBOX` reads the inbox. You can select another folder's actual name/path.
- **Processed folder:** Select a destination in the same account that is **different from the source folder**. You can use an existing folder; a new folder named `SAP-Processed` is not required. Profile validation rejects identical names and names differing only in letter case.

## 6. Return to the steps inside SAP

Once the server test passes and you have the working-folder path and mailbox settings, return to [creating the SAP installer program](WALKTHROUGH.md#31-create-the-installer-program). You also need permission to create and run SAP programs; this is separate from Windows/Linux administrator access.

Save the profile, test the connection, run list-only first and then a normal trial with the supplied example. Check the result in SAP and the moved message in the mailbox. The [walkthrough](WALKTHROUGH.md) explains these steps.
