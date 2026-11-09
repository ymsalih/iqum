# IQUM — sunucu otoritesi ve saat sınırları

8 Kasım 2026.

## Canlı fonksiyonlar

- `api`: Firebase kimliğinden oyuncuyu belirler; hesap/aktarımı, oda/eşleştirme, hazır olma, hamle ve yeniden bağlanma işlemlerini yönetir. `getServerTime` yalnızca sunucu zamanını döndüren herkese açık bir okuma işlemidir; profil ve maç işlemleri oturum ister.
- `enqueueMatchJob`: sunucunun yazdığı özel `matchJobs` belgelerini Cloud Tasks kuyruğuna taşır.
- `advanceMatchTask`: süre dolması, kartların kapanması ve bağlantı kaybını telefon açık olmasa da işler. Genel erişime kapalıdır.

## Uygulanan kontroller

Maç son tarihleri, 15 saniyelik hamle ve yeniden bağlanma süreleri Node sunucusunun `Date.now()` değeriyle hesaplanır. İsteklerdeki tarih, son tarih veya skor iddiaları kullanılmaz. Oyuncu sırası, üyelik, kart indeksi ve oyun aşaması sunucuda doğrulanır. Gizli kart yerleşimi ve henüz gösterilmeyen diziler istemciye açık değildir. Gösterilen bir dizinin cihaz tarafından kaydedilmesini bu düzen tek başına engelleyemez.

Firestore kuralları istemcinin profil puanlarını, maçları, gizli tahtayı veya görev kayıtlarını yazmasını engeller. Aynı hamle kimliğinin tekrarı tekrar puan üretmez; farklı içerikle tekrar kullanımı reddedilir. Sonuç ve hesap ödülü transaction içinde yalnızca bir kez işlenir. Yerel oyun kayıtları düello puanı, galibiyet veya maç sayısı üretemez.

Canların buluttaki yenilenmesi sunucu saatini kullanır. Yerel aktarımın `nextAt`/`observedAt` alanları can yenilemez ve devam eden sunucu yenilenme süresini sıfırlamaz. Daha az can içeren ilk aktarımda sunucu kendi 30 dakikalık sayacını başlatır; cihazın bildirdiği geçmiş süreyi kabul etmez. Bu nedenle ilk bulut aktarımında yerel kısmi bekleme süresi devralınmayabilir.

İstemci açılışta, girişte ve ön plana dönüşte sunucu saatini almayı dener. Başarılı yanıtlardan sonra saat, telefonun değiştirilebilir tarihinden bağımsız `Stopwatch` ile ilerler; sayaçlar ve yerel oyunlar aynı saati kullanır. Ağ gecikmesi tahmini de `Stopwatch` ile ölçülür. Eski bir isteğin yanıtı daha yeni saat örneğinin üzerine yazılmaz. Önceden ileri tarihle kaydedilmiş canların zaman damgaları güvenilir saate uyarlanır.

## Hesap silme ve eski oturumlar — 9 Kasım 2026

Silme isteği son beş dakika içindeki sunucu doğrulamalı auth_time ister; cihaz tarihi bu kontrolü belirlemez. İşlem sırrı 128 bit güvenli rastgele değerdir, sunucuda SHA-256 özeti saklanır. Durum uç noktası Auth hesabı kalktıktan sonra da bu sırla yalnız durum/zaman verir; UID veya profil bilgisi döndürmez.

accountDeletions işareti API transaction'larında ve Firestore okuma kurallarında kontrol edilir. Auth silindikten sonra henüz süresi dolmamış JWT ile profil/aktarım/maç yeniden oluşturulması engellenir. Puan sonuçlandırma da silinen kullanıcının profilini yeniden yazmaz. Tekrarlanan silme istekleri aynı makbuzla güvenlidir. Gizli maç kaydı temizliği, kamuya açık maç kimliksizleştirildikten sonra da tekrar başlanabilen alt işaretlerle izlenir. Temizlik yalnız tamamlanma sonrasındaki 24 saatlik korumadan sonra işareti kaldırır.

iOS Apple yeniden doğrulaması authorization code ile yetki iptali yapar; kod Firestore'a yazılmaz. Dış destek talepleri yönetici sahiplik doğrulaması gerektirir; bu yoldaki Apple sağlayıcı yetkisi için sınırlar SUPPORT_OPERATIONS.md içinde açıklanır. Çevrimdışı diğer cihazlardaki fiziksel yerel kopyaların uzaktan anlık silinmesi garanti edilmez; sunucu erişimi engellenir.

## Açık sınırlar

- İnternet olmadan soğuk açılışta geçen gerçek takvim süresi sunucudan doğrulanamaz. Çevrimdışı canlar, ilerleme ve kişisel rekorlar güvenilir rekabet verisi değildir; cihaz/yerel dosya değişikliklerine karşı kesin koruma iddiası yoktur. Bunlar düello puanı vermez.
- Firebase App Check SDK'sı ve sunucu zorunlu-mod/uygulama kimliği kontrolleri eklendi. Play Integrity ve App Attest sağlayıcı kayıtları 1 saat TTL ile mevcut; eksik Firebase iOS Team ID tamamlandı. Gerçek cihaz tokenları doğrulanana kadar canlı API **izleme modunda**, Firestore enforcement kapalı tutulur. Bu aşamada koruma tamamen etkin değildir. Konsol/cihaz adımları `APP_CHECK_SETUP.md` içindedir. Kimliği doğrulanmış bir kullanıcının özel istemci/bot yazması tamamen engellenmiş değildir. Hız/kötüye kullanım denetimi ve anlaşmalı puan kasma tespiti ayrı yayın öncesi çalışmalardır.
- Bu kontroller “hiç hile yapılamaz” garantisi değildir. Gerçek cihazda Google/Apple girişi, canlı aktarım ve iki telefonla zaman/sıra davranışı ayrıca doğrulanmalıdır.

Doğrulama sonuçları `VERIFICATION.md` içindedir.
