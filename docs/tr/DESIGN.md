# Tasarım özeti

> [English](../DESIGN.md) | **Türkçe** · [README](../../README.tr.md)

SAP mevcut bir IMAP posta kutusunu kontrol eder. PowerShell ve curl, iletileri SAP uygulama sunucusunda dosyalara hazırlar; ABAP programları bağlantı ayarlarını, iş adımını ve izlemeyi yönetir. Ayrı bir entegrasyon sunucusu gerekmez.

Başarılı iş adımı ile postanın taşınması ayrı kaydedilir. İş adımı tamamlandıktan sonra taşıma yarıda kalırsa sonraki çalışma taşımayı tamamlamayı dener. Bu davranış handler'ın işlem sözleşmesine bağlıdır; dış sistem etkileri için ayrıca mükerrerlik kontrolü gerekir.

Kaynaklar eski ABAP uyumluluğunu hedefler. Gerçek SAP çalışma zamanı ve eski/Unicode olmayan sürümlerdeki doğrulama durumu [teknik başvuru rehberindedir](TECHNICAL-REFERENCE.md#neler-doğrulandı).

Güncel ayrıntılar:

- [Kurulum ve ilk deneme](WALKTHROUGH.md)
- [Dosyalar, yetkiler, sınırlar ve işletim](TECHNICAL-REFERENCE.md)
- [Handler arayüzü ve işlem sözleşmesi](TECHNICAL-GUIDE.md)

Önceki 1.0 tasarım açıklamalarının yerini bu güncel rehberler alır.
