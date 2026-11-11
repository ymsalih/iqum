import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'components.dart';
import 'responsive.dart';
import 'theme.dart';

/// Open-source notices in the app's own look. The texts come from Flutter's
/// license registry (every package and font the app ships with); the
/// packages' licenses require these notices to travel with the app.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});
  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late final Future<List<(String, List<LicenseParagraph>)>> _packages =
      _collect();

  /// Groups the registry by package; a package may carry several notices.
  static Future<List<(String, List<LicenseParagraph>)>> _collect() async {
    final byPackage = <String, List<LicenseParagraph>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final paragraphs = entry.paragraphs.toList();
      for (final package in entry.packages) {
        final list = byPackage.putIfAbsent(package, () => []);
        if (list.isNotEmpty) {
          list.add(const LicenseParagraph('', 0)); // separator
        }
        list.addAll(paragraphs);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [for (final n in names) (n, byPackage[n]!)];
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutter(context);
    return GameScaffold(
      label: 'Açık kaynak lisansları',
      child: FutureBuilder<List<(String, List<LicenseParagraph>)>>(
        future: _packages,
        builder: (context, snapshot) {
          final packages = snapshot.data;
          if (packages == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 28),
            itemCount: packages.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Piece(
                    color: AppColors.petrol,
                    lip: AppColors.dark,
                    border: AppColors.dark,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        const OwlMark(size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IQUM\'u mümkün kılanlar',
                                style: AppColors.display(
                                  19,
                                ).copyWith(color: AppColors.paper),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Uygulama ${packages.length} açık kaynak paket ve '
                                'font kullanır. Lisansları gereği bildirimleri '
                                'aşağıdadır.',
                                style: AppColors.caption.copyWith(
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final (name, paragraphs) = packages[i - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Piece(
                  border: AppColors.line,
                  radius: 16,
                  depth: 3,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
                    title: Text(name, style: AppColors.title(16)),
                    subtitle: Text(
                      _kind(paragraphs),
                      style: AppColors.caption.copyWith(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _LicenseText(name, paragraphs),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// A short guess at the license family, from its first lines.
  static String _kind(List<LicenseParagraph> paragraphs) {
    final head = paragraphs.take(12).map((p) => p.text).join(' ').toLowerCase();
    if (head.contains('apache license')) return 'Apache lisansı';
    if (head.contains('open font license')) return 'SIL Open Font lisansı';
    if (head.contains('mit license') ||
        head.contains('permission is hereby granted, free of charge')) {
      return 'MIT lisansı';
    }
    if (head.contains('redistribution and use in source and binary')) {
      return 'BSD lisansı';
    }
    if (head.contains('mozilla public license')) return 'Mozilla lisansı';
    if (head.contains('zlib')) return 'zlib lisansı';
    return 'Lisans metni';
  }
}

class _LicenseText extends StatelessWidget {
  const _LicenseText(this.name, this.paragraphs);
  final String name;
  final List<LicenseParagraph> paragraphs;
  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutter(context);
    return GameScaffold(
      label: name,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 28),
        itemCount: paragraphs.length,
        itemBuilder: (context, i) {
          final p = paragraphs[i];
          if (p.text.isEmpty) {
            return const Divider(height: 32, color: AppColors.line);
          }
          final centered = p.indent == LicenseParagraph.centeredIndent;
          return Padding(
            padding: EdgeInsets.only(
              left: centered ? 0 : 14.0 * p.indent,
              bottom: 10,
            ),
            child: SelectableText(
              p.text,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: AppColors.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppColors.text,
              ),
            ),
          );
        },
      ),
    );
  }
}
