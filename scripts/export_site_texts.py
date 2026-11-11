"""Exports the legal pages as paste-ready text for the website (Google Sites).

Source: design/legal/tr.json. Usage:
    python scripts/export_site_texts.py [output folder]   (default: output/site-texts)
Bracketed fields ([DESTEK E-POSTA ADRESİN] …) are filled in by the publisher.
"""
import json, os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'design', 'legal', 'tr.json')
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'output', 'site-texts')
os.makedirs(out, exist_ok=True)
d = json.load(open(src, encoding='utf8'))
fill = {
    'legalName': '[ADIN SOYADIN veya ŞİRKET ADI]',
    'supportEmail': '[DESTEK E-POSTA ADRESİN]',
    'contactAddress': '[İLETİŞİM ADRESİN]',
    'targetAudience': '[HEDEF YAŞ GRUBU, ör. 13 yaş ve üstü]',
    'privacyUrl': '[GİZLİLİK SAYFASI LİNKİ]',
    'deletionUrl': '[HESAP SİLME SAYFASI LİNKİ]',
}


def expand(t):
    return re.sub(r'\{\{(\w+)\}\}', lambda m: fill.get(m[1], m[0]), t)


order = ['privacy', 'terms', 'guide', 'deletion']
pages = {doc['id']: doc for doc in d['documents']}
names = {}
for n, pid in enumerate(order, 1):
    doc = pages[pid]
    lines = [doc['title'], '', expand(doc['intro']), '', f"Sürüm: {d['version']}", '']
    for sec in doc['sections']:
        lines += [sec['title'], '']
        for p in sec.get('paragraphs', []):
            lines += [expand(p), '']
        for b in sec.get('bullets', []):
            lines += ['• ' + expand(b)]
        if sec.get('bullets'):
            lines += ['']
    for link in doc.get('links', []) or []:
        lines += [f"{link['label']}: {link['url']}"]
    name = f"{n}-{doc['title']}.txt"
    names[pid] = name
    open(os.path.join(out, name), 'w', encoding='utf8').write('\n'.join(lines).rstrip() + '\n')

guide = f"""IQUM — Google Sites'ta açılacak sayfalar
============================================

Bir Google Sites sitesi aç (ör. adı "IQUM") ve aşağıdaki 4 sayfayı oluştur.
Her sayfanın metni bu klasördeki aynı numaralı dosyada.

1. Gizlilik Politikası          → metin: {names['privacy']}
   Önerilen sayfa adresi: .../gizlilik
2. Kullanım Koşulları           → metin: {names['terms']}
   Önerilen sayfa adresi: .../kullanim-kosullari
3. Oyun ve Hesap Bilgileri      → metin: {names['guide']}
   Önerilen sayfa adresi: .../oyun-bilgileri
4. Hesap ve Veri Silme          → metin: {names['deletion']}
   Önerilen sayfa adresi: .../hesap-silme

Ana sayfaya (destek sayfası olarak kullanılır) kısaca şunları yaz:
IQUM logosu (Logo klasöründe), "IQUM — Hafıza Oyunları", destek e-posta adresin
ve bu 4 sayfanın linkleri.

Metinlerde köşeli parantezle işaretli yerleri kendi bilgilerinle değiştir:
  [ADIN SOYADIN veya ŞİRKET ADI]
  [DESTEK E-POSTA ADRESİN]
  [İLETİŞİM ADRESİN]
  [HEDEF YAŞ GRUBU, ör. 13 yaş ve üstü]
  [GİZLİLİK SAYFASI LİNKİ]   (sayfayı yayınladıktan sonra adresini yaz)
  [HESAP SİLME SAYFASI LİNKİ]

Mağazaların istediği koşullar:
- Site "Herkese açık" yayınlanmalı (giriş istememeli). PDF kullanma.
- Hesap silme sayfası ayrı bir sayfa olmalı; IQUM adı ve silme adımları görünmeli.
- Uygulamadaki kurallar değişirse bu metinleri de güncelle; ikisi aynı kalmalı.

Bittiğinde bana şu linkleri gönder:
- Gizlilik Politikası linki
- Kullanım Koşulları linki
- Oyun ve Hesap Bilgileri linki
- Hesap ve Veri Silme linki
- Destek e-posta adresi
Uygulamadaki bağlantıları bunlara göre ayarlayacağım.
"""
open(os.path.join(out, '0-OKU-Sayfalar.txt'), 'w', encoding='utf8').write(guide)
print('\n'.join(sorted(os.listdir(out))))
