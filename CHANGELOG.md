# Changelog

## Unreleased — 1.1.0 development sources

### Fixed

- Reject source and processed folder names that are identical or differ only in case, in both ABAP and the server script, before mail processing begins.
- Bound HTML conversion with token-based processing, character/tag limits, match timeouts and a total work budget. Malformed or excessive HTML returns `PARSE` instead of monopolizing processing.
- Wrap long body lines without repeatedly copying the remaining text.
- Clean each failed fetch's own temporary download and parsed files, including partial attachments. Published mail and unrelated files are preserved.
- Retry transient Windows directory rename failures for at most five attempts, without overwriting a destination or changing permissions.
- Remove unsupported COPY from new and existing `ZIMAP_MOVEMODE` domain values when the DDIC installation step runs; preserve unrelated fixed values.
- Scope monitor download names by SID, client, profile, UIDVALIDITY and UID.
- Correct the profile-deletion dialog: only current files are removed, and older credential/configuration revisions need controlled administrator cleanup.
- Replace obsolete setup/design instructions and correct the demo's list-only expectations.

### Validation

Regression coverage includes hostile HTML, long body lines, same-folder profiles and failed-transfer/parse cleanup. Source checks preserve ASCII ABAP and 72-column lines and verify the generated installer matches its sources.

Actual SAP compilation/runtime, older/non-Unicode releases, restricted-user background execution and end-to-end package transport still require validation on the target landscape. The compatibility range is a target, not a certification. No automated CI workflow is included.

### Updating

Update SAP sources and both server modules together. Run the DDIC step to remove the obsolete COPY choice from an existing domain. Stop and reconcile any old same-folder workflow before replaying mail; existing business duplicates are not automatically repaired. Follow the upgrade and credential-revision maintenance procedures in the technical reference.
