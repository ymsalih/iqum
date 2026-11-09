# IQUM

Android ve iOS için Flutter hafıza oyunu. Türkçe, dikey ekran; petrol yeşili, porselen ve kehribar renkler, aşağıdan yukarıya kıvrılan level yolu ve kodla çalışan üç boyutlu kart/karo animasyonları. Tasarım kararları `docs/DESIGN_REVIEW.md` içindedir.

## Çalışan özellikler

- **Sıra Hafızası:** 6/9/12 kartlı üç tur; görsel cevap paneli, ezber/cevap süreleri ve kişisel rekor.
- **Kart Eşleştirme:** 16 kartlı antrenman; ortak tahta üzerinde sırayla çevrimiçi düello. Eşleşme +1 ve aynı oyuncuda devam; hata veya 15 saniye aşımında sıra değişimi; puan kesilmez.
- **Hafıza Yolu:** 30 sabit level, giderek büyüyen tahta ve kısalan ezber süresi. Dört kalp; yanlış adımda bir kalp kaybı ve aynı leveli baştan deneme; 30 dakikada bir yenilenme.
- **Yerel kayıt:** gerçek SQLite, yarım kalan tek oyunculu oyunları geri yükleme, uygulama kapalıyken can yenileme, rekorlar, ses/titreşim tercihleri.
- **Hesap:** Google/Apple giriş kodu, misafir ilerlemesinin tekrar işlenmeyen aktarımı ve hesaplar arasında ayrı yerel veri alanları.
- **Düello sunucusu:** kodlu oda, rastgele eşleşme, hazır olma, sunucu süreleri, gizli kart yerleşimi, bağlantı kaybı ve tek seferlik puan yazımı. Galibiyet +100, beraberlik +50, mağlubiyet 0.

Üç tek oyunculu oyun ilk açılıştan itibaren giriş ve internet olmadan çalışır. **Canlı Google/Apple girişi ve internet üzerinden düello için Firebase projenizin yapılandırılıp sunucuya dağıtılması gerekir.** Uygulama, yapılandırma yokken örnek kullanıcı veya sahte rakip oluşturmaz.

## Çalıştırma

Flutter 3.41.2 / Dart 3.11 ile geliştirilmiştir. Bağımlılık sürümleri `pubspec.lock` ve `functions/package-lock.json` ile kilitlidir. Android minimum API 24; iOS minimum 15.0.

```sh
flutter pub get
flutter run
```

Canlı servisler için [Firebase kurulum rehberi](docs/FIREBASE_SETUP.md), [App Check cihaz/konsol adımları](docs/APP_CHECK_SETUP.md) ve `config/firebase.example.json` kullanılır:

```sh
flutter run --dart-define-from-file=config/firebase.json
```

Firebase özel hizmet hesabı anahtarlarını veya Apple özel anahtarlarını mobil yapılandırmaya koymayın. Google OAuth istemci kimlikleri, Firebase uygulama kimlikleri ve Android imzaları kullanıcıya ait projeden gelmelidir.

## Android test paketi

```sh
flutter build apk --release --target-platform android-arm64
```

Hazırlanan paket `output/apk/IQUM-test-arm64.apk` altındadır. ARM64 Android telefonlar içindir. Optimize edilmiş Flutter derlemesidir; geliştirme imzasıyla test amaçlı imzalanır ve Firebase yapılandırması olmadan çevrimdışı açılır. Mağaza sürümünde kullanıcıya ait Android imzalama yapılandırması gerekir. iOS derlemesi ve imzalama Mac/Xcode ortamında tamamlanır.

## Doğrulama

```sh
flutter analyze
flutter test
cd functions
npm ci
npm test
cd ..
firebase emulators:exec --project demo-iqum --only auth,firestore,functions "node --test functions/test/emulator.integration.js"
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart -d <android-device-id>
```

Yerel Firebase testleri Java 21+ ve Node 22 kullanır. Android entegrasyon testi ayrı bir test SQLite dosyası oluşturur; uygulamanın normal kayıtlarına dokunmadan üç oyunu oynar, can kaybını/ilerlemeyi ve tekrar açılışta kalıcılığı doğrular. Gerçek Flutter ekran görüntüleri `output/android/` altına alınır. Fiziksel cihazda 60 FPS ölçümü ve gerçek Google/Apple OAuth doğrulaması ayrıca yapılmalıdır; emülatör işlev testleri bunların yerine geçmez.

## Kod yapısı

Etkileşim paketleri, süreler ve Rive dosyası sözleşmesi [hareket notlarında](docs/MOTION.md) açıklanır. `.riv` hayvan dosyaları henüz yoktur; bu durumda özgün PNG çizimleri kullanılır.

- `lib/domain`: saf Dart oyun kuralları, 30 level tanımı ve can cüzdanı.
- `lib/application`: Riverpod, kayıt/hesap kapsamı, idempotent aktarım ve ses/titreşim.
- `lib/data`: SQLite ve gerçek Firebase istemcisi; yapılandırmasız çevrimdışı çalışma.
- `lib/ui`: Flutter ekranları ve yalnızca hareket eden kart/karoyu güncelleyen bileşenler.
- `functions/src`: saf sunucu motoru, ortak `api` çağrı noktası, atomik sonuçlandırma ve Cloud Tasks.
- `firestore.rules`: üyeye özel maç okuma; puan, sıra ve gizli veriye istemci yazma yasağı.
- `assets`: 12 hayvan çizimi, marka görselleri, kısa WAV sesleri ve açık lisanslı Lora/Manrope fontları.

Hayvanların düzenlenebilir vektör kaynağı `design/animals.cjs` içindedir. `node design/build.cjs` ve ardından `node scripts/prepare_assets.cjs` ile önizleme ve Flutter PNG dosyaları yenilenir; bu adım `sharp` paketini gerektirir. `node scripts/preview_animals.cjs`, 12 hayvanı büyük boyutta ve 40 piksel kart boyutunda karşılaştıran `output/artwork/animals-overview.png` görselini oluşturur.

Ürün kararları `docs/PRODUCT_SPEC.md`, ilk geliştirme planı `docs/IMPLEMENTATION.md` içindedir. Onaylanan tasarım kaynakları `design/` altında korunur; `design/index.html` önceki tarayıcı prototipidir, gerçek Flutter uygulaması değildir.
