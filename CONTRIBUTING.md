# Contributing

This repository uses manual checks rather than an automated CI workflow. Run the relevant checks before sharing a change. SAP compiler/runtime validation remains necessary for SAP-side changes.

## Source checks and parser tests

Development prerequisites: Node.js 22+, npm and PowerShell 7. These are development tools; Node.js/npm are not needed on the SAP application server.

From the repository root:

```powershell
npm ci --ignore-scripts
pwsh -NoProfile -File test/check-source.ps1
pwsh -NoProfile -File test/run-tests.ps1 -Shell pwsh
```

On Windows, also run the parser tests with Windows PowerShell 5.1 when changing scripts used with that runtime:

```powershell
powershell.exe -NoProfile -File test/run-tests.ps1 -Shell powershell.exe
```

Tests create isolated fixtures under `work/`. Keep real mail and credentials out of the repository and test fixtures. ABAP source remains ASCII, at most 255 columns, with classic ABAP 7.00 syntax. The pinned abaplint 7.00 syntax check does not certify 7.00 or non-Unicode runtime compatibility.

## IMAP integration tests

These tests require a disposable local GreenMail instance with SMTP, IMAPS and its REST API. With Docker available, this PowerShell example binds only to localhost. Check that the container name and ports are free first:

```powershell
docker run --detach --name sapimap-doc-tests `
  --publish 127.0.0.1:3025:3025 `
  --publish 127.0.0.1:3993:3993 `
  --publish 127.0.0.1:8080:8080 `
  --env 'GREENMAIL_OPTS=-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.users.login=email' `
  greenmail/standalone:2.1.14
```

Wait until the service is ready, then run:

```powershell
pwsh -NoProfile -File test/run-imap-tests.ps1 -Shell pwsh
```

The suite creates a unique test user per run. Do not target a business mailbox. If using different local ports, pass `-SmtpPort`, `-ImapsPort` and `-ApiPort`. Review the retained fixtures when investigating a failure.

When finished, stop the test container you created:

```powershell
docker stop sapimap-doc-tests
```

## Regenerate the installer

After changing `abap/` or `installer/head.abap`, regenerate the distributable installer and include it with the source change:

```powershell
pwsh -NoProfile -File installer/build.ps1
pwsh -NoProfile -File test/check-source.ps1
```

Update SAP and both server modules together when the protocol or file format changes. Test installation/update, the chosen file-I/O mode, roles, a restricted background user and handler transaction behavior on the actual target SAP system. State what was tested and what remains unverified in the change description.

## Documentation

Keep the English and Turkish README, walkthrough, self-managed setup, technical reference and developer guide consistent. Assume the installer can create, activate and run SAP programs in SE38; address SAP steps directly to that reader. For server and email preparation, explain both self-administration and requesting help from the responsible teams. Keep the README as a plain-language introduction; put setup details, authorization objects, compatibility notes and test commands in the relevant guides. Start with the whole installation map (mail service, SAP host, SAP ERP), then explain each part in that order. Keep the walkthrough focused on the first successful trial, explaining what each step does, why it is needed, who helps and how to recognize success. Keep server commands and advanced operational checks in the technical reference. Explain the user's task before implementation details. Mark historical screenshots and distinguish compatibility targets from verified results. Visuals should explain the business need and first-use steps; retain accurate alt text and avoid claims that the demo creates business documents.
