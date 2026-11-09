# IQUM doğrulama kaydı

## 9 Kasım 2026 — mağaza hazırlığı, hesap silme ve yasal merkez

Uygulamaya girişsiz yasal merkez, açık koşul kabulü, Google/yerel Apple yeniden doğrulaması, Apple revoke çağrısı, kalıcı silme onayı ve durum ekranı eklendi. SQLite v2 hedefli temizleme ve v1 yükseltmesi doğrulandı: güncel misafir/kullanıcı kayıtları ve bekleyen aktarım paketleri korunur; artık erişilmeyen eski misafir kopyaları temizlenir. İstek belirsizliği, iptal, native çıkış hatası, yeniden açma ve çevrimdışı durum tamamlandı diye gösterilmez.

Geçen kontroller:

| Kontrol | Sonuç / kapsam |
| --- | --- |
| Flutter testleri | **63 geçti**; auth/reauth, Apple revoke sırası (taklit SDK), veri izolasyonu, silme kurtarma, SQLite yükseltmesi, 320/390 px yasal/onay ekranları ve mevcut oyun regresyonları |
| Flutter analiz | **Temiz**, no issues found |
| Node sunucu kuralları | **18 geçti**; son auth_time, güvenli makbuz, kimliksiz sonuç ve erken temizlik engeli dahil |
| Firebase yerel entegrasyon | **9 geçti**; gerçek emülatör Auth kaydı/alt koleksiyon silme, eski JWT/Firestore erişim engeli, aktif maçta rakip ödülü, tekrar istek, yetkisiz makbuz, yarım temizlik devamı, koşul sürümü ve önceki oyun testleri |
| Web/operatör araçları | **4 geçti**; eksik kimlikle yayın engeli, HTML kaçışları, doğru mailto/sahte gönderim olmaması ve doğrulanmamış operatör silme komutunun servis çağrısından önce reddi |
| Web tarayıcı | **15 geçti**; beş sayfa × 320/390/820 px, taşma, yerel bağlantılar ve JS hataları; ekran görüntüleri ayrıca incelendi |
| Python iOS yardımcıları | **6 geçti**; mevcut Firebase yapılandırması ve yeni archive manifest envanter aracının temsili dosya testleri |
| Mağaza varlıkları | **22 geçti**; 19 iOS simgesi + üç mağaza görselinin boyut/opaklığı, yerel font yüklemesi; alfa kaldırıldı, logo korunuyor |
| Android Gradle | Yapılandırma/görev listesi başarılı. bundleRelease --dry-run eksik upload anahtarı nedeniyle beklenen IQUM kilidiyle durdu. APK/AAB oluşturulmadı |
| Canlı API erişimi | **7 geçti**; saat 200, girişsiz profil/silme/kabul 401, geçersiz makbuz yalnız unknown/zaman, iki görev ucu 403 |

Yerel emülatör otomatik paralel çalışan modunda bu bilgisayardaki Node işçi çoğalması/soğuk başlangıçlar heartbeat'i 15 saniyeden fazla geciktirip bir oyun regresyonunu kararsız yaptı. İşlevsel koşum, Firebase --inspect-functions ile tek yerel çalışan kullanacak şekilde düzenlendi ve dokuz test birlikte geçti. Gerçek oyun süreleri/üretim eşzamanlılığı değiştirilmedi. Bu koşum üretim yükü, gecikmesi veya eşzamanlı yarışların yük testi değildir. Sunucu Node 22, bu bilgisayardaki emülatör Node 24 ile çalışır.

Yayın: api, advanceMatchTask ve enqueueMatchJob güncellendi; eraseAccountTask ve enqueueAccountDeletion oluşturuldu; Firestore kuralları/indexleri başarıyla yayımlandı. App Check zorunlu modu açılmadı. Canlı salt okunur testte hiçbir gerçek kullanıcı hesabı/oyun/profil oluşturulmadı veya silinmedi. Canlı gerçek hesap silme ve görev yürütmesi bu smoke testle kanıtlanmış sayılmaz.

Salt okunur altyapı denetimi: Cloud Logging _Default 30 gün; _Required 400 gün/kilitli; iki varsayılan sink; Firestore europe-west1, PITR kapalı, yedek zamanlaması yok. Bu bilgiler gizlilik metnine işlendi. Sağlayıcının tüm dahili kopyalarına ilişkin anlık fiziksel silme iddiası yoktur.

Beklenen başarısız yayın kapısı: store_preflight exit 1. Gerçek legalName/supportEmail/contactAddress/publicOrigin/targetAudience, published durumu, üretim web çıktısı ve Android upload anahtarı eksik. Bu sonuç işlevsel test hatası değil; eksik kimlik/iletişimle mağaza sürümü hazırlamayı önleyen kontroldür. Web sürümü taslak olarak kaldı; kullanıcı daha sonra yayımlayacak.

Doğrulanmamış olanlar: gerçek Google/Apple sağlayıcısı ve Apple erişim iptali; TestFlight/iPhone native akışı, ertelenen App Attest; Play Integrity; final iOS archive SDK privacy/required-reason raporu; final AAB birleşik izin/16 KB uyumluluğu; gerçek iki istemci düellosu ve fiziksel cihaz performansı; yayımlanmış HTTPS URL'leri ve mağaza formlarının gönderimi. Gradle 8'in mevcut Kotlin/Gradle kullanımları için deprecation uyarıları var; Gradle 9 uyumluluğu bu çalışmanın doğrulaması değildir.

Raporlar output/store-*.log ve JSON dosyalarında; web ekranları output/legal-*.png. Üretilecek paket veya site yayını yapılmadı. Belgeler ve son kullanıcı adımları STORE_READINESS.md, STORE_DATA_DISCLOSURE.md, SUPPORT_OPERATIONS.md, CI_STORE_CHECKS.md ve STORE_LISTING_TR.md içinde.


## 9 Kasım 2026 — Android emülatörü ile canlı App Check

Kullanıcının istediği USB'siz kontrol için Pixel 6 / Android API 36 x86_64 emülatöründe tek bir debug entegrasyon derlemesi çalıştırıldı. Android native Firebase App Check SDK'sı geçici kayıtlı debug sağlayıcısıyla canlı `iqum-4734b` projesinden token aldı; tokenın uygulama kimliği Android Firebase app ID ile eşleşti. Native Cloud Functions SDK'sından canlı `getServerTime` çağrısı başarılı oldu. Canlı Cloud Run/Functions günlüğünde aynı çağrı `app: VALID` olarak doğrulandı: `2026-11-09T10:46:08.263357Z`, yanıt zamanı `1794221168265` ms. Sonuçlar token içermeyen `output/app-check-native-result.json` ve `output/app-check-native-server-result.json` dosyalarında saklandı.

46 Flutter testi ve Flutter analizi bu ek test kaynaklarıyla tekrar geçti. Native test geçti; kullanıcı/profil/oyun/oda/puan kaydı oluşturulmadı. Geçici debug kaydı ve özel tanım dosyası test sonunda kaldırıldı; testin gizli anahtarı kaynaklara veya mağaza yapılandırmasına eklenmedi. Salt okunur AVD kullanıldı, test emülatörü kontrol sonunda kapatıldı. Derlemenin düşük bellekli geçici Gradle ayarları geri yüklendi.

Bu, Android debug App Check'in gerçek mobil SDK → canlı Firebase → sunucu doğrulaması zincirini kanıtlar. Gerçek Play Integrity, gerçek iPhone App Attest, Google/Apple OAuth veya iki cihaz düellosu bu testle doğrulanmış sayılmaz. Üretim App Check enforcement izleme modunda/kapalı kalır. iOS Codemagic ile derlenir; gerçek App Attest testi daha sonra TestFlight üzerinden yapılabilir. Bu test APK'sı ana oyunun dağıtım paketi değildir. Ayrıntılar `NATIVE_APP_CHECK_TEST.md` içindedir.

Tarih: 8 Kasım 2026. Flutter 3.41.2 / Dart 3.11.0, Windows geliştirme ortamı.

## App Check hazırlığı

API canlıya **izleme modunda** yayımlandı; ACTIVE durumu, enforcement=false ve iki yerel mobil uygulamanın sunucu izin listesinde olması doğrulandı. Canlı saat 200, kimliksiz profil 401, genel görev çağrısı 403 kontrolleri geçti. Firebase iOS Team ID eklendi ve tekrar okunarak doğrulandı. Gerçek cihaz attestation ve enforcement açılışı bekleniyor; izleme modu hileye karşı tamamen etkin App Check anlamına gelmez.

46 Flutter testi, 14 sunucu kural testi ve altı zorunlu-mod Firebase entegrasyon testi geçti; Flutter analizi temiz. Release/profile için debug sağlayıcı engeli, açıkça seçilen geliştirme sağlayıcısı, otomatik token yenileme ve aktivasyon hatasında sessizce korumasız devam etmeme doğrulandı. Emülatörde App Check eksik/bozuk/yabancı uygulama kimliği isteklerinin reddi; izinli Android/iOS kimlikleri ve mevcut ortak tahta, 15 saniye, aktarım/puan kontrolleri geçti. Emülatör kriptografik Play Integrity/App Attest doğrulaması yapmaz; gerçek cihaz kanıtı bekleniyor. İlk paralel test denemesinde geliştirme bilgisayarında bellek tükendi; Java emülatörü 512 MB/iki işlemci sınırıyla, analiz ayrı çalıştırılarak başarılı tekrar tamamlandı. Eski üretilmiş `build/app/intermediates` önbelleği temizlendi; APK çıktıları korunur. APK/iOS paketi oluşturulmadı.

## Sunucu saati ve manipülasyon kontrolleri

42 Flutter testi ve 12 sunucu kural testi geçti; Flutter analizi temiz. Beş Firebase entegrasyon testi geçti; yeni senaryolar sahte tarih/skor/son tarih isteklerini, kimliksiz saat okumasını ve kimliksiz profil erişiminin engellenmesini doğrular. Ortak tahta, gerçek 15 saniye aşımı, gizli veri erişimi ve tek seferlik sonuç kontrolleri de geçti. Yeni saat testleri ileri/geri telefon tarihi, gerçek geçen süre, sunucu düzeltmesi, ağ gecikmesi ve gecikmiş yanıtın daha yeni saati bozmamasını doğrular. Başlangıçta can kaydı okunmadan önce sunucu saatinin alınması ayrıca test edildi. Gelecekte kaydedilmiş can verisi ve geçersiz yenilenme tarihi sunucu saatine can eklemeden uyarlanır. Sunucu testleri geçmiş/gelecek istemci tarihleriyle can kazanılmadığını, mevcut yenilenme süresinin yeniden başlamadığını ve aktarımla düello puanı üretilemediğini doğrular. Üç fonksiyon güncellenerek canlıya yayımlandı; canlı saat okuması 200, sahte tarih girdisini yok sayma, kimliksiz profil 401 ve genel görev çağrısı 403 kontrolleri geçti. Güvenlik kapsamı ve tamamen çevrimdışı zaman doğrulamasının sınırı `SECURITY.md` içindedir. APK/iOS paketi oluşturulmadı.

## Google hesap bağlantısı

37 Flutter testi geçti; Flutter analizi temiz. Android yalnızca Google, iOS Google ve Apple seçenekleri ve Android Apple akışı engeli doğrulandı. Google Services kaynak üretme görevi APK oluşturmadan başarıyla çalıştı; üretilen Android app ID ve Web OAuth ID yapılandırmayla eşleşti. Auth testleri token aktarımı, iptal ve çıkışı doğrular. iOS Firebase aktarımı için üç Python testi geçti: tekrar çalıştırma, diğer URL şemalarını koruma ve hatalı proje/bundle/Google şemasını yazmadan reddetme. Firestore canlı kuralları ve üç Cloud Functions fonksiyonu yayımlandı. Canlı hesap API'si kimliksiz çağrıyı 401, görev fonksiyonu genel erişimi 403 ile reddetti. Gerçek Google/Apple OAuth girişleri cihazda test edilmedi. Ayrıntılar `AUTH_STATUS.md` içindedir.

## Güncel kaynak revizyonu — premium etkileşimler

28 Flutter testi geçti; `flutter analyze` temiz. Önceki 25 kontrol korunur; ek testler yayla basılan butonda tek çağrı ve busy kilidi, azaltılmış hareketle gerçek puanın görünmesi, kutlamanın durup boşta kare planlamaması davranışlarını doğrular. Oyun motoru/ağ kuralları değiştirilmedi. Rive `.riv` dosyaları yoktur; mevcut PNG ile güvenli çalışma test edildi, gerçek Rive state machine/render ve fiziksel cihaz FPS ölçümü yapılmadı. APK/iOS derlenmedi. Uygulama ayrıntıları ve paket sürümleri `MOTION.md` içindedir.

## Önceki kaynak revizyonu — premium yol ve marka

25 Flutter testi geçti; Flutter analizi temiz. Aşağıdan yukarıya sıra, mevcut levelin 1/7/30 durumlarında ilk açılışta görünmesi ve boşta animasyon karesi planlanmaması test edildi. Yeni marka PNG dosyaları üretildi; önizleme ekranları kontrol edildi. Bu revizyon için APK/iOS derlenmedi. Tasarım ayrıntıları `DESIGN_REVIEW.md` içindedir.

## Önceki paket: 1.0.1+2

Kullanıcının canlı renk ve kıvrılan level yolu isteği uygulandı. Level seçimi 30 duraklı bir yol olarak çizilir; oyun içindeki güvenli karo ve kalp kuralları değişmedi. Kartlar ilk ezber gösterimi dahil 520 ms perspektifli dönüş ve hafif yükselme kullanır. Hareketi azaltma tercihi desteklenir. Yol sabit CustomPainter ile çizilir, boşta çalışan animasyon yoktur.

22 Flutter testi geçti: önceki oyun/kayıt testleri, 320/390 piksel level haritası/kilit kontrolü ve normal/azaltılmış hareket kart dönüşü doğrulaması. `flutter analyze` temiz. Güncellenen dokuz ekranlık önizlemenin etkileşim kontrolleri de geçti. Fiziksel cihaz FPS veya yeni iOS derlemesi ölçülmedi.

## İlk sürümde geçen kontroller

- `flutter analyze`: sorun bulunmadı.
- `flutter test`: 20 test geçti. Can yenilenmesi/geri alınan saat, 30 levelin süre ve yol kuralları, üç oyun motoru, SQLite kalıcılığı, bozuk kaydı koruma, yinelenmeyen oyun kayıtları, giriş iptali, misafir aktarımı, hesaplar arası yalıtım ve 320/390 piksel ekranlar.
- `node --test functions/test/engine.test.js`: 11 sunucu kural testi geçti.
- Firebase Auth/Firestore/Functions/Cloud Tasks emülatörlerinde dört entegrasyon testi geçti. Ortak tahta, ilk kartta sürenin yenilenmemesi, gerçek 15 saniyelik sıra aşımı, eşleşmede devam, hatada sıra değişimi, görünür kartlar, üyelik ve gizli veri erişim kuralları, iki kişilik oda, eşleşme yarışları, yinelenen hamle/kayıt/sonuç ve bağlantı kaybı doğrulandı.
- Android API 36 / Pixel 6 x86_64 emülatöründe gerçek Flutter entegrasyonu geçti. Üç oyun oynandı; yanlış adımda tek kalp kaybı, level açılması, antrenman sonucu, sıfır hesap puanı ve SQLite yeniden açıldığında verilerin korunması doğrulandı. Ekran görüntüleri `output/android/` altındadır.
- Optimize edilmiş ARM64 Android APK derlemesi oluşturuldu. Test imzası kullanır; canlı Firebase bilgisi içermez.

Hayvan görselleri kullanıcı geri bildirimiyle yeniden çizildi: 12 renkli vektör, belirgin siluetler, gözler ve dış çizgiler. 40 piksel kart boyutundaki görünümleri `output/artwork/animals-overview.png` üzerinden gözle kontrol edildi. Flutter kartlarında görsel alanı büyütüldü; uygulama bu çizimleri önceden oluşturulmuş PNG dosyalarından gösterir.

Bu değişiklikten sonra 20 Flutter testi ve `flutter analyze` yeniden geçti; güncel ARM64 APK oluşturuldu. APK içindeki 12 PNG'nin kaynak görsellerle birebir aynı olduğu doğrulandı. `output/android/` ilk cihaz entegrasyonunun, önceki çizimlerle alınan ekran görüntülerini içerir; güncel çizim örnekleri `output/artwork/` ve `design/screens/` altındadır.

Sunucu yerel testleri Node 24.13.1 üzerinde çalıştırıldı; dağıtım hedefi Node 22'dir. Kod, paketlerin Node 22 desteğiyle sınırlıdır. Geçişli paketler yamalı sürümlere sabitlenmiştir.

## Harici kurulum ve cihaz gerektirenler

- Canlı Firebase yapılandırıldı ve sunucu dağıtıldı. Gerçek Google/Apple hesap seçimi, Authentication kullanıcısı oluşması ve misafir aktarımı fiziksel cihazda doğrulanmadı.
- iOS kaynakları, iOS 15 hedefi, ikonlar ve Apple giriş yetkisi hazırlandı. Windows'ta Xcode derlemesi veya iPhone testi yapılmadı.
- Fiziksel orta seviye telefonda profile/release 60 FPS ölçümü yapılmadı. Yazılım GPU'su kullanan emülatörün debug işlev testleri bu ölçümün yerine geçmez.
- Reklam ve genel sıralama, onaylanan ilk sürüm kapsamı dışındadır.

Tekrar çalıştırma komutları README ve `docs/FIREBASE_SETUP.md` içindedir.
