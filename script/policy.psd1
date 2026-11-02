# policy.psd1 - limits set by Basis. Lives in the same folder as imap.ps1
# (bin); read-only for the SAP service account. Profiles in SAP cannot
# go beyond these limits. The setup-server scripts generate this file.
@{
    # Failed local caches marked by the operator; inbox mail is untouched.
    InCacheRetentionDays = 30
    # Work folder: contains conf, secret, in, done, tmp, log
    WorkDir          = 'C:\sapimap'

    # Only these mail servers can be reached (lowercase)
    AllowedHosts     = @('mail.example.com')

    # Allow disabling the certificate check (test environments only)
    AllowInsecure    = $false
    # Allow unencrypted IMAP (143, no TLS)
    AllowPlainImap   = $false
    # Windows: certificate revocation list check (usually $false in a closed network)
    CheckRevoke      = $false
    # In-house CA file (empty: the operating system certificate store)
    CaCert           = ''

    # Upper limits that profiles cannot exceed
    MaxMailBytes     = 52428800
    RetentionDaysMax = 365
    TimeoutSecMax    = 600
}
