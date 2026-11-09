# IQUM canlı hesap bağlantısı

9 Kasım 2026 mağaza hazırlığı: hesap silme ve koşul kabul API'si; eraseAccountTask ve enqueueAccountDeletion fonksiyonları; silinen hesapların eski tokenlarla erişimini engelleyen kurallar canlıya yayımlandı. Üç önceki fonksiyon korunarak toplam beş fonksiyon güncellendi/oluşturuldu. Canlı salt okunur kontroller: girişsiz silme/kabul/profil 401, görev uçları 403, sahte durum makbuzu yalnız unknown/zaman döndürüyor. Gerçek kullanıcı hesabı oluşturulmadı/silinmedi; gerçek Google/Apple giriş ve iPhone Apple revoke doğrulaması hâlâ bekliyor. App Check izleme modunda kaldı. Mağaza dosyaları STORE_READINESS.md içinde.

9 Kasım 2026 ek doğrulama: Android emülatöründe native App Check debug token alımı ve canlı sunucuda `app: VALID` doğrulaması geçti. USB gerektirmedi. Kullanıcıya ait oyun/hesap kayıtlarına yazılmadı. Gerçek Android Play Integrity ve iPhone App Attest hâlâ bekliyor; canlı enforcement açılmadı. Kullanıcı iOS derlemelerini Codemagic ile alıyor; yerel Mac/USB zorunlu adım değildir. Ayrıntılar `VERIFICATION.md` ve `NATIVE_APP_CHECK_TEST.md` içindedir.

8 Kasım 2026. Firebase projesi: `iqum-4734b`.

App Check güncellemesi: mobil SDK ve sunucu kimlik/uygulama kontrolleri eklendi; API izleme modunda yeniden yayımlandı. 46 Flutter, 14 sunucu kural ve altı zorunlu-mod Firebase entegrasyon testi geçti; analiz temiz. Android Play Integrity ve iOS App Attest ayarları API'de mevcut (TTL 1 saat); Firebase iOS Team ID tamamlandı. Gerçek mobil tokenlar ve yeni sürüm doğrulanmadan zorunlu moda geçilmedi. Kullanıcının kalan adımları `APP_CHECK_SETUP.md` içindedir. APK/iOS paketi oluşturulmadı. RTDB/WebSocket yalnızca değerlendirildi; altyapı hâlâ Firestore + Functions + Cloud Tasks.

Son güvenlik güncellemesi: istemcide sunucu saatinden ilerleyen monoton saat, misafirler için salt okunur saat başlangıcı ve can aktarımında istemci tarihlerini kullanmama uygulandı. Üç fonksiyon yeniden yayımlandı. 42 Flutter, 12 sunucu kural ve beş Firebase entegrasyon testi geçti; analiz temiz. Canlı saat/erişim kontrolleri de geçti. Ayrıntılar `SECURITY.md` ve `VERIFICATION.md` içindedir. Gerçek cihaz OAuth doğrulaması hâlâ bekliyor.

## Tamamlananlar

- Kullanıcı Google sağlayıcısını Firebase Console'da etkinleştirdi.
- Güncel `google-services (9).json`, beklenen proje ve `com.iqum.iqum` paketiyle doğrulandı. Android OAuth kaydındaki SHA-1 bu bilgisayarın debug sertifikasıyla eşleşiyor; Web OAuth istemcisi mevcut.
- Dosya `android/app/google-services.json` konumuna alındı; `config/firebase.json` güncellendi. Bu dosyalar git dışında tutulur.
- Google Services Gradle eklentisi 4.4.4 eklendi; JSON bulunan kurulumlarda uygulanır. JSON olmayan checkout çevrimdışı kullanımı korur.
- `:app:processDebugGoogleServices` başarıyla çalıştı. Üretilen `default_web_client_id` ve `google_app_id`, yerel Firebase ayarlarıyla birebir eşleşti. APK oluşturulmadı.
- Firebase/Google çıkışı, hesap seçimi iptali, native iptal, eksik token ve kullanıcıya gösterilen bağlantı hataları düzenlendi.
- 37 Flutter testi geçti. Google credential aktarımı, iptal, token kontrolü ve çıkışın yanında Android Apple engeli ve iOS'ta iki giriş düğmesi doğrulandı. Bu testler gerçek Google/Apple hesabıyla oturum açma değildir.
- Firestore API etkinleştirildi. `(default)` Standard veritabanı `europe-west1` bölgesinde ücretsiz katmanla oluşturuldu; hazır güvenlik kuralları ve index tanımı canlı projeye yayımlandı.
- Kullanıcının tamamladığı konsol işlemleri sonrasında Google ve Apple sağlayıcılarının ikisinin de etkin olduğu ve faturalandırmanın açık olduğu doğrulandı. Ödeme hesabı bu çalışma tarafından bağlanmadı/değiştirilmedi.
- Yeni `GoogleService-Info (1).plist` proje/bundle kimlikleriyle doğrulandı; iOS Runner kaynaklarına eklendi. Google istemci kimlikleri, dönüş URL şeması, platforma özel FirebaseOptions ve üç Runner yapılandırmasının `LW7U87C5PM` imzalama takımı tamamlandı. Apple yeteneği ve entitlements bağlandı.
- iOS dosya aktarım betiğinin üç testi geçti: yinelenebilir aktarım ve diğer URL şemalarını koruma, hatalı proje/bundle/Google dönüş şemasını yazmadan reddetme.
- `api`, `advanceMatchTask` ve `enqueueMatchJob` Node 22 / `europe-west1` üzerinde canlı ve ACTIVE. İlk Eventarc izin yayılımı hatası sonrası eksik fonksiyon yeniden dağıtıldı; dağıtım tamamlandı.
- Canlı API kimliksiz `getProfile` isteğini 401/UNAUTHENTICATED ile reddetti; görev fonksiyonuna genel erişim 403 ile reddedildi. Görev kuyruğu RUNNING ve beş deneme/50 eşzamanlı görev yapılandırması doğrulandı.
- Gerçek kullanıcı/maç oluşturmadan yalıtılmış bir `matchJobs` kontrol belgesiyle Firestore tetikleyicisi → Cloud Tasks → yetkili görev çağrısı doğrulandı: tetikleyici 204, görev 204, Cloud Tasks `status: OK`, tek gönderim/tek yanıt. Geçici kayıt ve kuyruk günlüğü kontrol sonrasında temizlendi. Mevcut servis hesabı yetkileri yeterliydi; ek IAM rolü verilmedi.

## Kalanlar

- Gerçek Android Google hesap seçimi ve Firebase Authentication kullanıcısı oluşturma cihazda doğrulanmalı. Kullanıcı paket istemediği için yeni APK derlenmedi.
- Mac/Xcode'da provisioning ve gerçek iPhone üzerinde Google/Apple girişi, E-postamı gizle seçeneği, iptal ve tekrar giriş doğrulanmalı. Windows'ta Xcode/iOS derlemesi yapılmadı. App Store ID isteğe bağlıdır; Bundle ID `com.iqum.iqum` ile devam edilir.
- Gerçek giriş sonrasında misafir ilerlemesinin yeni/mevcut hesaba aktarılması ve yinelenen aktarımın veri/puan çoğaltmaması canlı cihazda doğrulanmalı. Yerel testlerin geçmesi gerçek sağlayıcıyla cihaz doğrulaması yerine geçmez.

## Apple konsolundaki alanlar

Android yalnızca Google; iOS Google ve yerel Apple girişi sunar. App ID için `Enable as a primary App ID` seçilir; ilişkili başka uygulamayla ortak giriş grubu istenmiyor. `Services ID` ve domain/Return URL web/Android Apple OAuth içindir, bu sürümün yerel iOS girişi için gerekli değildir. Kullanılan FlutterFire 6.7.1 iOS eklentisi `ASAuthorizationAppleIDProvider` kullanır.

`Server-to-Server Notification Endpoint` hesap silme veya e-posta yönlendirme değişikliklerini alan ayrı bir webhook adresidir. Bu işleyici uygulanmadı; alan şimdilik boş bırakılır. Firebase Return URL burada kullanılmaz. Bu durum native Apple girişini engellemez.

Kaynaklar:
- https://firebase.google.com/docs/auth/flutter/federated-auth
- https://firebase.google.com/docs/auth/ios/apple
- https://developer.apple.com/help/account/capabilities/enabling-server-to-server-notifications/
- https://firebase.google.com/docs/functions/get-started
