# Walkthrough: see your first email in SAP

> **English** | [Türkçe](tr/WALKTHROUGH.md) · [Project overview](../README.md) · [Technical details](TECHNICAL-REFERENCE.md)

By the end of this guide, you will be able to view a test email and its attachment from SAP. We will use the supplied example; you can add your own business process afterwards.

A functional consultant or process owner can coordinate setup. **Basis** (SAP system administration) helps prepare the server, your **email administrator** prepares the account, and an **ABAP developer** helps install the SAP programs.

**If you do not have these teams:** You can do the relevant preparation yourself when you administer your own test system. You may need to connect to the machine running SAP through **Remote Desktop (RDP)** on Windows or **SSH** on Linux. For the email account, you may use your provider's administration panel. You need access and management permissions for the relevant server or account. The [self-managed setup guide](SELF-MANAGED-SETUP.md) explains which route to follow.

**Start with a test SAP system and a test mailbox.** Processing may mark messages as read and move them to another folder. The supplied example does not create invoices or purchase orders.

This guide covers the 1.1.0 sources. Installation and runtime tests for this version on an actual SAP system are still pending. Images show the earlier 1.0 demonstration, so screens may differ. [Test status](TECHNICAL-REFERENCE.md#what-has-been-verified).

## Before you start: what are we preparing, and where?

Installation has two parts:

| Where? | What do we do? | Why is it needed? |
|---|---|---|
| **On the machine running SAP** | Check the helper tools, install anything missing and place the project's server files. | To connect to the email account and retrieve messages and attachments. |
| **Inside SAP** | Install the project's programs and enter the mailbox settings. | To start processing and view results from SAP screens. |

The computer where you open SAP GUI may be different from the machine running SAP. Basis should prepare the server. You do not need a separate integration server.

### Download the files and share them with your team

Open the [GitHub repository](https://github.com/Cheditte/abap-imap-inbound), choose **Code → Download ZIP** and unpack the entire archive. Git is not required.

Share the same package with Basis and the developer. Keep the folder structure and use files from the same version. Basis will use the server files; the developer will use the root-level `ZIMAP_INSTALL.abap` file.

### Prepare the test mailbox

Obtain the server name, port, security type and login details from your email administrator. **An email address and correct password may not be enough.** The account must allow another program to read it through **IMAP access**. Have the email team confirm that the account can connect with this project. [Detailed connection requirements](TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable).

If you do not have an email team, obtain these settings from your account's provider panel or provider support. Being able to open your mailbox does not mean you can change mail-server settings. [Preparing the account yourself](SELF-MANAGED-SETUP.md).

The default source is the **inbox (`INBOX`)**. You can select a different folder if you only want messages from there. For processed messages, you can use an existing folder in the same email account. The initial `SAP-Processed` value is an example; you do not have to create a new folder with that name. Confirm the actual folder names with the email team.

## 1. Prepare the server (Basis)

**What are we doing?** Preparing the tools and project files that retrieve email on the Windows or Linux machine running SAP. This is usually done once at initial setup.

| Component to prepare | What is it for? |
|---|---|
| **PowerShell** | Runs the project's mail retrieval commands. Windows needs 5.1 or later; Linux needs 7. |
| **curl** | Connects to the mail server. It must support encrypted IMAP connections. |
| **The project's server files** | Prepare messages and attachments as files SAP can read. They are included in the download. |
| **A protected working folder** | Holds email, attachments and connection settings on the server. Basis chooses its path and access permissions. |

Suitable PowerShell and curl installations do not need to be installed again. Basis installs anything missing using your organization's process, then runs the server setup included in the project. The Windows and Linux commands are in [server setup for Basis](TECHNICAL-REFERENCE.md#server-setup-commands-and-checks).

Basis also checks that **the machine running SAP can connect to the mail server**. Accessing the account from your own computer does not replace this check.

Without a Basis team, you can perform this step on your own test server if you have administration permissions. The [separate guide](SELF-MANAGED-SETUP.md) explains how to connect, transfer the files and choose the terminal in which to run the commands.

**When can you continue?** Once Basis confirms that the server test passes. Obtain the SAP server to use and the **full path** of the prepared working folder. We will use that same server and folder in the following steps.

## 2. Create the installer program

**What are we doing?** Preparing a program that creates the SAP programs and tables the project needs. This requires SAP development permission; involve your developer.

Enter `SE38` in SAP GUI's command field at the top. This opens the program editor. Use `/nSE38` if you are already in another transaction.

1. Enter **`ZIMAP_INSTALL`** as the program name and choose **Create**.
2. Enter a description and select **Executable program** as the type.
3. When saving, use a customer package prepared by your developer, for example `ZIMAP`. **Local Object** can be used for a temporary trial only.
4. Open the downloaded [ZIMAP_INSTALL.abap](../ZIMAP_INSTALL.abap) file and paste its **entire contents** into the SAP editor.
5. Save, check the syntax and choose **Activate**.

![Creating the installer in SE38 — earlier demonstration](screenshots/01-se38-create.png)

**When can you continue?** Once the program activates without errors. Have the developer resolve any errors before moving on. Keep the program name as shown.

## 3. Run the installer

**What are we doing?** The installer will create the SAP screens, tables and definitions needed to connect SAP to the server tools.

Open **`ZIMAP_INSTALL`** in SE38 and choose **Execute (F8)**.

![Installation options — earlier demonstration](screenshots/02-install-screen.png)

- For a first installation, leave **DDIC objects**, **Programs**, **SM69 commands** and **Server check** selected. These cover tables, programs, server commands and the final check.
- Enter the **full folder path supplied by Basis** in **Server folder**. Do not assume the example path is right for your system.
- Leave **Uninstall** cleared. Review the other options with the developer.
- Press **F8** and read the results.

**When can you continue?** Once the selected installation steps and final server check succeed. Share any failure output with Basis and the developer.

**For maintained use:** The installer currently creates its objects in the local area `$TMP`. Saving the installer itself in a package does not change this. The developer must assign the objects to a customer package and plan transport to test and production systems. [Package and transport details](TECHNICAL-REFERENCE.md#2b-before-production-package-and-transport).

## 4. Set up a mailbox profile

**What are we doing?** Telling SAP which email account to connect to and which folder to read. These settings are saved together as a **profile**.

Open **`ZIMAP_CONFIG`** in SE38 and run it with **F8**. Use a SAP session connected to the server Basis prepared; ask Basis to check if you are unsure.

![Mailbox settings — earlier demonstration; do not copy the connection details shown](screenshots/04-config-profile.png)

| Field | What should you enter or select? |
|---|---|
| Profile | A name for your settings, for example `INVOICE`. You may choose another name; use the same name in later steps. |
| Active | Selected, to allow this profile to be processed. |
| Server, port and security | Actual values from your email team. Do not enter your email address in the server field. Keep certificate verification enabled. |
| Username and password | Login details confirmed by the email team. Password source `S` means entering the password in SAP; `O` means Basis saves it on the server. Agree the method with Basis. |
| Folder to read | The default `INBOX` reads the inbox. For another folder, enter its actual name/path. |
| Processed folder | Actual name/path of the folder you select in the same email account for successful messages; choose a different folder from the source. The name `SAP-Processed` is not required. |
| Move method | Select `MOVE` for the first trial. |
| Handler program | Leave **`ZIMAP_HANDLER_DEMO`** selected. This is the supplied example program that runs for each message. |

For the trial, review the remaining message count, size and timeout limits with Basis and keep the starting values where appropriate. Full field descriptions and server password commands are in the [technical reference](TECHNICAL-REFERENCE.md#profile-fields-and-server-managed-passwords).

Press **F8** to save and test the connection. Keep passwords out of screenshots and support tickets.

**When can you continue?** Once the connection test succeeds for the intended mailbox. Saved settings alone do not prove the connection works.

## 5. Process mail

**What are we doing?** First checking that the mailbox can be read, then retrieving a test message.

Send an email with a small PDF or text attachment to the test mailbox. If you selected a source folder other than the inbox, place the message in that folder.

1. Open **`ZIMAP_INBOUND`** in SE38 and run it.
2. Enter the **profile name** saved in the previous step.
3. Select **List only (no downloads/changes)** and press **F8**. This lists eligible message numbers; it does not yet retrieve content or attachments, or move messages.
4. If listing succeeds, go back, **clear List only** and run it again. This time the email and attachments are retrieved, the supplied example runs and successful mail is moved to your processed folder.

![Processing screen — earlier demonstration; current list-only mode does not show content](screenshots/06-inbound-screen.png)

**When can you continue?** Once the run finishes. Next, we will check the result in SAP and in the mailbox.

## 6. Monitor mails and attachments

**What are we doing?** Checking the result and confirming that the attachment can be accessed from SAP.

1. Open **`ZIMAP_MONITOR`** in SE38 and run it.
2. Select your profile and a date range covering the test, then press **F8**.
3. Open your test message's record and inspect its text and attachments.
4. Open the email account too. Successful mail should be in the processed folder you selected.

![Results screen — earlier demonstration](screenshots/08-monitor-list.png)

| Status | Meaning |
|---|---|
| `S` | Processing and moving the mail are complete. |
| `E` | An error occurred; read the explanation in the record. |
| `R` | A failed message has been marked for another attempt. |
| `H` | The SAP business step is complete, but moving the mail is pending. |

PDFs and common images can open in a suitable application. Download other attachments, such as Excel files, and inspect them with an application on your computer.

**A successful first trial means:** you see status `S`, can access the attachment and can find the message in the processed folder. The supplied example does not also create an invoice or purchase order.

### If a step fails

- **Sign-in or folder error:** Ask the email team to check connection details, IMAP access and the selected folder names.
- **Connection, certificate or SAP permission error:** Ask Basis for help. Keep certificate verification enabled.
- **The example or your business program fails:** Review the error with the developer. The supplied example deliberately fails for subjects containing `TEST-ERROR`.

Share the error text and the step you reached, without passwords. Authorized users can mark failed messages for another attempt. Do not delete log records or server files to force reprocessing. [Retry details](TECHNICAL-REFERENCE.md#retention-and-retry-details).

## 7. Schedule regular processing

**What are we doing?** After the trial succeeds, having the mailbox checked automatically at agreed intervals.

Basis creates a **background job** for `ZIMAP_INBOUND`. It must use the correct profile, have list-only cleared and run on the **same SAP machine** prepared for this installation. Basis also tests with the user that will run the job.

Agree the real business action with the consultant and developer. For example, linking an attachment to a purchase order is added through the connection point in the [developer guide](TECHNICAL-GUIDE.md). Before production use, validate business rules, permissions and package/transport steps in your test system.

**If you are updating an existing installation,** follow the [upgrade procedure](TECHNICAL-REFERENCE.md#8-update-an-existing-installation) rather than directly repeating the first-install steps. Server commands and detailed checks are in the [technical reference](TECHNICAL-REFERENCE.md).
