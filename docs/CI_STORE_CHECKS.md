# Codemagic ve son paket kontrolleri

Bu dosya mevcut Codemagic iş akışına eklenecek adımları tanımlar; hesabına bağlanılmadı ve uzaktan derleme başlatılmadı. iOS için yerel Mac veya USB gerekmez. Güvenli değerleri Codemagic encrypted environment groups / signing integrations içinde sakla.

## Derleme öncesi (Codemagic macOS)

1. Mevcut Flutter sürümü 3.41.2 ile `flutter pub get`. Kilit dosyasını kullan; yayın öncesi kontrolsüz toplu paket güncellemesi yapma.
2. Ignore edilen `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json` ve kullanılıyorsa `config/firebase.json` dosyalarını CI güvenli dosya/şifreli değişkenlerinden geri yükle. Base64 çözme çıktısını konsola basma; `.p8`, service-account anahtarı ve parola repoya girmez.
3. `node scripts/build_legal_site.cjs --release` gerçek yayın bilgileri/metinleri kontrol etsin. Yayıncı bilgilerinin eksik olması burada kasıtlı başarısızlıktır.
4. `flutter analyze --no-pub` ve `flutter test --no-pub --concurrency=1`.
5. `node --test functions/test/*.test.js` sunucu bağımlılıkları `npm ci --prefix functions` ile hazırlanmışsa çalıştırılabilir. Firebase entegrasyonları ayrı yerel/CI emülatör işidir; canlı projeyi test hesabı silme alanı olarak kullanma.
6. Her mağaza yüklemesinde artan build number kullan. `pubspec.yaml` sürümü veya CI build-number override'ı korunmalı. `APP_CHECK_DEBUG` ve `USE_FIREBASE_EMULATORS` release tanımlarına eklenmez.

## İmzalama

- iOS: `com.iqum.iqum` App Store provisioning profile + geçerli dağıtım sertifikası; Sign in with Apple entitlement profile ile eşleşmeli. App Attest entitlement mevcut, gerçek cihaz doğrulaması ertelenmiş durumda. Firebase App ID/Google URL scheme ve Apple Team ID mevcut yapılandırmayla eşleşmeli.
- Android: gerçek upload keystore ve özel `android/key.properties`. Projede debug key'e release fallback kaldırıldı. Eksik imza ile release görevleri durur. Play App Signing sertifikalarını Firebase Google giriş/App Check ayarlarına kaydet.
- `scripts/store_preflight.cjs` iki platformun yapılandırma dosyaları ve Android anahtarını kontrol eder. Yalnız iOS CI çalışıyorsa Android anahtar kontrolünün ayrı Android işinde karşılanacağını raporda açık tut; eksik kontrolü geçmiş gibi gösterme.

## Archive / AAB alındıktan sonra

Henüz paket istenmediği için bu görevde aşağıdaki derlemeler çalıştırılmadı.

```sh
# Mevcut Codemagic signing/export ayarlarınla, paket talep edildiğinde:
flutter build ipa --release --build-number="$BUILD_NUMBER"
python3 scripts/audit_ios_archive.py build/ios/archive/Runner.xcarchive

# Android işinde:
flutter build appbundle --release --build-number="$BUILD_NUMBER"
```

`audit_ios_archive.py` uygulama privacy manifesti ve arşive gömülü manifestlerin yapısını raporlar. Tüm required-reason API kullanımını binary taramasıyla ispatlamaz; Xcode/Apple privacy report ve yükleme uyarılarıyla karşılaştır. Her framework'e gelişigüzel aynı reason code'u ekleme. SDK güncellemesi yapılırsa raporu yenile.

Final Android manifestini Android SDK `apkanalyzer manifest permissions` veya bundletool ile incele. Kaynaktaki internet/titreşime ek transitive izinler varsa nedenini doğrula; uygulama işlevi gerektirmiyorsa kaldır. Reklam kimliği, konum, kamera, mikrofon, geniş depolama, background service gibi izinler gerekçesiz yayımlanmamalı. Play Console'un gösterdiği target API/SDK uyarıları ve native 16 KB sayfa uyumluluğu final AAB'de çözülmeli; yalnız Dart testleri bunları kanıtlamaz.

Sonra TestFlight / Play iç test:

- Gerçek sağlayıcı girişleri, iptal/yanlış hesap, misafir aktarımı ve çıkış/tekrar giriş.
- İki cihazda ortak kartlar, sıra/süre/bağlantı, sonuç ve tek ödül.
- Gerçek hesap silme, iOS Apple revoke, tekrar açma, aynı sağlayıcıyla yeni hesabın eski veriyi geri getirmemesi.
- Yayın HTTPS politikaları ve dış e-posta talebi; engelli hesap veya uygulamayı tekrar kurma zorunluluğu olmamalı.
- Küçük ekran/erişilebilirlik ve fiziksel cihazda performans; test sonuçlarını `docs/VERIFICATION.md` içine ekle.

Bu kontrollerden sonra mağaza ekran görüntüleri, App Privacy/Data safety, yaş anketi, destek/inceleme erişimi ve yayıncı bilgileri son kez karşılaştırılır. Yayın/gönderim kullanıcının mağaza hesabında ayrı adımdır.
