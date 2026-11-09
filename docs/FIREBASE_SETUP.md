# IQUM çevrimiçi servis kurulumu

Çevrimdışı üç oyun Firebase olmadan çalışır. Yerel ortam `iqum-4734b` projesine bağlandı; Android ve iOS yapılandırmaları eklendi, Firestore kuralları ve üç Cloud Functions fonksiyonu canlıya yayımlandı. Gerçek cihazda Google/Apple OAuth doğrulaması bekleniyor. Ayrıntılı durum `AUTH_STATUS.md` içindedir. Aşağıdaki adımlar yeni kurulumlar için genel rehberdir.

## Proje ve uygulamalar

1. Firebase Console'da projeyi açın; Authentication ve Firestore'u etkinleştirin.
2. Android uygulamasını `com.iqum.iqum`, iOS uygulamasını aynı bundle kimliğiyle kaydedin. Kimlikleri değiştirirseniz Flutter platform dosyalarını ve Firebase kayıtlarını birlikte değiştirin.
3. Authentication sağlayıcılarında Google ve Apple'ı etkinleştirin. Google için hem test hem mağaza imzalarına ait SHA-1/SHA-256 değerlerini ekleyin. Apple için Apple Developer hesabındaki Sign in with Apple ayarlarını tamamlayın.
4. `config/firebase.example.json` dosyasını `config/firebase.json` olarak kopyalayın. Firebase uygulama ayarlarından API key, project ID, sender ID, Android ve iOS app ID alanlarını doldurun. Google Web OAuth client ID ve iOS OAuth client ID ayrı alanlardır.
5. `python3 scripts/configure_firebase_ios.py /path/to/GoogleService-Info.plist --team-id YOURTEAMID` çalıştırın. Bu işlem proje/bundle kimliklerini doğrular; yerel Firebase dosyasını, iOS Google URL şemasını, Xcode kaynak üyeliğini ve Apple yeteneğini ekler. Xcode'da Runner hedefinin imzalama takımını ve provisioning profilini doğrulayın.

Android yalnızca Google; iOS Google ve yerel Apple girişi sunar. Yerel Apple girişi için Services ID/domain/Return URL gerekmez. App ID ayarında IQUM bir primary App ID olarak seçilir. Server-to-Server Notification Endpoint alanı giriş dönüş adresi değildir; hesap değişikliği bildirimlerini alan ayrı bir servis kurulana kadar boş bırakılır.

Bu dosya Firebase uygulama yapılandırmasıdır; hizmet hesabı özel anahtarı veya Apple özel anahtarı içermez. Bu özel anahtarları mobil uygulamaya koymayın. Firebase kuralları kullanıcıların puan ve maç belgelerini doğrudan yazmasını engeller.

## Sunucu dağıtımı

Node 22 ve Firebase CLI bulunan ortamda:

```sh
cd functions
npm ci
npm test
cd ..
firebase login
firebase use --add
firebase deploy --only firestore,functions
```

Fonksiyon bölgesi `europe-west1` olarak sabittir; mobil yapılandırmadaki `FUNCTIONS_REGION` aynı olmalıdır. Sunucu Cloud Functions, Firestore tetikleyicileri ve Cloud Tasks kullanır. Projede bu servislerin etkin olması ve bunları kullanabilen Firebase/Google Cloud faturalandırma planı gerekir. Cloud Tasks çağıran servis hesabının ilgili kuyruğa görev ekleyebilmesi ve `advanceMatchTask` fonksiyonunu çağırabilmesi gerekir; eksik IAM yetkisi varsa dağıtımın bildirdiği hesaba bu yetkiler tanımlanır.

`matchJobs` belgeleri maç güncellemesiyle atomik yazılır; tetikleyici kuyruk görevini oluşturur. Süre aşımı ve geri bildirim kapanması oyuncuların telefonlarına bağlı değildir. Yeniden gönderilen görev/hamle/sonuç puanı çoğaltmaz. Oda ve arama kayıtları kullanım sırasında mantıksal olarak sona erer; geçmiş maç ve outbox kayıtlarının uzun vadeli saklama politikası yayın trafiğine göre ayrıca ayarlanabilir.

## Uygulamayı gerçek servislere bağlama

```sh
flutter run --dart-define-from-file=config/firebase.json
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config/firebase.json
```

iOS 15+ hedeflenir. Mac'te `flutter pub get` sonrasında Xcode imzalama ayarlarını tamamlayıp aynı `--dart-define-from-file` seçeneğiyle `flutter build ios` çalıştırın. Mağaza sürümünün Android imzalama anahtarı ve iOS dağıtım profili ayrıca kullanıcı tarafından sağlanmalıdır. Depodaki test APK mağaza imzası taşımaz.

## Yerel servis testi

Canlı projenin veya gerçek kullanıcı verilerinin gerekmediği test:

```sh
cd functions
npm ci
cd ..
firebase emulators:exec --project demo-iqum --only auth,firestore,functions "node --test functions/test/emulator.integration.js"
```

Java 21+ gerekir. Testler yalnızca `.invalid` alan adlı yapay kullanıcılar oluşturur; e-posta göndermez. Firestore kurallarını, iki oyunculu ortak tahtayı, gerçek 15 saniyelik hamle aşımını, rastgele eşleşmeyi, kayıt aktarımını, tekrar denemeyi ve puanın tek seferlik yazılmasını kontrol eder. Google/Apple'ın gerçek OAuth ekranı ve mağaza kimlikleri bu yerel testin kapsamında değildir.
