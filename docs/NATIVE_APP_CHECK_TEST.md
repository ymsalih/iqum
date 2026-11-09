# Android emülatöründe canlı App Check testi

Bu test Firebase hizmet emülatörü yerine **Android emülatöründe gerçek mobil SDK'yı** ve `iqum-4734b` canlı Firebase projesini kullanır. Gerçek Play Integrity/App Attest yerine yalnız geliştirme için izin verilen debug sağlayıcısı kullanılır.

## Sınırlar

- Kullanıcı, profil, oyun kaydı, oda veya puan oluşturmaz. Native SDK token alımı ve herkese açık sunucu saati çağrısı yapılır.
- Firebase CLI'ın mevcut yetkili oturumuyla yalnızca bu test için geçici Android debug kimliği oluşturulur. Test bitince aynı kayıt silinir.
- Test anahtarı yalnızca git dışında tutulan `output/app-check-live-defines.json` ve debug test derlemesinde bulunur. Kaynak veya mağaza yapılandırmasına eklenmez; sohbet çıktısında gösterilmez.
- Gerçek Play Integrity, Apple App Attest, Google/Apple OAuth ve iki gerçek cihaz düellosu doğrulanmış sayılmaz.
- Canlı App Check enforcement bu test için değiştirilmez; izleme modu korunur.

## Tekrar çalıştırma

1. `node scripts/app_check_live_test.cjs prepare`: özel test tanımlarını ve geçici Firebase debug kaydını hazırlar.
2. `scripts/build_app_check_debug.ps1`: x64 debug entegrasyon uygulamasını derler. Geçici düşük bellekli Gradle ayarlarını işlem sonunda geri yükler. Bu APK ana oyun veya mağaza dağıtımı için kullanılmaz.
3. Android emülatörünü başlat. Paylaşılan bir AVD'de kullanıcı verilerini korumak için salt okunur mod kullanılabilir.
4. `flutter drive` ile `test_driver/app_check_driver.dart` sürücüsü ve önceden derlenmiş test APK'sı çalıştırılır. Cihaz kimliği açıkça seçilir. Test tanımları `output/app-check-live-defines.json` içinden alınır.
5. `node scripts/app_check_live_test.cjs verify`: testin başlangıcından sonraki canlı API günlüklerinde SDK'nın `app: VALID` doğrulamasını arar. Günlük aktarımı henüz tamamlanmadıysa kısa süre sonra tekrar okunabilir.
6. Başarı veya hata durumunda `node scripts/app_check_live_test.cjs cleanup` çalıştırılır. Sadece bu teste ait debug kaydını ve özel tanım dosyasını kaldırır; test günlüklerindeki anahtarı maskeler. Daha önce verilmiş kısa ömürlü tokenlar normal süreleri dolana kadar geçerli olabilir; kayıt silinmesi yeni token alımını engeller.

Sonuçlar `output/app-check-native-result.json` ve `output/app-check-native-server-result.json` dosyalarına gizli token içermeden yazılır. Geçen/eksik doğrulamalar `VERIFICATION.md` içinde kaydedilir.

## iOS / Codemagic

Yerel Mac veya USB bağlantısı gerekmez. Codemagic, projedeki `production` App Attest entitlements ve bunları içeren imzalama profiliyle iOS derlemesini oluşturabilir. Ancak başarılı derleme tek başına App Attest'in gerçek cihazda çalıştığını göstermez. Sonraki aşamada TestFlight üzerinden gerçek iPhone'a yükleyip Firebase'deki doğrulanmış istekler kontrol edilir.
