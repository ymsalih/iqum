# IQUM canlı düello altyapısı seçenekleri

Fiyat kontrolü: 8 Kasım 2026. USD; vergiler ve ek hizmetler hariç. Mevcut sistem hâlâ Firestore + Cloud Functions + Cloud Tasks kullanır. Bu belge alternatif değerlendirmesidir; geçiş uygulanmadı.

## Firebase Realtime Database

Firebase bağlantıları ve küçük JSON güncellemelerinin iki oyuncuya dağıtımını yönetir. Oyun motoru değildir; gizli tahta ve hamle/puan doğrulaması güvenilir sunucuda kalmalıdır. Firebase Auth ve hesap/puan kayıtları için Firestore korunabilir. RTDB'nin yerel presence/onDisconnect desteği bağlantı yönetimine yardımcı olur; kesin 15 saniyelik hükmen kaybetme kuralı ayrıca sunucuda korunur.

RTDB depolama ve veri aktarımı üzerinden ücretlenir. Blaze ücretsiz aktarım kotası günlük 360 MB'dir; yaklaşık 10 GB/ay olarak gösterilir. Aşan aktarım $1/GB. İlk 1 GB depolama ücretsiz, fazlası $5/GB/ay. Protokol/TLS/yeniden bağlantı trafiği de faturalandırılan aktarımın parçasıdır. Functions, Firestore, görevler ve diğer servisler bu fiyata dahil değildir.

Örnek **ölçüm değildir**: Maç başına iki oyuncu ve protokol dahil toplam faturalandırılan aktarımın 1 MB olduğunu varsayalım. 30 güne eşit dağılan 10.000 maç 10 GB aktarım yapar ve günlük kota içinde kalabilir. 100.000 maç 100 GB aktarım, yaklaşık $89–90 RTDB aktarım bedeli yapar. Tek güne yığılan trafik aynı aylık toplama rağmen farklı ücret doğurabilir. Veritabanı 1 GB altında varsayılmıştır.

## WebSocket oyun sunucusu

Node.js gibi bir sunucu programı sürekli çalışır. İki telefon sunucuya açık bağlantı kurar. Sunucu hamleyi doğrulayıp sonucu iki oyuncuya doğrudan gönderir; maç sonucu kalıcı veritabanına tek seferlik işlenir. Maç sürerken yeniden bağlanma, süreç çökmesi, ara kayıtlar ve birden çok sunucu arasında oda paylaşımı ayrıca tasarlanmalıdır. Ağ gecikmesi devam eder; sunucu bölgesi ve yükü ölçülmeden daha hızlı olduğu garanti edilmez.

DigitalOcean Basic örnek liste fiyatı: 1 GiB RAM/1 vCPU/25 GiB disk/1.000 GiB transfer $6/ay; 2 GiB RAM/1 vCPU/50 GiB disk/2.000 GiB transfer $12/ay. Bunlar yalnızca tek VM kirasıdır; kapasite veya kesintisiz hizmet garantisi değildir. Yedek, kalıcı veritabanı, ek trafik, izleme ve ikinci sunucu ek maliyet olabilir. Küçük sunucu trafiği yokken de çalışır ve ücretlenir. Güvenlik güncellemeleri, TLS, izleme ve yedekleme işletimi bize aittir.

## Seçim ölçütü

İlk sürümde düşük trafik ve az işletim yükü için RTDB makul bir adaydır. Sürekli yoğun maç trafiği veya daha öngörülebilir sunucu kirası isteniyorsa WebSocket değerlendirilebilir. Gerçek maçın veri boyutu, eşzamanlı oda sayısı ve gecikmesi ölçülmeden aylık kullanıcı sayısından kesin bütçe çıkarılamaz. İkisi de Firebase Auth/App Check ile kullanılabilir; App Check tek başına oyun hilesini veya anlaşmalı puan kasmayı bitirmez.

Kaynaklar:
- https://firebase.google.com/pricing
- https://firebase.google.com/docs/database/usage/billing
- https://firebase.google.com/docs/database/rtdb-vs-firestore
- https://firebase.google.com/docs/firestore/solutions/presence
- https://www.digitalocean.com/pricing/droplets
