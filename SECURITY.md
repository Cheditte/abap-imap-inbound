# Security and operations / Yetki ve işletim

## Provision before activation / Aktivasyondan önce

In SU20 create authorization field `ZCHE_PROF` (CHAR20, matching the profile key). In SU21 create customer object `ZCHE_IMAP` with `ZCHE_PROF` and standard `ACTVT`. Assign explicit profile values through PFCG; a missing object or grant fails closed.

| Activity | Permission / İzin |
|---|---|
| `03` | Monitor, body and attachment display; profile display. / Monitör, gövde, ek ve profil görüntüleme. |
| `02` | Configure/delete a profile; explicitly reprocess failed mail. / Profil bakımı ve hatalı maili yeniden işleme. |
| `16` | Run the inbound job for that profile. / Profilin gelen posta işini çalıştırma. |

The installer disables table maintenance and assigns `TDDAT` group `ZCHI`. Grant `S_TABU_DIS` only for the required table activities. Maintenance flags do not stop privileged SQL/debugging; do not grant production users generic table update or debug-change access. Root, handler prefix and retry limits are installer-owned parameters.

Tablo bakımı kapalıdır; `ZCHI` tablo grubu kullanılır. Yetkili geliştiricinin doğrudan SQL/debug erişimi ayrıca sınırlandırılmalıdır. Kök klasör ve handler izin listesi profil ekranından değişmez.

Set program authorization group `ZCHI` in SE38 attributes for CONFIG, INBOUND and MONITOR. Create matching SE93 report transactions `ZCHE_IMAP_CONFIG`, `ZCHE_IMAP_INBOUND`, `ZCHE_IMAP_MONITOR`; grant scoped `S_TCODE` and `S_PROGRAM`. These role/transaction steps are explicit administrator setup, not automatic role provisioning.

## File access / Dosya erişimi

| Principal | Scope |
|---|---|
| CONFIG user | `S_DATASET` ACTVT `34` for exact `conf/` and, only with screen-managed secrets, `secret/` paths; `06` on old revision credentials for rotation cleanup. No `33` read grant on secrets. |
| INBOUND/MONITOR users | Read only the required `in/` / `done/` files; INBOUND can write the failed-cache marker. No ABAP read access to `secret/`. |
| SAP service account | OS access to required work files; helper reads credentials. `bin/` scripts and policy must be administrator-owned and read-only to this account. |
| Other users | No secret-path read access, including CG3Y/generic file download. |

Production default is Basis-managed credentials, source **O** (the existing protocol value; not B). Basis-managed credential files are UTF-8, independent of the SAP display codepage; screen-managed credential files use the declared SAP codepage. The job never reads the credential through ABAP. Passwords remain plaintext files protected by OS and SAP authorizations. curl receives the password over stdin (`--config -`); neither password nor mail content is passed as a command argument.

Üretim varsayılanı Basis’in yönettiği **O** kaynağıdır. Parolalar şifreli kasa değildir; dosya izinleriyle korunur. Konfigürasyon kullanıcısına gizli klasörde okuma yetkisi verilmez. Ekran parolası kullanılıyorsa yeni profil commit edildikten sonra önceki revizyon silinir; silme izni yoksa açık bir temizlik uyarısı gösterilir. Başarısız yayınlamadan kalan yetim dosyaları Basis, etkin `CREDREV` değerleriyle karşılaştırarak temizler.

`SAPIMAP_POLICY` is ignored. Only administrator-owned `bin/policy.psd1` is loaded. Host allowlist, TLS restrictions, maximum size and timeout remain server policy. Certificate revocation checking defaults to false on Windows; set `CheckRevoke = $true` where the host can reach the CA's revocation services. Certificate-chain verification remains enabled in production.

## Handler and recovery / Handler ve kurtarma

Only programs matching the installer-owned `HANDLER_PREFIX` (default `ZCHE_IMAP_HANDLER_`) and a plain FORM name may run. Configuration and processing both enforce the policy. Handlers must not commit/rollback, call side-effecting RFC or leave the processor's LUW. The processor commits business work with H, then resumes only the move after a crash. No EXPUNGE is issued by production code.

`MAX_ATTEMPTS` defaults to 3 failed attempts. Ordinary runs skip E; retry mode respects the cap. Authorized monitor reprocessing changes E to R and explicitly permits another attempt. Inbox messages are retained, not silently deleted or automatically quarantined; operators review capped failures.

Failed local caches receive `failed.utc` only after E is committed. The helper removes that marker before a successful cache reuse can reach a handler. `PURGE` expires marked failed caches after `InCacheRetentionDays` (default 30). H/move-recovery caches have no failed marker and are retained. The original inbox mail remains available for an explicit retry. Unmarked caches and unknown files/links are not deleted. Completed archives use the profile's existing retention setting.

Türkçe özet: üç hata sınırı otomatik tekrarları durdurur; monitörde yetkili yeniden işleme açık bir operatör kararıdır. Hatalı önbellek 30 gün sonra temizlenebilir, posta kutusundaki özgün mail korunur. Commit edilmiş işin bekleyen taşıması temizliğe dahil edilmez.

## Migration / Geçiş

Stop old jobs before installing the renamed objects. `ZIMAP_` and `ZCHE_IMAP_` must never process the same mailbox concurrently. Reconcile old H/S business effects and mail identities before importing any log history. No old table, program, mailbox or credential is removed automatically. This candidate does not provide an automatic migration of production history.
