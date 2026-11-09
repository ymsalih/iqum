# IQUM etkileşim ve hareket katmanı

Oyun motorları, kayıt şeması, hamle doğrulaması, düello süreleri ve kalp tüketimi değiştirilmedi. Yeni davranışlar UI katmanında çalışır; animasyon tamamlanması hiçbir hamlenin işlenme koşulu değildir.

## Paketler ve gerçek kullanım

- `flutter_animate 4.5.2`: yanlış karoda 240 ms sarsılma/kırmızı vurgu; doğru karoda 240 ms yeşil dalga ve küçük ölçek geçişi.
- `animated_flip_counter 0.3.4`: düello skorları, antrenman doğru/çift sayıları ve profil sayıları. Değer daima oyun/hesap modelinden gelir; sadece rakam geçişi 260 ms sürer.
- `flutter_bounceable 1.2.0`: kart dokunuşu; callback bekletilmeden çağrılır. Basma 100, geri dönüş 180 ms. Eşleşmiş/rakip sırasındaki kartların callback kilidi korunur.
- Butonlarda Flutter `SpringSimulation`: basma 70 ms, gerçek mevcut ölçek/hızdan yayla geri dönüş en çok 320 ms. Native FilledButton, klavye, semantik ve disabled/busy davranışı korunur. Tek dokunuş tek işlem üretir.
- `confetti 0.8.0`: tek oyunculu tamamlanma veya düello galibiyetinde küçük bir kutlama. Kısa emisyon, 6 parçacıklı küçük gruplar, en fazla 900 ms görünürlük. Sonra widget kaldırılır; beraberlik/mağlubiyet ve ekran geri dönüşlerinde tekrar etmez.
- `google_fonts 8.0.2`: mevcut Dart 3.11 ile uyumludur; güncel 9 sürümü Dart 3.13 istediği için seçilmedi. Lora ve Manrope, paket içine alınan Regular dosyalarından yüklenir; runtime HTTP font indirme kapalıdır. Lisanslar mevcut OFL dosyalarındadır.
- `rive 0.14.11`: yerel hayvan dosyası varsa varsayılan artboard/state machine oynatılır. Yükleme yalnızca görünür, açık kartta ve azaltılmış hareket kapalıyken yapılır. 360 ms sonra controller durur; ekran gizlenmesi/uygulamanın arka plana geçişi ve dispose kaynakları durdurur. Dosya yoksa/hatalıysa mevcut PNG korunur.

## Rive dosyalarının durumu

Projede henüz `.riv` hayvan animasyonları yoktur. Mevcut hayvan çizimleri özgün SVG/PNG olarak korunur; bunları Rive'a dönüştürdüğümüz iddia edilmez. Yeni animasyonlar Rive Editor'da hazırlanıp `assets/art/kedi.riv`, `kus.riv` vb. anahtarlarla eklenmelidir. Dosyanın varsayılan artboard'u ve varsayılan state machine'i olmalıdır; kısa açılış hareketi giriş durumundan başlamalı, son pozu 360 ms içinde almalıdır. Girişler/sonuçlar gibi oyun kuralları Rive'dan kontrol edilmez. Henüz gerçek `.riv` dosyasıyla render/state machine veya fiziksel cihaz performansı doğrulanmadı.

Rive'ın her varlıkta Lottie'den daha hızlı olduğu varsayılmadı. Dosyanın karmaşıklığı, renderer ve cihaz ölçülmeden CPU/FPS garantisi verilemez.

## Ses, titreşim ve erişilebilirlik

Doğru/açma hareketinde `lightImpact`, hatada `heavyImpact` kullanılır. Mevcut kısa WAV sesleri korunur. Ses ve titreşim, kullanıcının mevcut ayarlarıyla ayrı ayrı kapatılabilir. Bunlar disk yazma veya hamle sonucunu bekletmez. Azaltılmış harekette shake/dalga, yay, sayaç geçişi, Rive ve konfeti devre dışı kalır; doğru/yanlış renkleri ve gerçek sayılar korunur. Görünmeyen ana sekmeler TickerMode ile durdurulur.

Kart dönüşü 340 ms'dir. Kısa kutlamanın 900 ms yaşam süresi dışında UI hareketleri 400 ms altındadır. Sürekli parıltı, shader, yoğun blur veya döngü eklenmedi. Tarayıcı önizlemesi aynı his için CSS/Web Animations kullanır; Flutter paketlerini çalıştırmaz.

Kaynaklar: [Flutter Animate](https://pub.dev/packages/flutter_animate), [Rive Flutter](https://rive.app/docs/runtimes/flutter/flutter), [Google Fonts](https://pub.dev/packages/google_fonts), [Flip Counter](https://pub.dev/packages/animated_flip_counter), [Bounceable](https://pub.dev/packages/flutter_bounceable), [Confetti](https://pub.dev/packages/confetti).
