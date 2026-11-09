# IQUM çalışma tercihleri

- Her değişiklikten sonra otomatik APK veya iOS derlemesi yapma. Kullanıcı yeni bir paket/derleme istediğinde derle.
- Değişikliğe uygun testleri ve Flutter kod kontrolünü çalıştır; geçen kontrolleri ve doğrulanmamış noktaları açıkça bildir.
- Kullanıcıya değişen ekranları ve davranışları kısa, somut biçimde anlat. Kullanıcı görsel kontrolü kendisi yapacak.
- Kullanıcının netleştirdiği Hafıza Yolu görünümü: kıvrılan yol üzerinde level durakları. Oyun içindeki güvenli karo/kalp kuralları ayrıca istenmedikçe korunur.
- Level sırası aşağıdan yukarıya yükselir; mevcut level ilk açılışta görünür/ortalanmış olmalıdır. Yeni premium yön petrol yeşili, porselen ve ölçülü kehribar vurgusudur; sürekli dekoratif animasyon veya yoğun blur ekleme.
- Giriş seçenekleri: Android'de yalnızca Google; iOS'ta Google ve yerel Apple girişi. Android'e Apple düğmesi veya Apple web OAuth akışı ekleme. iOS yerel giriş için domain/Return URL kurulumu zorunlu adım olarak sunulmaz.
- Güncel çevrimiçi altyapı tercihi mevcut Firestore + Cloud Functions + Cloud Tasks ile devam etmektir. Realtime Database ve özel WebSocket sunucusu değerlendirildi; geçiş istenmedi.
- Kullanıcı iOS derlemelerini Codemagic ile alıyor. Yerel Mac/Xcode ve USB bağlantısını zorunlu kullanıcı adımı olarak sunma; iOS imzalama CI'da, gerçek cihaz doğrulaması daha sonra TestFlight üzerinden yapılabilir. Android App Check geliştirme testi Android emülatörü ve debug sağlayıcısıyla yapılabilir.
- Kullanıcı iOS App Check/App Attest gerçek cihaz kontrolünü sonraya bıraktı. Android debug App Check canlı doğrulaması geçti; bu durum gerçek Play Integrity veya iOS App Attest doğrulaması olarak sunulmaz. Canlı App Check zorunlu modu henüz açılmadı.
