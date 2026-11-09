# IQUM App Check kurulumu

8 Kasım 2026. Proje `iqum-4734b`, Android/iOS `com.iqum.iqum`.

## Kodda hazır olanlar

`firebase_app_check` 0.4.9 eklendi. Firebase açıldıktan sonra ve Auth/Firestore/Functions kullanılmadan önce App Check hazırlanır. Android Play Integrity, iOS App Attest kullanır. iOS App Attest entitlements ortamı `production`; Apple sandbox attestation Firebase tarafından kabul edilmez. SDK tokenları önbelleğe alır/otomatik yeniler; her hamlede yeni doğrulama istenmez.

Debug sağlayıcı yalnızca debug derlemede VE `APP_CHECK_DEBUG=true` istendiğinde seçilebilir. Release/profile sürümleri bu bayrakla bile debug sağlayıcıya dönmez. Yerel Firebase emülatörleri cihaz attestation servisini kullanmaz. Debug token veya özel anahtar kaynak dosyalara eklenmedi.

Sunucuda `api` için `APP_CHECK_ENFORCED` anahtarı ve yalnızca iki IQUM mobil Firebase app ID'sine izin veren kontrol hazır. Anahtar istemciden değiştirilemez. Hatalı boolean ayarı veya zorunlu modda boş uygulama listesi dağıtımı başarısız kılar. Cloud Tasks/Firestore tetikleyicileri App Check yerine kendi servis kimliklerini kullanmaya devam eder.

## Kullanıcının konsol ve cihaz adımları

Güncel karar: mevcut Firestore + Cloud Functions + Cloud Tasks korunur. Realtime Database oluşturulmaz.

Geliştirmeyi Google Play'e yüklemeden doğrulamak için önce debug yöntemi kullanılabilir: Android telefonunu USB hata ayıklama açık şekilde bağla ve PowerShell'i proje klasöründe aç. `C:\Users\HP\flutter\bin\flutter.bat run --dart-define-from-file=config/firebase.json --dart-define=APP_CHECK_DEBUG=true` komutunu çalıştır. İlk çevrimiçi istekte cihaz günlüğünde çıkan debug secret'ı Firebase App Check > Apps > IQUM Android > Manage debug tokens içine `IQUM Android test` adıyla kaydet, ardından uygulamayı tekrar başlat. Bu yöntem yalnızca geliştirme güven ilişkisini test eder. Gerçek Play Integrity/App Attest doğrulaması için aşağıdaki mağaza/cihaz adımları yine gerekir.

1. [Firebase App Check](https://console.firebase.google.com/project/iqum-4734b/appcheck) > Apps altında Android için Play Integrity, iOS için App Attest sağlayıcılarını kontrol et. Başlangıç token süresini 1 saat bırak. Sağlayıcı kaydının bulunması gerçek cihazın doğrulandığı anlamına gelmez.
2. Android mağaza testi için Google Play Console'da IQUM uygulamasını oluştur/aç. App integrity > Play Integrity API bölümünden **aynı** `iqum-4734b` Cloud projesini bağla. App signing key certificate altındaki **SHA-256** değerini Firebase Project settings > Android uygulamasına ekle. Yükleme anahtarı, debug anahtarı ve Play'in uygulama imzası farklı olabilir.
3. Güncel sürümü Play Internal testing kanalından cihaza kur. Play'de yayımlanmamış, dışarıdan yüklenen APK varsayılan `PLAY_RECOGNIZED` koşulunu karşılamaz. İlk geliştirme testi için aşağıdaki debug yöntemi kullanılabilir; üretim doğrulaması yerine geçmez.
4. Kullanıcı iOS derlemelerini **Codemagic** ile alıyor; yerel Mac veya USB zorunlu değil. Firebase iOS Team ID `LW7U87C5PM` olarak tamamlandı. Kaynakta Apple girişi ve App Attest `production` entitlements hazır. Codemagic'in kullandığı imzalama/provisioning profilinin bu yetkileri içermesi doğrulanmalı; gerekiyorsa profil yenilenip CI'da tekrar alınır. Gerçek App Attest kontrolü daha sonra TestFlight sürümü gerçek iPhone'a yüklenerek yapılabilir. iOS simulator debug sağlayıcısıyla çalışsa da gerçek App Attest doğrulamasının yerine geçmez.
5. Geliştirme/debug paketi gerekiyorsa `flutter run --dart-define-from-file=config/firebase.json --dart-define=APP_CHECK_DEBUG=true` kullanılır. SDK'nın cihaz günlüğünde ürettiği debug secret, Firebase App Check > ilgili uygulama > Manage debug tokens içine özel olarak kaydedilir. Android ve iOS için ayrı kayıt yapılır. Secret sohbete, git'e veya release pakete eklenmez.
6. Yeni SDK içeren sürümde hem Android hem iOS için App Check isteklerinin **Verified/Geçerli** olduğunu kontrol et. Google/Apple girişi, profil aktarımı ve iki telefonla düello denenmeli. Eski kurulmuş APK yeni SDK'yı içermez.
7. İki platform doğrulanınca geliştirici `functions/.env.iqum-4734b` içindeki `APP_CHECK_ENFORCED=true` ayarını yapıp `functions:iqum:api` dağıtımını tamamlar. Firebase App Check > APIs altında **Cloud Firestore** enforcement da bu aşamada açılır. Cloud Functions enforcement kodda yönetilir. Authentication enforcement ayrı bir ayardır; bu çalışma otomatik açmaz.

Kayıt ve gerçek cihaz doğrulaması bitmeden enforcement açılmaz; aksi hâlde gerçek kullanıcıların da erişimi kesilebilir. APK/iOS paketi kullanıcı istemedikçe oluşturulmaz.

## Geliştirici kontrolü

- Yerel zorunlu-mod testi: `powershell -File scripts/test_app_check.ps1`. Geçici `.env.local` ayarını geri yükler; `demo-iqum` dışında kaynak kullanmaz.
- Emülatör eksik/bozuk/yabancı uygulama kimliği isteklerini reddetmeyi test eder. Emülatör imzasız yapay kimlikleri yalnızca yerelde kabul eder; gerçek Play Integrity/App Attest attestation kanıtı değildir.
- Gerçek cihazlar hazırlandıktan sonra `APP_CHECK_ENFORCED=true` ile API yeniden yayımlanır. Tokensız/bozuk tokenlı canlı API isteği reddedilmeli; yeni mobil sürüm aynı anda çalışmaya devam etmelidir.
- Replay token tüketimi etkinleştirilmedi; bütün 5 saniyelik heartbeat/hamleler için ek attestation turu eklenmez. Hamle ve puan yine işlem kimlikleri/transaction ile yinelenmez.

Kaynaklar:
- https://firebase.google.com/docs/app-check/flutter/default-providers
- https://firebase.google.com/docs/app-check/android/play-integrity-provider
- https://firebase.google.com/docs/app-check/ios/app-attest-provider
- https://firebase.google.com/docs/app-check/cloud-functions
