# IQUM mağaza metinleri

Yalnız gerçekten var olan özellikler anlatılır. Ekran görüntüleri final cihaz sürümünden alınmalı; HTML tasarım önizlemesi uygulama görüntüsü diye yüklenmemeli. Geliştirici adı, telif hakkı, iletişim ve yaş derecesi gerçek yayıncı bilgileriyle tamamlanır.

## Google Play

**Ad:** IQUM: Hafıza Oyunları

**Kısa açıklama:** Üç hafıza oyunu, 90 level, yıldızlar ve arkadaşlarınla çevrimiçi düello.

**Tam açıklama:**

IQUM ile biraz odaklan, bir adım ileri git. Üç hafıza oyununun her birinde 30 level seni bekliyor; tek başına ilerle veya çevrimiçi düelloda bir arkadaşınla karşılaş.

Sıra Hafızası'nda hayvanları ve sıralarını ezberle, sonra doğru sırayla seç. Kart sayısı 3'ten 12'ye çıkar, ezber süresi kısalır.

Kart Eşleştirme'de kapalı kartların arasında çiftleri bul. Tahta 6 karttan 24 karta büyür; hamle hakkın sınırlı, az hamlede bitirirsen daha çok yıldız kazanırsın.

Hafıza Yolu'nda güvenli yol bir kartta gösterilir ve sonra kalkar. Kapalı karoları hafızanla çevirerek en alttan zirveye ilerle.

Her level 1–3 yıldız verir. Çayır, Orman ve Zirve bölümlerinden geçen level haritasında ilerlemeni gör; profilinde oyun başına istatistiklerini takip et. Dört kalbin vardır; yanan level bir kalp götürür, eksik kalpler 30 dakikada bir yenilenir. Kartlar dönerken her hayvan kendi küçük animasyonuyla canlanır.

Düelloda aynı tahtada sırayla kart açın; açılan kartları ikiniz de görürsünüz. Çift bulan puan kazanır ve devam eder. Sıra Hafızası düellosunda aynı diziyi aynı anda cevaplarsınız. Düello kalp harcamaz.

Tek oyunculu oyunlar giriş yapmadan ve çevrimdışı oynanabilir. İlerlemeni hesabına bağlamak veya düelloya katılmak istediğinde Google ile giriş yap. Rastgele rakip bul ya da oda kodunu arkadaşınla paylaş. Sesleri ve titreşimi ayarlardan kapatabilirsin.

Bu sürümde reklam ve uygulama içi satın alma bulunmaz. Çevrimiçi düello ve bulut kaydı internet bağlantısı gerektirir. IQUM eğlence amaçlıdır; tıbbi hizmet veya IQ testi değildir.

## App Store

**Ad:** IQUM: Hafıza Oyunları

**Alt başlık:** Üç oyun, 90 level, tek hafıza

**Tanıtım metni:** Üç hafıza oyununda 90 level, yıldızlar ve level haritası. Tek başına ilerle veya arkadaşınla ortak kart tahtasında karşılaş.

**Açıklama:** Yukarıdaki tam açıklamayı kullan; giriş cümlesini “Google veya Apple ile giriş yap” olarak değiştir. Android ve iOS giriş seçeneklerini birbirine karıştırma.

**Anahtar kelimeler:** hafıza,kart,eşleştirme,hayvan,sıra,yol,düello,bulmaca,odak,level

**Kategori önerisi:** Oyunlar / Puzzle; ikinci kategori mevcut form ve gerçek ürünle değerlendirilir. Yaş anketi sonuçlanmadan yaş derecesi yazılmaz.

## Ekran görüntüsü planı

Hazır tanıtım varlıkları: `store_assets/google-play-icon.png` (512×512), `app-store-icon.png` (1024×1024), `google-play-feature-graphic.png` (1024×500). Tanıtım grafiği bir marka görselidir, uygulama ekran görüntüsü değildir. Kaynak: `design/brand/brand.cjs`, üretici: `node design/brand/build_brand.cjs`.

Uygulama ekran görüntüleri `store_assets/screenshots/` altındadır ve `test/store_screenshots_test.dart` ile gerçek uygulama ekranlarından üretilir (`IQUM_STORE_SHOTS` klasör değişkeni). Sıra:

1. Ana sayfa — üç oyun, level ve yıldızlar.
2. Level haritası — Çayır bölümünde geçilmiş leveller ve yıldızlar.
3. Hafıza Yolu — ayrı kartta gösterilen yol.
4. Sıra Hafızası — ezber aşaması.
5. Kart Eşleştirme — eşleşmiş çiftler ve hamle sayacı.
6. Level sonucu — üç yıldız.
7. Profil — oyun başına istatistikler.

Boyutlar: Google Play telefon 1080×1920; App Store iPhone 6,9 inç 1320×2868; App Store iPad 13 inç 2064×2752. Mağazanın yükleme gününde istediği cihaz sınıflarını yeniden kontrol et. Görüntüler misafir oyuncuyla alınır; gerçek e-posta, token veya oda kodu içermez.

## İnceleme notu taslağı

IQUM has three memory games. Solo modes are available without an account and work offline. On Android, cloud progress and duels use Google sign-in. On iOS, Google and native Sign in with Apple are available. There are no ads, purchases, gambling, chat, or public leaderboards in this version.

Open **Profil → Bilgilendirme ve gizlilik** to read the bundled Privacy Policy, Terms, game information, deletion information, support contact and open-source licenses without signing in. Account sign-in first displays a short data explanation and an unchecked Terms acceptance box.

To delete an account: sign in, open **Profil → Hesabımı sil**, select the permanent-deletion confirmation and reauthenticate using the same provider account. The request removes the account and associated data through a server job and displays its status. Native Apple reauthentication revokes Apple authorization before submitting the deletion. For an outside-app request, use the published account-deletion URL entered in the listing.

For a duel, both reviewers sign in on two devices, choose the same game, create a room on one device, join with its six-character code on the other, then mark both players ready. Matching uses a shared 16-card board: two selections within a total 15 seconds; a pair earns one match point and another turn. Match victory/draw account rewards are 100/50. Duels do not use hearts. Solo games have 30 levels each; a failed level costs one of four hearts, which refill every 30 minutes. Memory Path is solo only.

Reviewer login: use the supported provider flow with a review account you control. If the store requests additional access arrangements, provide a real tested review setup in its private review fields. Do not invent credentials or add an insecure authentication bypass for reviewers. Cloud functions and the published policy/support URLs must remain available throughout review.

**Göndermeden önce:** gerçek destek URL/e-posta, yayıncı/telif, gerçek doğrulanmış inceleme erişimi ve ilgili sürümün test sonuçlarını özel inceleme alanlarına ekle. Bu metin tek başına mağazanın erişim formunu tamamlamaz.
