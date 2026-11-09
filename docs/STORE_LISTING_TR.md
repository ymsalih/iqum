# IQUM mağaza metinleri

Yalnız gerçekten var olan özellikler anlatılır. Ekran görüntüleri final cihaz sürümünden alınmalı; HTML tasarım önizlemesi uygulama görüntüsü diye yüklenmemeli. Geliştirici adı, telif hakkı, iletişim ve yaş derecesi gerçek yayıncı bilgileriyle tamamlanır.

## Google Play

**Ad:** IQUM: Hafıza Oyunları

**Kısa açıklama:** Üç hafıza oyunu, 30 levellik yol ve arkadaşlarınla sıra tabanlı düellolar.

**Tam açıklama:**

IQUM ile biraz odaklan, bir adım ileri git. Üç farklı hafıza oyununda tek başına pratik yap veya çevrimiçi düelloda bir arkadaşınla karşılaş.

Sıra Hafızası'nda hayvanları ezberle ve doğru sırayla seç. Kart Eşleştirme'de çiftleri bul; çevrimiçi düelloda aynı tahtada sırayla oynayın, açılan kartları ikiniz de görün. Çift bulan oyuncu puan kazanır ve devam eder.

Hafıza Yolu'nda gösterilen güvenli adımları aklında tut. Kıvrılan level yolunda 30 aşama boyunca ilerle. Dört kalbin vardır; yanlış adım bir kalp götürür, eksik kalpler zamanla yenilenir.

Tek oyunculu oyunlar giriş yapmadan ve çevrimdışı oynanabilir. İlerlemeni hesabına bağlamak veya düelloya katılmak istediğinde Google ile giriş yap. Rastgele rakip bul ya da oda kodunu arkadaşınla paylaş. Sesleri ve titreşimi ayarlardan kapatabilirsin.

Bu sürümde reklam ve uygulama içi satın alma bulunmaz. Çevrimiçi düello ve bulut kaydı internet bağlantısı gerektirir. IQUM eğlence amaçlıdır; tıbbi hizmet veya IQ testi değildir.

## App Store

**Ad:** IQUM: Hafıza Oyunları

**Alt başlık:** Üç oyun, her adımda hafıza

**Tanıtım metni:** Üç farklı oyunda hafızanı dene. Tek başına pratik yap, 30 levellik Hafıza Yolu'nda ilerle veya arkadaşınla ortak kart tahtasında karşılaş.

**Açıklama:** Yukarıdaki tam açıklamayı kullan; giriş cümlesini “Google veya Apple ile giriş yap” olarak değiştir. Android ve iOS giriş seçeneklerini birbirine karıştırma.

**Anahtar kelimeler:** hafıza,kart,eşleştirme,hayvan,sıra,yol,düello,bulmaca,odak

**Kategori önerisi:** Oyunlar / Puzzle; ikinci kategori mevcut form ve gerçek ürünle değerlendirilir. Yaş anketi sonuçlanmadan yaş derecesi yazılmaz.

## Ekran görüntüsü planı

Hazır tanıtım varlıkları: `store_assets/google-play-icon.png` (512×512), `app-store-icon.png` (1024×1024), `google-play-feature-graphic.png` (1024×500). Tanıtım grafiği bir marka görselidir, uygulama ekran görüntüsü değildir. Kaynak ve yeniden üretme aracı `feature-graphic.html` / `scripts/prepare_store_assets.cjs` içindedir.

1. Ana sayfa — “Üç oyunda hafızanı dene”.
2. Sıra Hafızası — belirgin hayvanlar ve ezber aşaması.
3. Kart Eşleştirme — ortak tahta ve sıranın kime ait olduğu.
4. Hafıza Yolu — gerçek level oyunu ve dört kalp.
5. Level haritası — aşağıdan yukarıya kıvrılan 30 durak.
6. Düello lobisi — rastgele eşleşme ve kodlu oda.

Ekran boyutlarını mağazanın yükleme gününde gösterdiği zorunlu cihaz sınıflarından al. Gerçek kullanıcı e-postası, token, oda daveti veya özel kayıt gösterme. iPad dağıtımı açıksa gerçek iPad boyutlarında ayrıca kontrol et. Başarı, sıralama, reklamla can veya Rive animasyonları hazır olmadığı halde görsellerde vaat etme.

## İnceleme notu taslağı

IQUM has three memory games. Solo modes are available without an account and work offline. On Android, cloud progress and duels use Google sign-in. On iOS, Google and native Sign in with Apple are available. There are no ads, purchases, gambling, chat, or public leaderboards in this version.

Open **Profil → Bilgilendirme ve gizlilik** to read the bundled Privacy Policy, Terms, game information, deletion information, support contact and open-source licenses without signing in. Account sign-in first displays a short data explanation and an unchecked Terms acceptance box.

To delete an account: sign in, open **Profil → Hesabımı sil**, select the permanent-deletion confirmation and reauthenticate using the same provider account. The request removes the account and associated data through a server job and displays its status. Native Apple reauthentication revokes Apple authorization before submitting the deletion. For an outside-app request, use the published account-deletion URL entered in the listing.

For a duel, both reviewers sign in on two devices, choose the same game, create a room on one device, join with its six-character code on the other, then mark both players ready. Matching uses a shared 16-card board: two selections within a total 15 seconds; a pair earns one match point and another turn. Match victory/draw account rewards are 100/50. Memory Path is solo only.

Reviewer login: use the supported provider flow with a review account you control. If the store requests additional access arrangements, provide a real tested review setup in its private review fields. Do not invent credentials or add an insecure authentication bypass for reviewers. Cloud functions and the published policy/support URLs must remain available throughout review.

**Göndermeden önce:** gerçek destek URL/e-posta, yayıncı/telif, gerçek doğrulanmış inceleme erişimi ve ilgili sürümün test sonuçlarını özel inceleme alanlarına ekle. Bu metin tek başına mağazanın erişim formunu tamamlamaz.
