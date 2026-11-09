import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../application/app_controller.dart';
import '../data/backend.dart';
import '../data/legal_documents.dart';
import 'components.dart';
import 'theme.dart';

Future<void> openLegalLink(BuildContext context, Uri uri) async {
  if (!['https', 'mailto'].contains(uri.scheme)) return;
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      showError(
        context,
        'Bağlantı açılamadı. Adresi kopyalayıp kullanabilirsin.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showError(context, 'Bu bağlantıyı açan bir uygulama bulunamadı.');
    }
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) => FutureBuilder<LegalDocuments>(
    future: LegalDocuments.load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Bilgilendirme')),
          body: Center(
            child: snapshot.hasError
                ? const Text('Metin açılamadı. Lütfen tekrar dene.')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final legal = snapshot.data!, doc = legal.document(id);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            doc['title'] as String,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              if (kDebugMode && legal.draft)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'TASLAK · Yayıncı ve iletişim bilgileri yayından önce tamamlanacak.',
                    style: AppColors.caption,
                  ),
                ),
              Text(
                doc['intro'] as String,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
              Text('Sürüm: ${legal.version}', style: AppColors.caption),
              for (final section in doc['sections'] as List) ...[
                const SizedBox(height: 24),
                Text(
                  section['title'] as String,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final paragraph in section['paragraphs'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      legal.expand(paragraph as String),
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ),
                for (final bullet in section['bullets'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '• ${legal.expand(bullet as String)}',
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ),
              ],
              for (final link in doc['links'] as List? ?? [])
                TextButton(
                  onPressed: () =>
                      openLegalLink(context, Uri.parse(link['url'] as String)),
                  child: Text(link['label'] as String),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> requestLegalAcceptance(BuildContext context) async {
  final legal = await LegalDocuments.load();
  if (!context.mounted) return null;
  var accepted = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Hesabınla devam et', style: AppColors.display(24)),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Girişte sağlayıcının paylaştığı profil bilgileri ve seçtiğin oyun ilerlemesi Firebase ile işlenir. Düelloda görünen adın ve maç skorun rakibinle paylaşılır.',
              style: TextStyle(height: 1.5),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LegalDocumentScreen('privacy'),
                ),
              ),
              child: const Text('Gizlilik Politikasını oku'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LegalDocumentScreen('terms'),
                ),
              ),
              child: const Text('Kullanım Koşullarını oku'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: accepted,
              onChanged: (value) => setState(() => accepted = value ?? false),
              title: const Text(
                'Kullanım Koşullarını kabul ediyorum.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const Text(
              'Gizlilik metni veri kullanımını açıklar; koşulları kabul etmek ayrı rıza gerektiren işlemlere toplu onay vermez.',
              style: AppColors.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Misafir kal'),
          ),
          FilledButton(
            onPressed: accepted ? () => Navigator.pop(context, true) : null,
            child: const Text('Devam et'),
          ),
        ],
      ),
    ),
  );
  return result == true ? legal.version : null;
}

class LegalCenterScreen extends ConsumerWidget {
  const LegalCenterScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bilgilendirme ve gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final item in const [
            ('privacy', 'Gizlilik Politikası', Icons.privacy_tip_outlined),
            ('terms', 'Kullanım Koşulları', Icons.description_outlined),
            ('guide', 'Oyun ve Hesap Bilgileri', Icons.info_outline),
            ('deletion', 'Hesap ve Veri Silme', Icons.manage_accounts_outlined),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$3),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LegalDocumentScreen(item.$1),
                ),
              ),
            ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: const Text('Açık kaynak lisansları'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'IQUM'),
          ),
          FutureBuilder<LegalDocuments>(
            future: LegalDocuments.load(),
            builder: (context, snapshot) {
              final email = snapshot.data?.supportEmail ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent),
                title: const Text('Destek ve veri talepleri'),
                subtitle: SelectableText(
                  email.isEmpty
                      ? 'Destek iletişimi yayın öncesinde eklenecek.'
                      : email,
                ),
                onTap: email.isEmpty
                    ? null
                    : () => openLegalLink(
                        context,
                        Uri(
                          scheme: 'mailto',
                          path: email,
                          query:
                              'subject=${Uri.encodeComponent('IQUM destek talebi')}',
                        ),
                      ),
              );
            },
          ),
          if (app.account != null || app.deletion != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: Text(
                app.deletion != null ? 'Hesap silme durumu' : 'Hesabımı sil',
                style: const TextStyle(color: AppColors.red),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
            ),
          if (app.account == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Bu cihazdaki misafir verilerini sıfırla'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Misafir ilerlemesi silinsin mi?'),
                    content: const Text(
                      'Bu cihazdaki mevcut misafir levelleri, rekorları ve yarım kalan oyunları silinir. Bulut hesapların etkilenmez.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await app.resetGuestProgress();
                  } catch (error) {
                    if (context.mounted) {
                      showError(context, friendlyError(error));
                    }
                  }
                }
              },
            ),
          const SizedBox(height: 24),
          const Text(
            'IQUM bir eğlence oyunudur; tıbbi hizmet veya IQ testi değildir.',
            style: AppColors.caption,
          ),
        ],
      ),
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool confirmed = false;
  Timer? _poll;
  int _attempts = 0;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) _bind(ref.read(appProvider));
    });
  }

  void _bind(AppController app) {
    final pending = ['pending', 'processing'].contains(app.deletion?['state']);
    if (!pending) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_poll != null || _attempts >= 20) return;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || ++_attempts > 20) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      if (ModalRoute.of(context)?.isCurrent == true) {
        unawaited(ref.read(appProvider).refreshDeletionStatus());
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appProvider, (_, next) => _bind(next));
    final app = ref.watch(appProvider), state = app.deletion?['state'];
    final done = state == 'complete',
        pending = ['pending', 'processing'].contains(state);
    return Scaffold(
      appBar: AppBar(title: Text(done ? 'Hesabın silindi' : 'Hesabımı sil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.delete_outline,
            size: 52,
            color: done ? AppColors.green : AppColors.red,
          ),
          const SizedBox(height: 22),
          Text(
            done
                ? 'Silme tamamlandı.'
                : pending
                ? 'Silme işlemin başlatıldı.'
                : 'Hesabını kalıcı olarak sil.',
            style: AppColors.display(27),
          ),
          const SizedBox(height: 16),
          Text(
            done
                ? 'Bulut hesabın ve bağlı kayıtların silindi. Diğer cihazlarda kalan yerel kopyaları o cihazlardan temizleyebilirsin.'
                : pending
                ? 'Sunucu isteğini kabul etti ve silme işlemi sürüyor. Tamamlandığında burada görebilirsin. Uygulamayı kapatıp daha sonra durumu kontrol edebilirsin.'
                : 'Profilin, hesap puanın, bulut ilerlemen ve kayıtların silinir. Düello geçmişindeki adın/kimliğin kaldırılır; rakibinin kendi sonucu kalabilir. Aktif maçtan ayrılma hükmen kayıp doğurabilir.',
            style: const TextStyle(height: 1.6),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalDocumentScreen('deletion'),
              ),
            ),
            child: const Text('Nelerin silindiğini ve saklama bilgisini oku'),
          ),
          if (state == 'prepared')
            const Text(
              'İsteğin kabul edildiği henüz doğrulanamadı. Verilerin işlem kabul edilene kadar bu cihazda korunur; durumunu kontrol edebilir veya tekrar deneyebilirsin.',
              style: AppColors.caption,
            ),
          if (app.deletion?['statusUnavailable'] == true)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Durum makbuzu şu anda doğrulanamıyor veya süresi dolmuş olabilir. Tamamlandığı doğrulanmadan silindi sayılmaz; tekrar kontrol edebilir veya Destek bölümünden yardım isteyebilirsin.',
                style: AppColors.caption,
              ),
            ),
          if (!pending && !done && app.account != null) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: confirmed,
              onChanged: app.busy
                  ? null
                  : (value) => setState(() => confirmed = value ?? false),
              title: const Text(
                'Hesabımın ve bağlı kayıtlarımın kalıcı olarak silinmesini istiyorum.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const Text(
              'Aynı Google/Apple hesabıyla kimliğini yeniden doğrulaman istenecek. İşlemi iptal edebilirsin.',
              style: AppColors.caption,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                padding: const EdgeInsets.all(18),
              ),
              onPressed: confirmed && !app.busy
                  ? () async {
                      try {
                        await app.deleteAccount();
                      } catch (error) {
                        if (context.mounted) {
                          showError(context, friendlyError(error));
                        }
                      }
                    }
                  : null,
              child: Text(
                app.busy ? 'İşlem yapılıyor…' : 'Hesabımı kalıcı olarak sil',
              ),
            ),
          ],
          if (app.deletion != null && !done)
            TextButton(
              onPressed: app.busy ? null : app.refreshDeletionStatus,
              child: Text(
                app.busy ? 'Kontrol ediliyor…' : 'Silme durumunu kontrol et',
              ),
            ),
          if (done)
            FilledButton(
              onPressed: () async {
                await app.dismissCompletedDeletion();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Misafir olarak devam et'),
            ),
          if (app.account == null && app.deletion == null)
            const Text(
              'Şu anda misafir olarak oynuyorsun; silinecek bir bulut hesabın yok.',
              style: AppColors.caption,
            ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalCenterScreen(),
              ),
            ),
            child: const Text('Destek ve diğer gizlilik seçenekleri'),
          ),
        ],
      ),
    );
  }
}
