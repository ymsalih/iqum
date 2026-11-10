# IQUM mağaza yayın dosyası — 9 Kasım 2026

Bu dosya uygulama içi akışları, yayımlanacak sayfaları ve iki mağazada doldurulacak alanları birlikte tutar. Mağaza hesabına gönderim veya web yayını yapılmadı. Uygulama testlerinin geçmesi mağaza onayının veya gerçek cihaz doğrulamasının yerine geçmez.

## Uygulamada hazırlanan yollar

- **rPofil → Bilgilendirme ve gizlilik:** Gizlilik Politikası, Kullanım Koşulları, Oyun ve Hesap Bilgileri, Hesap ve Veri Silme. Metinler uygulamaya gömülüdür; hesap ve internet gerekmez.
- **Giriş öncesi:** veri kullanımının kısa açıklaması; açılabilir gizlilik/koşul metinleri; başlangıçta boş koşul kabul kutusu. Vazgeçen kullanıcı misafir kalır. Kabul sürümü ve sunucu zamanı hesaba kaydedilir; bu, pazarlama/açık rıza onayı olarak kullanılmaz.
- **Profil → Hesabımı sil:** kalıcı silme etkileri, açık onay, aynı Google/Apple hesabıyla yeniden kimlik doğrulama, sunucu isteği, işlem durumu ve tamamlanma. iOS Apple yeniden doğrulaması ardından tek kullanımlık yetki koduyla Apple erişimi iptal edilir. Yanlış hesapla yeniden doğrulama oturumu değiştirmez.
- Silme kabul edilince ilgili SQLite alanları, aktarılmış misafir alanları ve bekleyen yüklemeler temizlenir. Yeni misafir alanı açılır; başka kullanıcının yerel kayıtları silinmez. Ağ kesilirse işlem makbuzu korunur; tekrar açılışta durum denetlenir. Belirsiz/başarısız istek silindi diye gösterilmez.
- SQLite v1 → v2 geçişinde artık erişilmeyen eski misafir aktarım kopyaları temizlenir. Güncel misafir ilerlemesi, bütün kullanıcı alanları ve henüz gönderilmemiş donmuş aktarım paketleri korunur; bu geçiş ayrı test edildi.
- Firestore'un kalıcı istemci önbelleği kapatıldı; açılışta eski disk önbelleği temizlenir. Çevrimdışı oyun kaydı SQLite ile sürer. Android otomatik yedek/cihaz aktarımı uygulama kurallarında kapatıldı; üretici davranışı ve iOS yedeği gerçek cihazda ayrıca doğrulanmalı. Silme, fiziksel diskte anlık adli güvenli üzerine yazma iddiası değildir.
- **Bilgilendirme → Misafir verilerini sıfırla:** yalnız güncel misafir alanını, açık onaydan sonra temizler. Bulut hesap silme yerine geçmez.
- Aynı bölümde destek e-postası ve açık kaynak/font lisansları bulunur. Android yalnız Google; iOS Google ve yerel Apple gösterir.

## Önce gerçek yayın bilgilerini doldur

Tek kaynak: `assets/legal/publisher.json`.

| Alan | Yazılacak gerçek değer |
| --- | --- |
| `legalName` | Mağaza yayıncısı/veri sorumlusunun kişi veya şirket adı |
| `supportEmail` | Düzenli kontrol edilen, hesap/veri taleplerini alan gerçek adres |
| `contactAddress` | Yayıncının iletişim adresi; hayali adres kullanma |
| `publicOrigin` | Sayfaları yayımlayacağın HTTPS kök alan adı, ör. kendi alanın |
| `targetAudience` | Gerçek hedef yaş grupları; Play hedef kitle seçimiyle aynı olmalı |
| `version` | Uygulama metni ve sunucunun koşul sürümüyle aynı sürüm |
| `status` | Gerçek bilgiler/metinler gözden geçirilince `published` |

Bu bilgiler mevcut proje dosyalarından doğrulanamadığı için boş bırakıldı. Kod, eksik kimlik/iletişim ile yayın sayfası üretmeyi reddeder. Yaş hedefi bir içerik derecelendirmesi değildir. Çocukları hedefleyen bir yayın seçilirse çocuk verileri, ebeveyn izni ve mağaza Families/Kids koşulları için ayrıca ürün ve mevzuat değerlendirmesi gerekir. Politikalar gerçek işletmeci, yayın ülkeleri ve veri aktarımı sözleşmeleriyle son kez kontrol edilmeli; hazır metinler hukuki uygunluk garantisi değildir.

## Web yayını

1. Gerçek yayın bilgilerini doldur. Metin kaynağı `assets/legal/tr.json`; aynı metin uygulamada kullanılır.
2. Önizleme: `node scripts/build_legal_site.cjs`. Taslak işareti ve eksik bilgi raporu üretir.
3. Yayın sürümü: `node scripts/build_legal_site.cjs --release`. Bilgiler eksikse başarısız olur.
4. `legal_site/` içeriğini seçtiğin HTTPS barındırmaya aynı yollarla yükle. Firebase Hosting ayarı `firebase.json` içinde hazır: `firebase deploy --only hosting` ile `https://iqum-4734b.web.app/` altında yayımlanır (bu adresi kullanacaksan `publicOrigin` olarak yaz ve 3. adımı ondan sonra çalıştır). Bu çalışma kapsamında site yayımlanmadı.
5. Gerçek tarayıcı/gizli sekme ve telefonla, giriş olmadan, ülke/IP kısıtı ve düzenleme izni olmadan açıldığını doğrula. PDF bağlantısı kullanma. Otomatik HTTPS yönlendirmesini ve 200 yanıtlarını denetle.

Mağazaya verilecek yollar:

- Gizlilik: `https://KENDİ-ALANIN/gizlilik/`
- Kullanım koşulları: `https://KENDİ-ALANIN/kullanim-kosullari/`
- Uygulama dışı hesap silme: `https://KENDİ-ALANIN/hesap-silme/`
- Destek: `https://KENDİ-ALANIN/` (destek adresi ve ilgili sayfalar burada görünür).

Silme sayfası IQUM adını, silinen/saklanan verileri ve süreleri açıklar. Form, gerçek destek adresine e-posta hazırlatır; kendi başına sunucu talebi kaydetmez. Gönderme e-posta uygulamasında kullanıcıya aittir. E-posta uygulaması olmayan kişi gösterilen adresi kopyalayabilir. Bu yolu çalışır tutmak için **SUPPORT_OPERATIONS.md** süreci uygulanmalıdır. Yalnız bir gizlilik sayfası açıp silme yolunu gizlemek yeterli değildir.

## Google Play Console

| Bölüm | Bu sürüm için hazırlık |
| --- | --- |
| Ana mağaza girişi | `STORE_LISTING_TR.md` metinleri; gerçek sürüm ekran görüntüleri |
| Gizlilik politikası | Yayımlanan `/gizlilik/` HTTPS adresi |
| Veri güvenliği | `STORE_DATA_DISCLOSURE.md` envanterini final AAB ve SDK sürümleriyle kontrol ederek doldur |
| Hesap oluşturma/silme | Google ile hesap; uygulama içinde kalıcı silme; dış silme URL'si `/hesap-silme/` |
| Reklam | Bu sürümde reklam SDK'sı/gösterimi yok; reklam yok |
| Uygulama erişimi | Solo oyunlar açık; düello/bulut Google girişi gerektirir. İnceleme için gerçek akışı ve oda adımlarını açıkla |
| Hedef kitle/içerik derecesi | Anketi gerçek hedef yaşlara göre doldur; yaş derecesi uydurulmadı |
| Sağlık/finans/devlet vb. | Üründe olmayan kategorileri var diye işaretleme; IQUM tıbbi/zekâ testi değildir |
| İzinler | Kaynakta internet ve titreşim; final birleşik manifestte mikrofon/konum/kamera/Advertising ID gibi beklenmeyen izinleri kontrol et |
| İmzalama | Kendi upload anahtarı + Play App Signing. `android/key.properties.example` şablonu var; release debug anahtarıyla üretilmez |
| Firebase/Google | Play uygulama imzalama sertifikasının SHA-1/SHA-256 değerlerini Firebase'e ekle; gerekirse güncel JSON'u al. Upload ve Play dağıtım sertifikalarını karıştırma |
| Test/yayın | Hesabının Play Console'da gösterilen test/erişim koşullarını tamamla; kapalı/iç test → gerçek hesap/duello/silme → üretim |

## App Store Connect / Codemagic

- Bundle ID: `com.iqum.iqum`; mevcut Apple takımı ve Sign in with Apple entitlement korunur. Apple yerel giriş için domain/Return URL zorunlu adım değildir.
- Gizlilik politikası URL'si, destek URL'si, telif hakkı/yayıncı, yaş derecesi, kategori ve App Privacy beyanları doldurulmalı. `STORE_LISTING_TR.md` açıklama ve inceleme notları içerir.
- `ios/Runner/PrivacyInfo.xcprivacy` uygulama hedefinin Resources bölümüne eklendi. Takip yapılmadığını ve uygulamanın hesap/oyun verilerini beyan eder. Bu dosya SDK manifestlerini veya App Store Connect beyanını otomatik tamamlamaz. Gerçek `.xcarchive` içindeki Flutter/Firebase/Google/sqflite ve diğer eklenti manifestleri Codemagic üzerinde denetlenmeli; eksik required-reason bildirimi boş/uydurma gerekçeyle kapatılmamalı.
- ATT istemi eklenmedi: mevcut sürümde uygulamalar arası takip/IDFA reklam kullanımı yok. Firebase Analytics/Crashlytics mobil paketleri ekli değil. Yeni reklam/analiz eklenirse yeniden değerlendirilir.
- **CI_STORE_CHECKS.md** Codemagic için derleme öncesi ve arşiv sonrası komutları içerir; imzalama/API anahtarları CI güvenli değişkenlerinde tutulur. Mevcut Codemagic hesabına girilmedi, iş akışı uzaktan değiştirilmedi.
- TestFlight'ta gerçek Google ve Apple girişleri, Apple E-postamı Gizle, iptal/yanlış hesap, hesap silme ve tekrar açılış doğrulanmalı. Windows testi Apple sunucu yetki iptalini gerçek iPhone'da kanıtlamaz.
- Kullanıcı kararıyla iOS App Attest gerçek cihaz testi sonraya bırakıldı. App Check üretimde izleme modunda; bu iş zorunlu modu açmadı. Mağaza girişi ve silme akışı token bulunmadığında mevcut sunucu politikasına göre çalışır.

## Yayın kapıları

`store_assets/` içinde opak 512×512 Google Play simgesi, 1024×1024 App Store simgesi ve 1024×500 Google Play tanıtım grafiği hazır. iOS simgelerindeki gereksiz alfa kanalı kaldırıldı; logo çizimi korunuyor. 19 native simge ve üç mağaza görseli için 22 boyut/opaklık kontrolü geçti. Gerçek ekran görüntüleri bunlardan ayrıdır ve final uygulamadan alınmalı.

`node scripts/store_preflight.cjs` gerçek kimlik/iletişim, sürüm, üretim sayfaları ve Android imzalama önkoşullarını kontrol eder. Eksik gerçek bilgiler yüzünden bu kontrolün başarısız olması beklenir; testlerin geçtiği iddia edilerek atlanmamalıdır.

Paket istendiğinde son AAB/IPA üzerinde: gerçek iki oyuncu, giriş/aktarım/silme, ekran görüntüleri, küçük ekran/VoiceOver/TalkBack, uzun oturum performansı, TLS URL'leri, SDK/izin/manifest ve mağaza anketleri kontrol edilir. Bu görevde otomatik APK/IPA derlenmedi.

## Dayanaklar

- [Apple hesap silme](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple App Review kuralları](https://developer.apple.com/app-store/review/guidelines/)
- [Google hesap silme koşulları](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google kullanıcı verileri/gizlilik politikası](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Apple privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

Kontrol tarihi 9 Kasım 2026; mağaza formlarının yayın günündeki güncel alanları ayrıca geçerlidir.
