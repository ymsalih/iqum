# IQUM hesap/veri talepleri işletim süreci

Bu süreç `publisher.json` içindeki gerçek destek adresi açılıp izlenmeye başlandığında uygulanır. Bu çalışma gerçek bir destek e-postası göndermedi veya gerçek kullanıcı hesabı silmedi.

## Uygulama içi otomatik silme

1. Kullanıcı etkileri okuyup kalıcı silme kutusunu kendisi seçer.
2. Aynı hesapla son beş dakika içinde yeniden kimlik doğrulama gerekir. Android Google; iOS Google/yerel Apple. Apple akışında authorization code ile sağlayıcı yetkisi iptal edilir. Kod/parola sunucu Firestore kayıtlarına konmaz.
3. İstemci 128 bit rastgele işlem sırrını önce yerelde saklar. Sunucu idempotent bir silme işareti oluşturur; eski tokenlar hesap/maç verilerini okuyamaz, puan/profil/aktarım oluşturamaz.
4. Cloud Tasks, devam eden maçı adil şekilde sonuçlandırır; yalnız rakibin geçerli puanı kalır. Oyuncunun UID/adı maçtan kaldırılır. Profilin alt koleksiyonları, Auth kullanıcısı, gizli hamleler, odalar, kuyruk ve kilit kayıtları temizlenir. Kısmi işlemden sonra iş tekrar başlayabilir.
5. Tamamlanma durumu makbuz sırrıyla, Auth hesabı silindikten sonra da okunabilir. Bu uç yalnız durum/zaman döndürür; e-posta/profil döndürmez. Sınırlı sunucu işareti tamamlanmadan kaldırılmaz; tamamlanınca 24 saat sonraki temizlik göreviyle kaldırılır. Makbuz sona erdikten sonra yeni durum alınamayabilir; önceki tamamlandı kaydı yerelde korunur.

İşlem uzun süre `pending/processing` kalırsa Cloud Tasks `eraseAccountTask` kuyruğu ve `enqueueAccountDeletion` tetikleyicisinin hata/yeniden denemeleri incelenir. Hatalı işi işaretini silerek “çözme”; bu eski oturumların veriyi yeniden oluşturmasına izin verebilir. Sorunu gider ve aynı UID işini tekrar yürüt. Kuyruk görevi iç API'dir; herkese açık çağrı izni verilmez.

## Uygulamayı kurmadan gelen e-posta

- İş günü gelen kutusunu izle; hedef ilk yanıt iki iş günü, doğrulanmış talebin normal tamamlanma hedefi yedi gün. Uygulanabilir yasal süre daha kısaysa ona uy; gecikme/kapsam gerekçesini kişiye bildir. Bunlar otomatik e-posta veya teslim garantisi değildir; işletmecinin uygulayacağı hizmet hedefleridir.
- Yalnız adını veya bir UID'yi bilen birinin talebiyle hesap silme. Giriş e-postası veya Apple relay adresiyle hesap sahipliğini güvenli biçimde doğrula. Parola, SMS/OTP kodu, `.p8` veya Google erişim tokenı isteme. Hassas kimlik belgesi toplamak varsayılan yöntem değildir.
- Kullanıcı uygulamaya erişebiliyorsa in-app akış en kolay doğrulama yoludur; **uygulamayı tekrar kurmayı tek seçenek yapma**. Apple gizli adresinin iletiyi iletebildiğini doğrula; ad benzerliğinden hesap bulup silme.
- Doğrulanmış hesabın UID'sini yönetici ortamında bul. E-postadan gelen UID'yi doğrulamadan kullanma. Operatör aracı önce kuru çalışma yapar: `node scripts/request_account_deletion.cjs --uid GERCEK_UID`. Yönetici SDK'sı ve yetkili ADC/servis ortamı gerekir; özel anahtar dosyasını repoya koyma.
- Sahiplik doğrulandıktan sonra, aynı araca `--verified-request --execute` ekle. Araç aynı silme kuyruğunu başlatır; müşteriye verilecek geçici durum makbuzu sırdır ve yalnız özel operatör dosyasına yazılır. Raporu/logu genel web'e koyma. Kimlik doğrulaması yerine bu bayrağı körlemesine kullanma.
- Apple yetki iptalinin uygulama içi yeniden doğrulamayla yapılıp yapılmadığını ayrıca kontrol et. Dış talepte kullanıcıdan parola/token isteme; hesabını geciktirmeden sil, gerekirse Apple hesabındaki uygulama yetkisini kaldırma yolunu anlat. Sunucu, saklanmayan bir Apple refresh tokenını sihirli biçimde iptal edemez. Sağlayıcı erişimini yöneten yeni bir sunucu akışı eklenirse Apple REST revoke ve güvenli anahtar saklama ayrıca uygulanmalı.
- Tamamlanmayı kuyruğun/işaretin durumundan doğrula; ilgili Auth/profil/alt kayıtlar ve eski erişim kapatılmış olmalı. Kullanıcıya silinen kapsamı, rakipte kimliksiz kalan sonuçları ve teknik log saklama istisnalarını sade biçimde bildir. Tamamlanmadan “silindi” cevabı gönderme.
- Destek yazışmasını talep kapandıktan sonra 90 gün içinde temizle. Zorunlu bir saklama varsa yalnız gerekli kayıtları, gerekçe ve süreyle sınırla. Operatör makbuzunu da artık gerekmediğinde kaldır.

## Erişim, düzeltme ve diğer talepler

Aynı sahiplik doğrulamasını kullan. Erişim taleplerinde rakibin özel verilerini, gizli oyun tahtalarını veya yönetici sırlarını paylaşma. Düzeltme/itiraz talebinin kapsamını belirle ve uygulanabilir hukuk çerçevesinde yanıtla. Verileri satış/pazarlama listesine aktarma.

## İnceleme ve gerçek cihaz senaryoları

- Onaysız/iptal/yanlış hesap: silme başlamaz; yerel ilerleme korunur.
- Sunucu kabulünden önce bağlantı kesilir: işlem belirsiz gösterilir, aynı makbuzla kontrol/tekrar yapılır.
- Kabulden sonra uygulama kapanır: açılışta yerel temizleme ve durum sorgusu sürer.
- Aynı istek/iş yeniden çalışır: çift puan veya yanlış hesap silme olmaz.
- Eski token/diğer cihaz: sunucu yazma/okuma reddedilir. Diğer cihazda çevrimdışı önceden kalmış yerel kopyanın fiziksel temizliği ayrıca gerekir.
- Aktif düelloda silme: rakip sonucu tek kez; eski UID/ad görünmez.
- Apple E-postamı Gizle / yeniden giriş / token revoke: gerçek TestFlight iPhone'da doğrula.

Bu senaryoların kod/emülatör testleri ile gerçek Google/Apple ve mağaza paketinden yapılan testleri ayrı kaydet.
