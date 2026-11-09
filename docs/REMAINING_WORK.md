# IQUM kalan işler — 9 Kasım 2026

Kullanıcının son kararı: Firestore + Cloud Functions + Cloud Tasks korunur. iOS App Check/App Attest gerçek cihaz kontrolü sonraya bırakılır. Kodun hazır olması ile gerçek hesap/cihaz doğrulamasının geçmesi ayrı durumlardır.

## Hazır olan temel kapsam

- Üç tek oyunculu oyun; Hafıza Yolu 30 level, dört kalp ve kayıt/yenilenme.
- Premium tema, marka, 12 hayvan görseli, kart/karo/buton hareketleri, ses/titreşim ayarları.
- SQLite misafir/hesap alanları ve tekrar işlenmeyen bulut aktarım kodu.
- Android Google; iOS Google ve yerel Apple giriş kodu/yapılandırması.
- Canlı Firestore kuralları; API, görev kuyruğu ve düello fonksiyonları.
- Sunucu saatine bağlı düello, sıra/skor doğrulaması, gizli kartlar ve tek seferlik ödüller.
- App Check SDK ve zorunlu mod kodu. Android emülatörü → canlı Firebase debug doğrulaması geçti; üretim izleme modunda.

## Öncelik 1 — gerçek yayın bilgileri ve politika yayını

- Uygulama içi yasal merkez, açık koşul onayı, yeniden doğrulamalı hesap silme, Apple yetki iptali kodu ve yerel temizlik eklendi. Sunucuda silme kuyruğu, eski oturum engelleri ve yeniden denenebilir temizlik yayımlandı.
- Aynı metinlerden üretilen dört web sayfası, dış hesap silme e-posta yolu, destek işletim süreci, mağaza açıklamaları ve veri beyanları hazır. Ayrıntılar STORE_READINESS.md içinde.
- Gerçek işletmeci adı, destek e-postası, iletişim adresi, HTTPS alanı ve hedef yaş grupları assets/legal/publisher.json içinde doldurulmalı. Bilinmeyen değerler uydurulmadı; yayın kontrolü bu alanlar eksikken geçmez.
- Kullanıcı daha sonra legal_site sayfalarını yayımlayacak; burada web yayını yapılmadı. Gerçek destek adresi izlenmeli, dış taleplerde sahiplik doğrulanmalı.

## Öncelik 2 — gerçek hesapla giriş ve aktarım doğrulaması

- Android'de gerçek Google hesap seçimi → Firebase Auth kullanıcısı → bulut profilini doğrula.
- İptal, çıkış/tekrar giriş, misafir ilerlemesi ve yeni/mevcut hesaba aktarımı kontrol et. Kesilen aktarım kayıp veya çoğalma üretmemeli.
- iOS Google/Apple gerçek girişleri, E-postamı gizle ve aynı akışlar Codemagic/TestFlight sürümünde doğrulanmalı. Yerel Mac/USB gerekmez.

## Öncelik 3 — iki istemcili canlı düello doğrulaması

Sunucu emülatör testleri geçti; Flutter arayüzünün iki gerçek oyuncu hesabıyla canlı oda/rastgele eşleşme akışı henüz tamamlanmış sayılmaz. Ortak kart açılması, sıra, puan, 15 saniye, eşleşmede devam, beraberlik, bağlantı kaybı ve tek seferlik ödül iki istemcide doğrulanmalı. Hamle gecikmesi ve maç başına tüketim ölçülmeli; ölçüm olmadan altyapı değiştirilmemeli.

## Öncelik 4 — kullanıcı deneyimi ve performans

- Güncel görsel revizyonu küçük ekranlarda ve uzun oturumda gözden geçir.
- Fiziksel orta seviye cihazda profile/release FPS ve bellek ölç. Hedef %95 kare için UI/raster <16,7 ms; henüz ölçülmedi.
- Oyun sürelerini/30 level zorluğunu dengele.
- Gerçek `.riv` hayvan dosyaları henüz yok; PNG çizimleri kullanılıyor. Rive animasyonları ek görsel çalışma olarak ele alınabilir.

## Öncelik 5 — yayın hazırlığı

- Android release debug imza fallback kaldırıldı ve eksik upload anahtarıyla görevin durduğu doğrulandı. Kullanıcıya ait yayın anahtarı/Play App Signing ve üretim SHA kayıtları tamamlanmalı.
- Codemagic'te iOS Firebase dosyaları, imzalama profili, App Attest production entitlements ve TestFlight akışı doğrulanmalı. Bu depoda Codemagic workflow dosyası bulunmadı; uzaktaki Workflow Editor ayarları kontrol edilmiş sayılmaz.
- Mağaza açıklama/veri beyanı çalışma dosyaları ile 512/1024 simgeler ve Play tanıtım grafiği hazır. Final uygulama ekran görüntüleri, gerçek içerik/yaş anketleri, App Privacy/Data safety formları ve yayımlanmış destek/politika bağlantıları mağazada tamamlanmalı.
- Gerçek Android Play Integrity ve ertelenen iOS App Attest doğrulamalarından sonra App Check zorunlu moduna geçilmeli.

Reklamla can kazanma ve genel sıralama ilk sürüm kapsamına dahil değildir.

Kaynaklar:
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://support.google.com/googleplay/android-developer/answer/13327111
