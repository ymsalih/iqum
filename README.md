# IQUM

Android ve iOS için Flutter hafıza oyunu. Türkçe, dikey ekran; "masa oyunu" görünümü: porselen zemin, petrol yeşili keçe tahtalar, ölçülü kehribar vurgu ve alt kenarı (dudak) olan dokunsal parçalar. Aşağıdan yukarıya kıvrılan level yolu, perspektifli kart çevirme ve Rive ile canlanan 12 özgün hayvan. Telefon (320 dp'den itibaren), tablet ve 1,3× yazı ölçeği için responsive.

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

### Tasarım sistemi

- `lib/ui/theme.dart`: renk/tipografi belirteçleri. Başlıklar Baloo 2 (600/800), metinler Nunito (500/700/800); fontlar Latin + Türkçe karakterlere alt kümelenmiş statik dosyalardır.
- `lib/ui/components.dart`: `Piece` (dudaklı yüzey), `IqumButton` (basınca dudağa gömülen tuş), `MemoryTile` (perspektifli çevirme, eşleşmede zıplama, hatada sallanma), `PathTile`, `ClockStrip`, `StatPill`, `AnimalChoice`.
- `lib/ui/responsive.dart`: `AppFrame` yazı ölçeğini 1,3× ile sınırlar; 640 dp'den geniş ekranlarda oyunu ortalanmış dikey sütunda gösterir. `FitBoard` oyun tahtalarını görünür yüksekliğe sığdırır.
- Performans: gölgeler bulanıksız dudaklardır; blur, shader, `Opacity` katmanı veya sürekli animasyon yoktur. Yol haritası tek seferlik `CustomPainter`, kart sırtı küçültülmüş tek PNG'dir.

### Rive hayvanları

`assets/art/<hayvan>.riv` dosyaları `node design/rive/build_animals.cjs` ile özgün vektör çizimlerden (`design/animals.cjs`) üretilir; parçalar ve hareketler `design/rive/animal_rigs.cjs` içindedir. Her dosyada varsayılan state machine vardır: giriş → `reveal` (kart açılınca ~0,57 sn), `match` tetikleyicisi → `celebrate` (eşleşme/doğru cevap). İkisi de tek seferliktir; klip bitince Rive kare üretmez ve `AnimalArt` denetleyiciyi kapatır. Rive çalışamazsa veya hareketi azaltma açıksa aynı çizimin PNG'si gösterilir. `test/rive_art_test.dart` dosyaları gerçek Rive çalışma zamanıyla doğrular (masaüstü kütüphanesi için bir kez `dart run rive_native:setup --platform windows`).

- `lib/domain`: saf Dart oyun kuralları, 30 level tanımı ve can cüzdanı.
- `lib/application`: Riverpod, kayıt/hesap kapsamı, idempotent aktarım ve ses/titreşim.
- `lib/data`: SQLite ve gerçek Firebase istemcisi; yapılandırmasız çevrimdışı çalışma.
- `lib/ui`: Flutter ekranları ve yalnızca hareket eden kart/karoyu güncelleyen bileşenler.
- `functions/src`: saf sunucu motoru, ortak `api` çağrı noktası, atomik sonuçlandırma ve Cloud Tasks.
- `firestore.rules`: üyeye özel maç okuma; puan, sıra ve gizli veriye istemci yazma yasağı.
- `assets`: 12 hayvan çizimi (PNG + Rive), marka görselleri, kısa WAV sesleri ve açık lisanslı Baloo 2/Nunito fontları.

Hayvanların düzenlenebilir vektör kaynağı `design/animals.cjs` içindedir. `node design/build.cjs` ve ardından `node scripts/prepare_assets.cjs` ile önizleme ve Flutter PNG dosyaları yenilenir; bu adım `sharp` paketini gerektirir. Logo, uygulama/mağaza ikonları, kart sırtı ve tanıtım grafiği `node design/brand/build_brand.cjs` (`sharp` + `opentype.js`), ses efektleri `node design/sound/build_sounds.cjs` ile üretilir. `node scripts/preview_animals.cjs`, 12 hayvanı büyük boyutta ve 40 piksel kart boyutunda karşılaştıran `output/artwork/animals-overview.png` görselini oluşturur.

Ürün kararları `docs/PRODUCT_SPEC.md`, ilk geliştirme planı `docs/IMPLEMENTATION.md` içindedir. Onaylanan tasarım kaynakları `design/` altında korunur; `design/index.html` önceki tarayıcı prototipidir, gerçek Flutter uygulaması değildir.
