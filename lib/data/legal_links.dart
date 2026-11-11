/// Public pages the app links to (published by the publisher, e.g. on
/// Google Sites). The texts themselves are not bundled in the app; their
/// source is `design/legal/tr.json` (export: `scripts/export_site_texts.py`).
///
/// Fill every value before a store release; empty links are shown as
/// "not yet available" and are reported by `scripts/store_preflight.cjs`.
abstract final class LegalLinks {
  /// Terms version the player accepts at sign-in. Must equal
  /// `CURRENT_LEGAL_VERSION` in functions/src/index.js.
  static const version = '2026-11-10';

  static const privacy =
      'https://sites.google.com/view/iqumgizlilikpolitikasi/ana-sayfa';
  static const terms =
      'https://sites.google.com/view/iqumkullanimkosullari/ana-sayfa';
  static const gameInfo =
      'https://sites.google.com/view/iqumoyunvehesapbilgileri/ana-sayfa';
  static const deletion = 'https://sites.google.com/view/iqumhesap/ana-sayfa';
  static const supportEmail = 'salihatic@gmail.com';

  static Uri? uri(String link) {
    final parsed = Uri.tryParse(link);
    return parsed != null && parsed.scheme == 'https' ? parsed : null;
  }
}
