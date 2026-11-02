# Optional abapGit installation

The copy/paste installer remains the primary path. The repository's `.abapgit.xml` points to `/abapgit/`, which contains only executable `ZCHE_IMAP_INSTALL` and its program metadata. Import that installer into a development package and activate it, then execute it to create the actual DDIC objects, reports and commands. Importing the repository alone does not complete runtime installation.

Other source files under `abap/` are the editable inputs embedded by `installer/build.ps1`; `.abaplint-deps/` is never installable SAP source. Regenerate both installer copies after editing an input. Existing setup and authorization steps still apply.

Türkçe: abapGit yalnız installer programını getirir. Programı aktifleştirip çalıştırarak diğer nesneleri oluşturun. `.abaplint-deps/` dosyalarını SAP’ye yüklemeyin. Ana kurulum yolu tek installer kaynağını SE38’e kopyalamaktır.
