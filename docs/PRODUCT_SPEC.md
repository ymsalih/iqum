# IQUM ürün kararları

Durum: tasarım onaylandı; Flutter uygulaması ve sunucu kodu geliştirildi. Kullanıcının onayladığı planın kart eşleştirme güncellemesi dahildir.

## Kimlik ve erişim

- IQUM; iki açılmış kartın boşluğundan oluşan Q işareti.
- Güncel premium görsel yön: porselen zemin, petrol yeşili tahtalar/kart arkaları, adaçayı tamamlanan alanlar, kehribar odak ve mercan hata/can rengi. Marka kaynakları ve renkli/tek renk logo güncellendi; kararlar `DESIGN_REVIEW.md` içindedir.
- Level seçimi aşağıdan yukarıya kıvrılan bir yol üzerindeki 30 numaralı duraktan oluşur. Mevcut level ilk açılışta ortalanır; başlık/devam düğmesi sabittir. Tamamlanan duraklar onaylı, sıradaki koyu petrol ve kehribar çerçeveli, ileri leveller kilitlidir. Oyun tahtasında güvenli karo ezberleme kuralları korunur.
- Kartlar 340 ms süren perspektifli yarım dönüşle açılır/kapanır; açılma sırasında hafif yükselir. Buton yayı en fazla 320 ms, adım geri bildirimi 240 ms, puan geçişi 260 ms sürer. Hareketi azaltma ayarında geçişler anında tamamlanır. Ayrıntılar `MOTION.md` içindedir.
- Dikey Android/iOS uygulaması. iOS derleme ve mağaza işlemleri kullanıcıda.
- Üç tek oyunculu oyun misafire ve çevrimdışı kullanıma açık.
- Gerçek rakiplerle düello ve buluta kayıt için Google/Apple hesabı gerekir.
- Android'de yalnızca Google girişi sunulur; iOS'ta Google ve yerel Apple girişi bulunur. Apple seçeneği iOS dışındaki platformlarda hem arayüzde hem giriş katmanında kapalıdır.
- Reklam, alışveriş ve genel sıralama ilk sürümde yoktur.

## Sıra Hafızası

Üç tur; sırasıyla 6/9/12 kart. Ezber süresi 6/8/10 saniye, cevap süresi 30/45/60 saniye. Kartlar soldan sağa ve satır satır hatırlanır; cevap hayvan görseline dokunarak verilir. Hata veya cevap süresinin dolması oyuncunun o turdaki denemesini bitirir. Düelloda aynı dizinin ayrı kopyaları eşzamanlı oynanır. Toplam doğru sayısı, eşitlikte toplam cevaplama süresi karşılaştırılır; ikisi de eşitse beraberliktir. Antrenmanda kişisel performans tutulur.

## Kart Eşleştirme: ortak tahta, sırayla

- 16 kart, sekiz çift; açılan kartları iki oyuncu da görür.
- İlk oyuncuyu sunucu rastgele seçer.
- Hamle iki kartın tamamı için 15 saniyedir. İlk kartı açmak süreyi yenilemez.
- Eşleşme: kartlar açık kalır, bulan oyuncu +1 maç puanı alır, aynı oyuncu yeni hamleyle devam eder.
- Hata: kartlar 900 ms görünür, sonra kapanır; sıra diğer oyuncuya geçer. Puan eksilmez.
- Süre aşımı: tek açık kart kapanır, sıra değişir. Puan eksilmez.
- Sonuç gösterilirken yeni seçim alınmaz. Yeni hamlenin süresi geri bildirim bittiğinde başlar.
- Aynı kart iki kez seçilemez; bulunan çiftler yeniden oynanamaz.
- Sekiz çift tamamlanınca maç biter. Daha çok çift bulan kazanır; 4–4 beraberliktir.
- Antrenmanda rakip/hamle süresi yoktur; tamamlanma süresi ve deneme sayısı rekor olarak tutulur.

## Hafıza Yolu

- Tek oyunculu; her sırada bir güvenli karo ve 30 sabit level.
- Komşu sıralardaki güvenli karolar aynı veya komşu sütundadır. Her sıradan bir karo seçilir; sıra atlanamaz.
- Ön izleme sırasında güvenli karolar görünür, sonra gizlenir. Doğru basılmış karolar açık kalır; çizgi çizilmez.
- Hata bir can götürür ve aynı leveli baştan ezberlemeye döndürür. Başarılı adım/level can harcamaz.
- Başlangıç dört, üst sınır dört can. Eksikse 30 dakikada bir yenilenir. Yeni hata yenilenme başlangıcını sıfırlamaz.
- Sıfır canda level ve ilerleme korunur; kullanıcı diğer antrenmanları oynayabilir.
- Boyutlar: level 1–5: 3×4; 6–10: 3×5; 11–15: 4×5; 16–20: 4×6; 21–25: 5×6; 26–30: 5×8 (sütun × sıra).
- Ön izleme: `max(3, 9 - (level - 1) * 0.2)` saniye. Level 30 yaklaşık 3 saniyedir.
- Yol level kimliğine göre sabittir; uygulamayı yeniden açmak veya tekrar denemek yolu değiştirmez.

## Hesap, aktarım ve puan

- Galibiyet +100, beraberlik +50, mağlubiyet 0 hesap puanı. Çift puanları yalnızca maç skorudur.
- Yerel ilerleme SQLite'ta saklanır; Google/Apple girişinden sonra tek seferlik aktarım kimliğiyle taşınır.
- Yeni hesap yerel kayıtları alır. Mevcut hesapta en ileri level, en iyi rekor ve benzersiz oyun kayıtları korunur.
- İki can durumu aynı zamana yenilendikten sonra düşük olan kullanılır; canlar toplanmaz.
- Aktarım başarısızsa yerel veri silinmez. Tekrar işlem puan/oyun kaydı çoğaltmaz.
- Misafir kayıtları çevrimiçi düello puanı yaratamaz; puan yalnızca sunucuda sonuçlandırılır.
- Giriş iptal edilirse misafir olarak devam edilir. Oturum kapanınca başka hesaba önceki hesabın özel kayıtları aktarılmaz.

## Çevrimiçi oyun

İki kişilik oda, altı karakter kod, 10 dakika bekleme. Oyun türüne göre rastgele eşleşme ve 30 saniyelik arama. İki taraf hazır olduğunda ortak başlangıç zamanı; Sıra Hafızası'nda eşzamanlı başlangıç, Kart Eşleştirme'de tek aktif oyuncu. Bağlantı kopmasında 15 saniye geri dönme süresi, dönmeyene hükmen mağlubiyet. Aynı maçın sonucu bir kez puanlandırılır.

## Hareket ve erişilebilirlik

Kart dönüşü 360 ms; karoya basma 180 ms; hatalı çift gösterimi 900 ms. Sabit sahne, sınırlı gölge ve önbelleğe alınabilir çizimler. Doğru/yanlış yalnızca renkle anlatılmaz; işaret ve metin de kullanılır. Azaltılmış hareket, ses ve titreşim tercihleri desteklenir. Önizleme gerçekçi derinliği kodla örnekler; üretimde cihaz testiyle doğrulanır.
