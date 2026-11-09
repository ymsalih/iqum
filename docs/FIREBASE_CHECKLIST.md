# IQUM — Firebase, Google ve Apple kurulum kontrol listesi

Proje: `iqum-4734b`. Android/iOS kimliği: `com.iqum.iqum`.

Güncel karar: Android yalnızca Google ile giriş yapar. iOS Google ve yerel Apple girişi sunar. Android/web Apple desteği bu sürümde yoktur. Web OAuth code flow/domain/Return URL alanları mevcut yerel iOS girişinde zorunlu kurulum adımları değildir. iOS App ID, Sign in with Apple capability, Firebase Apple sağlayıcısı ve iOS Firebase dosyası tamamlanmalıdır. Firestore veritabanı ve kuralları bu listeden sonra geliştirici tarafından kurulmuştur; tekrar oluşturma. Canlı durum `AUTH_STATUS.md` içindedir.

Bu liste konsolda kullanıcı tarafından yapılacak ayarları ve ardından geliştiricinin tamamlayacağı bağlantıları ayırır. Mevcut Android dosyası indirildi ve doğrulandı; henüz Google OAuth istemcisi içermiyor. Canlı sağlayıcı ayarlarının yapıldığı, sunucunun yayımlandığı veya gerçek girişin geçtiği varsayılmaz.

## 1. Google girişini etkinleştir

- Firebase Console'da `iqum-4734b` projesini seç.
- Authentication > Get started > Sign-in method / Sign-in providers bölümünü aç.
- Google sağlayıcısını etkinleştir.
- Uygulamanın görünen adını IQUM, destek e-postasını yönettiğin hesap olarak seç ve kaydet.
- Başka sağlayıcı ekleme; misafir oyunlar yerel çalıştığından Anonymous Auth açılması gerekmez.

## 2. Android imzalarını doğrula ve güncel dosyayı indir

Project settings > General > Your apps > IQUM Android altında paket adı `com.iqum.iqum` olmalı.

Bu bilgisayarın debug sertifikası:

SHA-1:
`7A:EF:2B:A0:FB:9C:2C:5C:90:09:97:05:C7:6F:C5:A1:E3:2D:E5:A7`

SHA-256:
`6C:CC:B1:DF:B8:AC:AB:5A:EB:20:12:29:08:3E:54:3A:C6:9D:36:F9:3E:09:0C:4B:77:C5:64:8D:C0:7E:E5:FC`

- Eksik parmak izini Add fingerprint ile ekle. Aynı değeri ikinci kez ekleme.
- Google etkinleştirildikten sonra `google-services.json` dosyasını yeniden indir. İndirilenler klasöründe kalabilir; geliştirici en yeni dosyayı paket/proje eşleşmesini kontrol ederek alır.
- Mağaza imzası ve Google Play App Signing parmak izleri yayın sırasında ayrıca eklenecek; debug imzası onların yerine geçmez.

Kaynak: https://firebase.google.com/docs/auth/android/google-signin

## 3. iOS uygulamasını Firebase'e ekle

- Project settings > General > Your apps > Add app > iOS.
- Bundle ID: `com.iqum.iqum`.
- Nickname: `IQUM iOS`.
- App Store ID henüz yoksa boş bırak.
- `GoogleService-Info.plist` dosyasını indir; İndirilenler klasöründe tut.
- Firebase SDK'sını Swift/Objective-C kod parçalarını kopyalayarak ayrıca ekleme; Flutter bağımlılıkları ve Xcode proje bağlantısını geliştirici tamamlayacak.
- iOS Google CLIENT_ID / REVERSED_CLIENT_ID ve Android dosyasındaki Web client ID bu dosyalardan alınacak. Android, iOS ve Web OAuth kimlikleri birbirinin yerine kullanılmaz.

## 4. iOS için yerel Apple girişi

Sign in with Apple için Apple Developer Program üyeliği gerekir. Android'de Apple girişi sunulmaz; bu sürüm için web domain/Return URL/Services ID adımları zorunlu değildir.

- Apple Developer > Certificates, Identifiers & Profiles > Identifiers altında mevcut com.iqum.iqum App ID'sini aç veya Explicit App ID olarak oluştur.
- Sign in with Apple yeteneğini etkinleştir ve kaydet.
- Firebase Authentication > Sign-in method > Apple sağlayıcısını etkinleştir ve kaydet. Web/OAuth code flow alanları, yalnızca bu web akışını kullanacaksan ayrıca yapılandırılır.
- iOS Firebase uygulamasını kaydet, güncel GoogleService-Info.plist dosyasını indir.
- Mac/Xcode'da doğru Signing Team, com.iqum.iqum Bundle ID ve Sign in with Apple capability doğrulanır; provisioning yenilenir.
- Mevcut FlutterFire iOS eklentisi Apple'ın yerel ASAuthorizationAppleIDProvider penceresini kullanır. iPhone'da gerçek giriş ve E-postamı gizle seçeneği test edilir.
- Önceden oluşturduğun Services ID/domain kaydının bulunması, Android'de Apple düğmesini açmaz. Gerekirse gelecekteki web entegrasyonu ve hesap silme/token iptali ihtiyaçları ayrıca ele alınır; özel anahtar mobil projeye veya sohbete alınmaz.

Kaynak: https://firebase.google.com/docs/auth/flutter/federated-auth

## 5. Hesap kayıtları için Firestore

- Firebase > Firestore Database > Create database.
- Edition sorulursa Standard; database ID `(default)`.
- Bölge: `europe-west1` (Belgium / Belçika); mevcut sunucu bölgesiyle eşleştir.
- Security Rules başlangıcı Production / Locked mode.
- Test mode ile herkese okuma/yazma açma; projede hazır üyelik/hesap kuralları bulunur ve dağıtımda yayımlanır.
- Koleksiyon veya kullanıcı belgelerini elle oluşturma; sunucu işlemleri bunları oluşturur.

Kaynak: https://firebase.google.com/docs/firestore/quickstart

## 6. Sunucu için faturalandırma

Cloud Functions dağıtımı Blaze planı gerektirir. Bu, mevcut hesap aktarımı/hesap oluşturma sunucu işlemleri için de gereklidir.

- Plan / Usage and billing > Upgrade > Blaze.
- Kullanıcı kendi Cloud Billing hesabını/ödeme bilgilerini bağlar.
- Cloud Billing > Budgets & alerts altında kullanıcıya uygun aylık bütçe ve bildirim eşikleri oluşturur.
- Bildirim bütçesi harcamayı otomatik durdurmaz; kullanım ücret oluşturabilir.

Kaynaklar:
https://firebase.google.com/docs/functions/get-started
https://docs.cloud.google.com/billing/docs/how-to/budgets

## 7. Geliştiricinin tamamlayacağı bağlantı ve dağıtım

Konsol adımları bittikten sonra:

- Yeni `google-services.json` ve `GoogleService-Info.plist` içinden platform ayarlarını doğrula/aktar.
- Android Google Services plugin, iOS plist hedef üyeliği, Google URL scheme ve FirebaseOptions alanlarını tamamla.
- CLI'da kullanıcı kendi Google hesabıyla Firebase login yapar. Parola/token sohbet üzerinden alınmaz.
- Node 22 ile mevcut sunucu testlerini çalıştır ve `iqum-4734b` hedefine Firestore rules/indexes ile Cloud Functions'ı dağıt.
- Functions / Firestore trigger / Cloud Tasks API ve servis hesabı yetkilerini dağıtımdaki gerçek kimliklerle doğrula; görev ekleme/çağırma yetkilerini doğru kimliğe ver. Görev fonksiyonunu genel erişime açma.
- Bölgeler `europe-west1`, emülatör bayrağı false olmalı.
- İptal, tekrar giriş, misafir aktarımı, aynı/mevcut hesap ve canlı profile yazma testlerini yap.
- Mac/Xcode'da Runner bundle ID ve Signing Team'i doğrula, Sign in with Apple capability/provisioning'i tamamla. iOS Google yönlendirmesini doğrula.
- iPhone'da Apple 'E-postamı gizle' seçeneğiyle ve Google ile gerçek giriş testi yap.
- Kullanıcı APK/iOS derlemesi istemedikçe paket oluşturma.

Google/Apple giriş ekranının açılması tek başına bitiş kriteri değildir: Authentication > Users'da gerçek sağlayıcı ve UID, uygulamada aynı hesaba yeniden giriş, Firestore profil kaydı ve yinelenmeyen misafir aktarımı doğrulanmalıdır.
