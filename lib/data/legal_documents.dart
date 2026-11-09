import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LegalDocuments {
  LegalDocuments(this.publisher, this.content);
  final Map<String, dynamic> publisher, content;
  static LegalDocuments? _cached;
  static Future<LegalDocuments> load() {
    final cached = _cached;
    if (cached != null) return SynchronousFuture(cached);
    return _load().then((value) => _cached = value);
  }

  static Future<LegalDocuments> _load() async => LegalDocuments(
    Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString('assets/legal/publisher.json'))
          as Map,
    ),
    Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString('assets/legal/tr.json')) as Map,
    ),
  );
  String get version => content['version'] as String;
  String get supportEmail => publisher['supportEmail'] as String? ?? '';
  bool get draft => publisher['status'] != 'published';
  String get origin => (publisher['publicOrigin'] as String? ?? '')
      .replaceFirst(RegExp(r'/$'), '');
  List<Map<String, dynamic>> get documents => (content['documents'] as List)
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
  Map<String, dynamic> document(String id) =>
      documents.firstWhere((d) => d['id'] == id);
  String expand(String value) {
    final values = <String, String>{
      'legalName': (publisher['legalName'] as String? ?? '').isEmpty
          ? 'IQUM işletmecisi (yayın bilgileri tamamlanacak)'
          : publisher['legalName'] as String,
      'contactAddress': (publisher['contactAddress'] as String? ?? '').isEmpty
          ? 'yayın öncesinde eklenecek'
          : publisher['contactAddress'] as String,
      'supportEmail': supportEmail.isEmpty
          ? 'uygulamadaki Destek bölümü'
          : supportEmail,
      'targetAudience': (publisher['targetAudience'] as String? ?? '').isEmpty
          ? 'yayın öncesinde kesinleştirilecek'
          : publisher['targetAudience'] as String,
      'privacyUrl': origin.isEmpty
          ? 'uygulamadaki Gizlilik Politikası'
          : '$origin/gizlilik/',
      'deletionUrl': origin.isEmpty
          ? 'uygulamadaki Hesap ve Veri Silme bölümü'
          : '$origin/hesap-silme/',
    };
    return value.replaceAllMapped(
      RegExp(r'\{\{(\w+)\}\}'),
      (m) => values[m[1]] ?? m[0]!,
    );
  }
}
