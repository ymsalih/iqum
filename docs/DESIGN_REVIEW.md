# IQUM — tasarım revizyonu

8 Kasım 2026. Kullanıcının premium görünüm ve aşağıdan yukarıya level sırası geri bildirimi uygulandı.

## Görsel yön

Petrol yeşili ana kimlik, porselen yüzey, adaçayı tamamlanmış alanlar, kehribar mevcut odak ve mercan hata/can rengi. Lora başlıklarda, Manrope açıklama ve sayılarda kullanılır. Arayüzün tamamında aynı renkler korunur; hayvan çizimleri ayırt edilebilir doğal renklerini korur.

Level seçiminde iri yıldızlar, yüksek ekstrüzyon ve gökkuşağı geçişleri kaldırıldı. Numara her durumda görünür; kilit ve onay ek işaretleriyle durum sadece renge bağlı kalmaz. Yolun çizgisi hafif, aktif durak koyu ve ince kehribar çerçevelidir. Başlık ve devam düğmesi sabittir; yalnızca yol kayar. İlk level en alttadır, 30 en üsttedir. Mevcut durak ilk açılışta görünür ve kaydırma alanına ortalanır. Bölümler Odak, Ritim ve Ustalık olarak sakin tipografik etiketlerle ayrılır.

## Marka

İki kartın geometrisinden Q işareti yeniden çizildi. Temiz negatif boşluk, tek kalınlıkta arka kart çizgisi ve kehribar Q kuyruğu kullanılır. Renkli/tek renk logo, koyu kartlar için açık renk simge, Android/iOS ikon kaynakları güncellendi. Tüm çizimler özgün ve düzenlenebilir vektördür; harici logo veya tasarım reposu kopyalanmadı.

## Hareket ve maliyet

Kartların yarım dönüşü 340 ms'dir; açılışta hafif yükselir. Sistem hareketi azaltma tercihiyle anında tamamlanır. Level yolunda ticker, parçacık, sürekli parıltı veya yoğun blur yoktur. Yol statik CustomPainter ile ayrı RepaintBoundary içinde çizilir; scroll dışındaki gereksiz yeniden çizimlerden korunur. İkonlar ve hayvanlar önceden PNG olarak oluşturulur. Yeni etkileşimler ve Rive dosyası gereksinimi `MOTION.md` içindedir. Bunlar tasarım/uygulama tercihidir; fiziksel cihazda FPS sonucu ölçülmüş değildir.

Hareket referansı: [Material Motion](https://m3.material.io/styles/motion). Buradan yön ve etkileşim geri bildirimi ilkeleri incelendi; ek animasyon paketi veya bağımlılık eklenmedi.

## Doğrulama

25 Flutter testi geçti. Yeni testler level 1/7/30 için mevcut durağın küçük ekranda görünmesini, 2'nin 1'in üstünde bulunmasını, seçimi, ileri level kilidini ve boşta animasyon karesi planlanmamasını doğrular. 320/390 piksel ekran ve hareketi azaltma kontrolleri korunur. Flutter analizi temizdir. Önizlemenin dokuz ekran ve oyun akışı kontrolleri geçti. APK/iOS derlenmedi; kullanıcı isteğiyle yalnızca test ve analiz çalıştırıldı. Önceden oluşturulmuş APK dosyaları bu revizyondan önceye aittir.
