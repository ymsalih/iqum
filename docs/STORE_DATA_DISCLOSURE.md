# IQUM veri envanteri ve mağaza beyanları

Sürüm: 1.0.1 kaynakları, kontrol: 9 Kasım 2026. Bu bir doldurma çalışma kâğıdıdır; Play Console/App Store Connect'e otomatik gönderilmedi. Final AAB/IPA bağımlılıkları ve sağlayıcı belgeleriyle karşılaştırılmalıdır. SDK eklenirse beyanlar tekrar değerlendirilir.

## Gerçek veri akışı

| Veri | Yer / amaç | Hesapla bağlantı | Silme / saklama |
| --- | --- | --- | --- |
| Misafir level, kalp, rekor, yarım oyun, ses/titreşim | SQLite; çevrimdışı oyun | Misafir alanı; girişte isteğe bağlı aktarım | Misafir sıfırlama / uygulama kaldırma; aktarılan alan hesap silmede temizlenir |
| Google/Apple UID, ad, e-posta, varsa profil resmi URL'si | Firebase Authentication; giriş | Evet | Auth hesabı silinir; sağlayıcının kendi hesabı silinmez |
| Bulut level/rekor/kalp/oyun kayıtları | Firestore `users/{uid}` ve `runs/imports` | Evet | Hesap silmede belge ve alt koleksiyonlar temizlenir |
| Koşul sürümü/kabul zamanı | Firestore profil + gönderilene kadar yerel metadata | Evet | Hesapla birlikte silinir; kabul zamanı sunucudan |
| Oyuncu adı/UID, hamle, skor, zaman, bağlantı bilgisi | Firestore maç ve gizli sunucu belgeleri | Evet; yalnız gerekli maç bilgisi rakibe açık | Silmede UID/ad bağlantısı kaldırılır, gizli hamle/tahta/oda/işler temizlenir; rakibin sonucu korunabilir |
| Aktif oyuncu kilidi / eşleşme kuyruğu | Sunucu; aynı anda tek maç | Evet / maç ID | Silmede kilit ve ilgili kuyruk girdisi temizlenir |
| Silme işlem makbuzu | Yerelde UID + rastgele sır; sunucuda sırın SHA-256 özeti | Sınırlı UID bağlantısı | Sunucu tamamlanmadan silinmez; tamamlanınca 24 saat sonra temizlik görevi. Yerel tamamlandı ekranından devam edilince kaldırılır |
| IP, istek/teknik metadata ve App Check doğrulama verisi | Firebase/Google/Apple güvenliği ve hizmet sunumu | Sağlayıcı/istek türüne göre; takip amacı yok | Cloud Logging _Default 30 gün; zorunlu _Required 400 gün; Auth kaydedilen IP'leri birkaç hafta. App Check sağlayıcı süreçleri ayrıca geçerli |
| Destek talebi ve iletişim adresi | Kullanıcının başlattığı e-posta, kullanılan posta hizmeti | Talebin belirttiği hesapla | Talep kapanınca 90 gün içinde operasyonel temizlik; zorunlu hukuki saklama ayrı gerekçelendirilir |

Firebase Analytics, Crashlytics, reklam, ödeme, konum, kişiler, mikrofon/kamera kaydı, sohbet ve genel sıralama bu sürümde yoktur. Firebase konsolunda Analytics projesi bulunması, mobil Analytics SDK'sı kullanıldığı anlamına gelmez. Google Fonts fontları yerel varlıklardan yüklenir; tema çalışma anında font indirmez. Hayvanlar yerel çizimlerdir, kullanıcının fotoğraf galerisi okunmaz. Authentication'da bir profil fotoğrafı URL'sinin bulunması kullanıcı fotoğraf galerisine erişim demek değildir; sağlayıcının profil veri beyanı ayrıca kontrol edilir.

## Google Play Data safety çalışma kâğıdı

- Veri toplanıyor mu: **evet**. Misafir için bile teknik Firebase/attest istekleri vardır; “hiç veri toplanmaz” seçilmez.
- Hesap açma: üçüncü taraf Google hesabıyla oluşturma/giriş. Android'de Apple giriş seçeneği yoktur.
- Kişisel bilgiler: ad, e-posta, kullanıcı kimlikleri; **uygulama işlevi, hesap yönetimi, güvenlik/dolandırıcılığın önlenmesi** amaçları. Hesap isteğe bağlıdır; bu bilgiler çevrimiçi hesabın kullanımı için gereklidir.
- Uygulama etkinliği: oyun sonuçları/hamleleri ve etkileşim/bağlantı zamanları; hesapla ilişkilidir; bulut/düello için işlev ve güvenlik amaçları. Çevrimdışı kalan misafir oyunu yalnız cihazda olduğunda “cihaz dışına toplama” sayılmaz; aktarım seçilince toplanır.
- Cihaz veya diğer kimlikler: Firebase Auth UID ile cihaz ID'sini karıştırma. App Check / Play Integrity ve paketlerin final SDK açıklamalarına göre doğrulama/uygulama kimliklerini değerlendir. Firebase'in resmi Android açıklamasında App Check'in integrity tokenı ve kullanıcı aracısı bilgisi belirtilir. Advertising ID kullanımı var diye uydurma; kullanılan SDK tanımına giren diğer kimlikleri de gizleme.
- Tanılama: Crashlytics yoktur; buna rağmen sunucu hata/teknik kayıtları vardır. Kullanım biçimine göre gerçek veri türünü ve işlev/güvenlik amacını işaretle; “Crashlytics yok → hiçbir tanılama yok” çıkarımı yapma.
- IP'yi konum elde etmek için kullanmıyoruz; sırf istek IP'si var diye GPS/konum izni kullanıldığını söyleme. IP ve teknik güvenlik verileri gizlilik metninde açıklanır.
- Paylaşım: Google/Firebase hizmet sağlayıcıları ile veri işleme, üçüncü taraf girişleri ve oyuncunun kendi seçtiği düelloda görünen ad/skor ayrı incelenir. Play'in hizmet sağlayıcı ve kullanıcı başlatımlı paylaşım istisnalarını uygulayarak yanıtla. Toplu olarak “hiç paylaşım yok” denip rakibe açık bilgiler gizlenmez.
- Aktarımda şifreleme: canlı Firebase HTTPS/TLS ve platform SDK'ları kullanılır; yalnız yerel test emülatörü HTTP kullanır. Final sürümde `USE_FIREBASE_EMULATORS` ve `APP_CHECK_DEBUG` kapalı olmalı.
- Hesap/veri silme: evet; in-app akış + dış HTTPS silme sayfası. Yalnız çıkış/dondurma yoktur. Saklama istisnalarını açıkla.
- Bağımsız güvenlik denetimi / sertifika: böyle bir denetim alınmadı; var diye işaretleme.

## Apple App Privacy çalışma kâğıdı

Hesap ve oyun verileri kullanıcı kimliğine bağlıdır; reklam takibi için kullanılmaz. Uygulama manifestinde **Name, EmailAddress, UserID, GameplayContent, ProductInteraction** uygulama işlevi amacıyla beyan edilir. App Store Connect kategorileriyle eşleştirirken:

| Kategori | Kullanım | Kullanıcıya bağlı / takip |
| --- | --- | --- |
| Contact Info — Name / Email Address | Google/Apple hesabı | Bağlı / takip yok |
| Identifiers — User ID | Auth UID ve maç üyeliği | Bağlı / takip yok |
| User Content — Gameplay Content | Kayıtlar, eşleşme ve hamleler | Bağlı / takip yok |
| Usage Data — Product Interaction | Oyun ilerleme/etkileşim zamanları | Bağlı / takip yok |
| Teknik güvenlik / diğer veriler | App Attest nesneleri, SDK istek metadata/IP | Firebase iOS açıklamasına ve gerçek archive raporuna göre tür/bağlantı kontrolü; takip amacı yok |
| Customer Support | Kendi isteğiyle e-posta talebi | Destek içeriği; Apple'ın isteğe bağlı/seyrek toplama istisnasının gerçekten uygulanıp uygulanmadığını değerlendir |

Firebase/Google SDK manifestleri uygulamanın kendi backend beyanını otomatik doldurmaz; uygulama manifesti de SDK'ların bildirimlerini karşılamaz. Kullanılmayan kategorileri işaretleyerek veya boş manifest yazarak inceleme hatası bastırılmamalıdır. Final raporda farklı veri/required-reason API görülürse kaynak ve veri akışı incelenerek bu envanter/manifest güncellenmelidir. Bu Windows oturumunda gerçek iOS archive üretilmediği için SDK manifest birleştirmesi doğrulanmadı.

## Saklama yapılandırması kanıtı

`node scripts/audit_store_backend.cjs` yalnız altyapı ayarlarını okur. 9 Kasım 2026 sonucu: `_Default=30` gün, `_Required=400` gün (kilitli), yalnız iki varsayılan log sink'i; Firestore `europe-west1`, PITR kapalı, yedek zamanlaması yok. Rapor `output/store-backend-audit.json`. Bu, sağlayıcının tüm dahili kopyalarını inceleyebildiğimiz anlamına gelmez. Saklama/SDK değişince metni ve sürümü yenile.

## Resmi kaynaklar

- [Firebase Android Play veri açıklamaları](https://firebase.google.com/docs/android/play-data-disclosure)
- [Firebase iOS veri toplama açıklamaları](https://firebase.google.com/docs/ios/app-store-data-collection)
- [Firebase gizlilik/saklama](https://firebase.google.com/support/privacy)
- [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple manifest veri türleri](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
- [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)

Bu tablo mağazadaki formun tamamlandığı veya hukuki incelemenin yapıldığı beyanı değildir; gerçek yayıncı son beyanlardan sorumludur.
