# Uygulama geliştirme sırası

## 1. Tasarım incelemesi — tamamlandı

- [x] Renkler, tipografi, renkli ve tek renk logo, uygulama simgesi.
- [x] Dokuz ekran ve ilgili durumlar için etkileşimli önizleme.
- [x] Özgün, aynı görsel ailede 12 hayvan çizimi.
- [x] Kart dönüşü, ortak tahta/sıra ve karo basma örnekleri.
- [x] Kullanıcıyla görsel yönü kesinleştirme ("tamam sen kodlamaya başla").

Kullanıcı tasarımın ardından kodlamayı onayladı. Flutter uygulaması, SQLite kaydı, hesap aktarımı ve sunucu kontrollü düello kodu geliştirildi. Doğrulama sonuçları `VERIFICATION.md`, canlı servis bağlantısı `FIREBASE_SETUP.md` içindedir.

## 2. Flutter ve çevrimdışı oyunlar

Android/iOS Flutter projesi; Riverpod, SQLite ve özelliklere ayrılmış yapı. Saf Dart oyun modelleri ve kurallar, ayrı çizim katmanı, kayıt depoları ve saat arayüzü. Ekranlar `design/` kaynaklarına göre geliştirilir. Yerel kayıt sürümlenir; uygulama arka plana geçtiğinde kayıt yapılır. Canlar arka plan zamanlayıcısıyla değil kayıtlı zaman damgasından hesaplanır. Saat geri alınırsa geriye doğru süre kazanımı verilmez.

Doğrulama: üç oyunun saf kural testleri; 30 levelin deterministik ve çözülebilir olması; eksik canın yenilenmesi, üst sınır, arka plana geçiş, tekrar açma, bozuk/eksik yerel kaydın veri kaybetmeden ele alınması. Küçük ekran ve azaltılmış hareket testi.

## 3. Hesap ve kayıt aktarımı

Firebase Auth Google/Apple, Firestore, Cloud Functions; geliştirmede emülatörler. Misafir kayıtları giriş olmadan yerelde kalır. `importProgress(importId, records, progress, lifeState)` oturumlu kullanıcıya bir kez uygulanır. Aktarım onayı gelmeden yerel kaynak silinmez; eski hesap verileri yeni misafir alanına dahil edilmez. Hesap sonuçları ve oyun kayıtları ayrı depolanır; yerel kayıttan düello puanı kabul edilmez.

Doğrulama: yeni/mevcut hesaba giriş, sağlayıcı iptali, kesilen ve yinelenen aktarım, iki hesap arasında geçiş, çevrimdışı devam.

## 4. Sunucu kontrollü düellolar

Arayüzler: `createRoom(gameType)`, `joinRoom(code)`, `findMatch(gameType)`, `setReady(matchId)`, `submitMove(matchId, actionId, move)`, `resumeMatch(matchId)`. İstemci maçın izin verilen görünümüne abone olur. Hamleler kullanıcı, maç üyeliği, sıra, faz, süre ve benzersiz işlem kimliğiyle doğrulanır.

Kart yerleşimi yalnızca sunucunun okuyabildiği kayıtta tutulur. Açılan kart ve skor ortak görünümde paylaşılır. Hamle süresi tek bir sunucu son tarihidir; ilk kart yeni süre üretmez. Geri bildirim/kapanma ve hamle süre aşımı istemciye bağlı olmayan sunucu işleriyle ilerletilir. Sunucu sonuç işlemi atomik ve tekrarlanabilir olur; puan yalnızca bir kez yazılır.

Rastgele eşleşme aynı kullanıcıyı iki maça atamaz; oda üçüncü oyuncuyu kabul etmez. Bekleme süresi dolan odalar başlatılmaz. Bağlantı kopmasında sunucu tarafından takip edilen 15 saniye uygulanır. İki tarafın da kaybolduğu maç iptal edilir ve puan üretmez.

Doğrulama: iki cihazda aynı kartlar, rakip sırası reddi, çift dokunma, eşleşmede devam, hatada kapanma, ilk karttan sonra süre aşımı, tekrar eden hamle/sonuç isteği, beraberlik, oda yarışı ve yeniden bağlanma.

## 5. Cihaz testi ve yayın

Fiziksel orta seviye Android ve kullanıcı ortamında iOS. Profile/release derlemesinde 60 FPS hedefi; UI ve raster kare sürelerinin en az %95'i 16,7 ms altında. Görünmeyen ekranlarda animasyon durdurma, uzun oturum ve bellek kontrolü. Tasarım önizlemesinin testleri bu cihaz ölçümlerinin yerine geçmez.

Gerçek servislerin etkinleştirilmesi için kullanıcıya ait Firebase projesi, Google/Apple sağlayıcı ayarları ve mağaza imzalama bilgileri gerekir. Bu bilgiler kaynak koduna veya tasarım dosyalarına gömülmez. Yayın öncesi uygulama kimlikleri ve servis yapılandırmaları bu hesaplara bağlanır.
