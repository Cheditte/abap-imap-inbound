# Ayrı bir destek ekibiniz yoksa: hazırlığı kendiniz yapın

> [English](../SELF-MANAGED-SETUP.md) | **Türkçe** · [Kurulum rehberi](WALKTHROUGH.md) · [Teknik başvuru](TECHNICAL-REFERENCE.md)

Ayrı bir Basis veya e-posta ekibinizin olması şart değildir. SAP'nin çalıştığı makineyi ve posta hesabını yönetmeye **yetkiniz varsa**, bu hazırlıkları kendiniz yapabilirsiniz. Bu rehber, zaten kurulu bir SAP sistemine proje dosyalarını eklemek içindir; yeni SAP sunucusu kurmaz.

SAP tarafında SE38 ile program oluşturma, etkinleştirme ve çalıştırma bilgi ve yetkinizin bulunduğu varsayılır; bu adımları siz yapacaksınız. Bu rehber, ayrıca sunucu ve posta yönetimini üstlenmeniz halinde gereken hazırlıkları anlatır.

SAP GUI'ye giriş yapmak, Windows/Linux makinesinde yönetici yetkisi vermez. Posta kutusunu webden açabilmek de posta sunucusunun yönetim paneline erişim vermez. Gerekli erişiminiz yoksa makinenin veya posta hizmetinin sahibinden destek alın.

**Önce deneme sistemi ve deneme posta kutusu kullanın.** Güncel 1.1.0 sürümünün gerçek SAP sistemindeki kurulum ve çalışma testleri henüz tamamlanmadı. [Doğrulama durumu](TECHNICAL-REFERENCE.md#neler-doğrulandı).

## 1. Hangi makineye bağlanacaksınız?

SAP ekranlarını açtığınız bilgisayar ile SAP'nin çalıştığı makine farklı olabilir. Projenin sunucu kurulumu **SAP'nin çalıştığı makinede** yapılır. Kendi bilgisayarınıza yardımcı araçları kurmanız bu adımı tamamlamaz.

Sunucu sahibinden veya kendi kurulum kayıtlarınızdan makinenin adını/IP adresini, işletim sistemini ve size verilmiş uzak bağlantı hesabını doğrulayın. Birden fazla SAP uygulama sunucusu varsa birini seçin; ayarlar, işleme ve izleme aynı sunucuda çalışmalıdır.

- Makine **Windows** ise aşağıdaki Uzak Masaüstü yolunu izleyin.
- Makine **Linux** ise SSH yolunu izleyin.
- Barındırılan hizmette makine erişimi size verilmiyorsa hizmet sağlayıcı hazırlığı yapmalıdır.

## 2a. Windows makinesine bağlanın

Bu adımlar, makinede size izin verilmiş bir Uzak Masaüstü bağlantısının zaten bulunduğunu varsayar.

1. Kurum bağlantıyı VPN üzerinden sağlıyorsa önce VPN'e bağlanın.
2. Kendi Windows bilgisayarınızda **Win + R** basın, `mstsc` yazıp Enter basın.
3. **Bilgisayar / Computer** alanına SAP makinesinin doğruladığınız adını veya IP adresini girin.
4. **Seçenekleri Göster / Show Options** altında size verilmiş kullanıcı hesabını seçip **Bağlan / Connect** ile giriş yapın.

Açılan masaüstünün doğru makineye ait olduğunu kontrol edin. Erişim reddedilirse sunucu sahibiyle çözün; bu rehber uzak erişim hizmeti veya güvenlik duvarı kuralı açmayı gerektirmez. [Microsoft'un Uzak Masaüstü açıklaması](https://support.microsoft.com/en-us/windows/experience/connectivity-networking/how-to-use-remote-desktop).

### Uzak makinede yönetici PowerShell açın

Uzak masaüstünün **Başlat** menüsünde **Windows PowerShell** arayın, sağ tıklayıp **Yönetici olarak çalıştır / Run as administrator** seçin. Windows'un yetki isteğini kendi yetkili hesabınızla onaylayın.

Yönetici grubunda olmak her PowerShell penceresinin yükseltilmiş olduğu anlamına gelmez. Aşağıdaki kontrolü **o uzak pencerede** çalıştırın:

```powershell
$SetupIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$SetupPrincipal = New-Object Security.Principal.WindowsPrincipal($SetupIdentity)
$SetupPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

`True`, bu işlemin yönetici yetkisiyle çalıştığını gösterir. `False` ise kurulum komutuna geçmeyin; pencereyi doğru yetkiyle açın. Dosya kopyalayabiliyor olmanız yönetici yetkisi kanıtı değildir. [Microsoft: WindowsPrincipal ve UAC davranışı](https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole?view=netframework-4.8.1).

### Araçları kontrol edin

```powershell
$PSVersionTable.PSVersion
curl.exe --version
```

Windows PowerShell **5.1** olmalı. Bu projenin Windows SAP komutu `powershell.exe` kullanır; ayrıca PowerShell 7 kurmak bu kontrolün yerini tutmaz. curl çıktısındaki **Protocols** satırında `imaps` bulunmalı. Windows PowerShell'de `curl.exe` yazın; `curl` başka bir komut olabilir.

Eksik veya uygun olmayan araç varsa işletim sisteminize uygun, onaylı kurulum yolunu kullanın: [Windows PowerShell hazırlığı](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/install/installing-windows-powershell), [curl Windows indirmeleri](https://curl.se/windows/). Windows'un sistem dosyalarının üzerine başka bir curl kopyalamayın. Ayrı konum kullanırsanız sunucu kurulumundaki `-CurlPath` ayarını gerçek dosya yoluna göre verin.

## 2b. Linux makinesine SSH ile bağlanın

Kendi bilgisayarınızda Windows Terminal'in PowerShell sekmesini açın. Bu blok **SAP Linux makinesinin gerçek adını/IP adresini ve size verilmiş giriş adını sorar**; örnek bir adres kullanmaz:

```powershell
& {
  $SapLinuxHost = (Read-Host 'SAP Linux makinesinin adi veya IP adresi').Trim()
  $LinuxLogin = (Read-Host 'Size verilmis yetkili Linux giris adi').Trim()
  if (@($SapLinuxHost, $LinuxLogin) -contains '') {
    throw 'Makine ve kullanici bilgileri gereklidir.'
  }
  ssh -l $LinuxLogin $SapLinuxHost
}
```

İlk bağlantıda gösterilen sunucu anahtarı parmak izini sunucu sahibinden doğrulayın. Parolayı bağlantı sorunca girin veya size atanmış SSH anahtarını kullanın. `ssh` bulunamıyorsa bilgisayarınızda **OpenSSH Client** özelliğinin kurulu olduğunu kontrol edin; [Microsoft'un SSH rehberi](https://learn.microsoft.com/en-us/windows/terminal/tutorials/ssh) bunu açıklar. Gerekiyorsa önce kurum VPN'ine bağlanın.

SSH oturumu açıldıktan sonraki komutlar **Linux makinesinde** çalışır. Mevcut yönetici/root hesabınızı veya size verilmiş `sudo` yetkisini kullanın. İzin reddedilirse sunucu sahibi çözmelidir.

### Araçları kontrol edin

```bash
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
command -v pwsh
curl --version
```

**PowerShell 7** ve `imaps` destekli curl gerekir. Bu projede SAP'nin başlattığı komut `/usr/bin/pwsh` yolunu kullanır; bu yolun kurulumunuzda mevcut ve çalışır olduğunu doğrulayın.

PowerShell eksikse Linux dağıtımınızı ve sürümünüzü belirleyip [Microsoft'un o dağıtım için kurulum adımlarını](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux) izleyin. curl için dağıtımın onaylı paket yöneticisini kullanın; [curl'ün dağıtım paketleri](https://curl.se/download.html) başvuru sağlar. Başka dağıtıma ait komutları kopyalamayın; uygun olmayan bir işletim sistemini bu proje için yerinde yükseltmeyin.

## 3. Projenin tamamını SAP makinesine aktarın

[Depodan](https://github.com/Cheditte/abap-imap-inbound) **Code → Download ZIP** ile indirdiğiniz paketin **tamamını** aktarın. Uzak makinedeki tarayıcıyla indirebilir veya izin verilen dosya aktarım yönteminizi kullanabilirsiniz. Linux'a aktarırken SSH ile çalışan dosya aktarımı (`scp`/SFTP) da kullanılabilir. Yalnız tek bir `.ps1` dosyasını taşımayın.

ZIP'i SAP makinesinde açın. Açılan **proje ana klasöründe** `server`, `script` ve `ZIMAP_INSTALL.abap` birlikte görünmeli. Sunucu komutlarını bu ana klasörden çalıştıracaksınız; ZIP'in açıldığı klasör, iletilerin saklanacağı korumalı çalışma klasöründen farklıdır.

Windows'taki yönetici PowerShell penceresinde proje klasörüne geçmek için:

```powershell
& {
  $ProjectFolder = (Read-Host 'SAP makinesinde acilan proje ana klasorunun tam yolu').Trim()
  if ($ProjectFolder -eq '') { throw 'Proje klasoru gereklidir.' }
  Set-Location -LiteralPath $ProjectFolder -ErrorAction Stop
  Get-Item server, script, ZIMAP_INSTALL.abap -ErrorAction Stop
}
```

Linux SSH oturumunda:

```bash
{
  read -r -p 'SAP makinesindeki proje ana klasorunun tam yolu: ' project_folder
  cd -- "${project_folder:?Project folder is required}" &&
    ls server script ZIMAP_INSTALL.abap
}
```

## 4. Sunucu kurulumunu ve kontrolünü tamamlayın

Kuruluma başlamadan **SAP'nin işletim sistemi hesabını** doğrulayın. Uzak bağlantıda kullandığınız kişisel yönetici hesabı ile SAP'yi çalıştıran servis hesabı aynı olmak zorunda değildir. Windows'ta **Hizmetler / Services** içindeki ilgili SAP servisinin **Oturum Aç / Log On** bilgisini, Linux'ta SAP kurulum kayıtlarını ve çalışan SAP süreçlerinin sahibini kontrol edin. Tahmin edilmiş bir hesap adı kullanmayın.

Ardından işletim sisteminize uygun adımları uygulayın:

- [Windows sunucu kurulum bloğu ve öz test](TECHNICAL-REFERENCE.md#windows)
- [Linux sunucu kurulum bloğu ve öz test](TECHNICAL-REFERENCE.md#linux)

Bu bloklar gerçek IMAP sunucusunu, SAP servis hesabını ve seçtiğiniz çalışma klasörünü sorar. Korunan klasörleri ve dosya izinlerini hazırlar; `imap.ps1` ile `mime.ps1` dosyalarını birlikte yerleştirir. Öz testin `OK` ile bittiğini, protokol `2` ve sürüm `1.1.0` bildirdiğini kontrol edin. Kullanılan klasörün tam yolunu kaydedin; SAP kurulum ekranında da aynısını kullanacaksınız.

Posta sunucusuna bağlantı **SAP makinesinden** kurulabilmelidir. Sertifika hatası varsa gerçek sunucu adını ve güvenilen sertifikaları düzeltin; sertifika doğrulamasını kapatmayın.

## 5. E-posta ekibi yoksa hesabı nasıl hazırlarsınız?

E-posta ekibiniz varsa aşağıdaki bilgileri ve kontrolleri onlardan isteyin. Ekip yoksa hizmetin yetkili yöneticisi olarak siz ilerleyebilir veya sağlayıcı desteğini kullanabilirsiniz.

Posta hizmetinizin **yetkili yöneticisi sizseniz**, sağlayıcının yönetim panelinden hesabın IMAP erişimini, giriş yöntemini ve klasör izinlerini kontrol edebilirsiniz. Bazı ayarlar hesap sahibinin web posta ayarlarında, bazıları yalnız yönetim panelindedir. **Sıradan bir web posta oturumu, sunucu yönetim yetkisi sağlamaz.**

Kendi posta sunucunuzu yönetiyorsanız bu kontroller, kullandığınız posta ürününün yönetim arayüzünde yapılır. O makineye ayrıca bağlanmanız gerekiyorsa posta sunucusunun kendi adresiyle izinli RDP/SSH bağlantısını kullanın. **Posta sunucusu ve SAP sunucusu farklı makineler olabilir.** Bu projenin PowerShell/curl ve dosya hazırlığı SAP makinesinde yapılır; posta tarafında hesap erişimi ve klasörler hazırlanır. Menü ve ayar adları posta ürününe göre değiştiğinden ürününüzün güncel yönetici kılavuzunu izleyin.

Sağlayıcınızın kendi belgelerinden şu bilgileri alın: gerçek IMAP sunucusu, port ve güvenlik türü, giriş kullanıcı adı, hesap için izin verilen parola yöntemi ve klasörlerin gerçek IMAP adları/yolları. E-posta adresini sunucu adı yerine yazmayın. Yetkili panel erişiminiz yoksa sağlayıcının desteğine başvurun.

Bu sürüm kullanıcı adı/parola ile bağlanır; **yalnız OAuth kabul eden hesaplar desteklenmez**. İki adımlı doğrulamada normal parola yeterli olmayabilir. Sağlayıcınızın izin verdiği bir uygulama parolası varsa kullanılabilir; her hesapta bulunmaz. İki adımlı doğrulamayı kapatmayın. Örnek sağlayıcı koşulları: [Microsoft'un IMAP bağlantı bilgileri](https://support.microsoft.com/en-us/outlook/pop-imap-and-smtp-settings-for-outlook-com), [Google uygulama parolaları](https://support.google.com/mail/answer/185833?hl=tr).

Hesabın ileti okuma ve taşıma izinlerini doğrulayın. Posta sunucusu **UID MOVE** desteklemelidir; bu sürümde COPY alternatifi yoktur.

- **Okunacak klasör:** Varsayılan `INBOX` Gelen Kutusu'nu okur. İsterseniz başka bir klasörün gerçek adını/yolunu seçebilirsiniz.
- **İşlenmiş klasörü:** Aynı posta hesabında, **okunacak klasörden farklı** bir hedef seçin. Mevcut klasör kullanılabilir; `SAP-Processed` adında yeni klasör açmak zorunlu değildir. Kaynak ve hedefin aynı olması veya yalnız büyük/küçük harfle ayrılması profil doğrulamasında reddedilir.

## 6. SAP içindeki adımlara dönün

Sunucu testiniz başarılı, çalışma klasörünüz ve posta bağlantı bilgileriniz hazırsa [SAP kurulum programını oluşturma adımına](WALKTHROUGH.md#31-kurulum-programını-oluşturun) dönün. Windows/Linux yönetici hesabınızdan ayrı olarak SAP içinde program oluşturma ve çalıştırma yetkiniz de olmalıdır.

Profili kaydedin, bağlantıyı test edin, önce yalnız listeleme sonra hazır örnekle normal deneme yapın. SAP'de sonucu ve posta kutusunda taşınan iletiyi kontrol edin. Ayrıntılar [kurulum rehberindedir](WALKTHROUGH.md).
