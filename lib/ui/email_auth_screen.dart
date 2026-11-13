import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/app_controller.dart';
import '../data/backend.dart';
import '../data/legal_links.dart';
import 'components.dart';
import 'legal_screen.dart';
import 'responsive.dart';
import 'theme.dart';

/// E-mail sign-in and registration. A new account gets a verification link
/// and can sign in only after confirming its address; the server refuses
/// unverified e-mail accounts as well.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key, this.onSignedIn, this.register = false});
  final VoidCallback? onSignedIn;
  final bool register;
  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  late bool register = widget.register;
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final name = TextEditingController(),
      surname = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      repeat = TextEditingController();
  bool accepted = false, hidden = true, working = false;

  /// Address a verification link was just sent to (shows the next step).
  String? sentTo;

  AppController get app => ref.read(appProvider);

  @override
  void dispose() {
    for (final c in [name, surname, email, password, repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  String? _email(String? v) => _emailPattern.hasMatch(v?.trim() ?? '')
      ? null
      : 'Geçerli bir e-posta adresi yaz.';
  String? _newPassword(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'En az 8 karakter olmalı.';
    if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'En az bir harf ve bir rakam içermeli.';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (working) return;
    setState(() => working = true);
    String? unverified;
    try {
      await action();
    } on EmailNotVerified catch (e) {
      unverified = e.email;
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
    // The button is idle again before the explanation opens.
    if (unverified != null && mounted) await _unverified(unverified);
  }

  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) return;
    final version = await requestLegalAcceptance(context);
    if (version == null || !mounted) return;
    await _run(() async {
      final ok = await app.signInWithEmail(
        email.text,
        password.text,
        legalVersion: version,
      );
      if (!ok || !mounted) return;
      if (widget.onSignedIn != null) {
        widget.onSignedIn!();
      } else {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _register() async {
    if (!_registerForm.currentState!.validate()) return;
    if (!accepted) {
      showError(context, 'Devam etmek için Kullanım Koşullarını kabul et.');
      return;
    }
    await _run(() async {
      await app.registerWithEmail(
        name: '${name.text.trim()} ${surname.text.trim()}',
        email: email.text,
        password: password.text,
      );
      if (!mounted) return;
      setState(() {
        sentTo = email.text.trim();
        register = false;
        password.clear();
        repeat.clear();
      });
    });
  }

  Future<void> _unverified(String address) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('E-postanı doğrula', style: AppColors.display(22)),
      content: Text(
        '$address adresine gönderdiğimiz bağlantıya tıklayıp e-postanı '
        'doğruladıktan sonra giriş yapabilirsin. E-posta gelmediyse spam '
        'klasörüne de bak.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dialog);
            await _run(() async {
              await app.backend.resendVerification(address, password.text);
              if (mounted) {
                showError(context, 'Doğrulama e-postası yeniden gönderildi.');
              }
            });
          },
          child: const Text('Tekrar gönder'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );

  Future<void> _forgot() async {
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ResetDialog(initial: email.text.trim()),
    );
    if (address == null || !mounted) return;
    await _run(() async {
      await app.backend.sendPasswordReset(address);
      if (mounted) {
        showError(
          context,
          'Bu adrese kayıtlı bir hesap varsa şifre sıfırlama bağlantısı gönderildi.',
        );
      }
    });
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      );

  Widget get _eye => IconButton(
    tooltip: hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
    icon: Icon(
      hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
      size: 20,
    ),
    onPressed: () => setState(() => hidden = !hidden),
  );

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutter(context);
    return GameScaffold(
      label: register ? 'Kayıt ol' : 'E-posta ile giriş',
      child: AutofillGroup(
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 28),
          children: [
            _ModeToggle(
              register: register,
              onChanged: working
                  ? null
                  : (value) => setState(() => register = value),
            ),
            const SizedBox(height: 18),
            if (sentTo != null && !register) ...[
              Piece(
                color: const Color(0xFFE5F6EB),
                lip: AppColors.sage,
                border: AppColors.sageDeep,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Doğrulama bağlantısı $sentTo adresine gönderildi. '
                        'Bağlantıya tıkla, sonra buradan giriş yap.',
                        style: AppColors.body.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            register ? _registerFields() : _loginFields(),
          ],
        ),
      ),
    );
  }

  Widget _loginFields() => Form(
    key: _loginForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: _field('E-posta', Icons.mail_rounded),
          validator: _email,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: password,
          obscureText: hidden,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _login(),
          decoration: _field('Şifre', Icons.lock_rounded, suffix: _eye),
          validator: (v) => (v ?? '').isEmpty ? 'Şifreni yaz.' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: working ? null : _forgot,
            child: const Text('Şifremi unuttum'),
          ),
        ),
        const SizedBox(height: 6),
        IqumButton('Giriş yap', accent: true, busy: working, onPressed: _login),
      ],
    ),
  );

  Widget _registerFields() => Form(
    key: _registerForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
                decoration: _field('Ad', Icons.person_rounded),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Adını yaz.' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: surname,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.familyName],
                textInputAction: TextInputAction.next,
                decoration: _field('Soyad', Icons.badge_rounded),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Soyadını yaz.' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: _field('E-posta', Icons.mail_rounded),
          validator: _email,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: password,
          obscureText: hidden,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: _field('Şifre', Icons.lock_rounded, suffix: _eye),
          validator: _newPassword,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: repeat,
          obscureText: hidden,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: _field('Şifre (tekrar)', Icons.lock_outline_rounded),
          validator: (v) => v != password.text ? 'Şifreler aynı olmalı.' : null,
        ),
        const SizedBox(height: 4),
        Text(
          'En az 8 karakter; en az bir harf ve bir rakam.',
          style: AppColors.caption.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: accepted,
          onChanged: (value) => setState(() => accepted = value ?? false),
          title: const Text(
            'Kullanım Koşullarını kabul ediyorum.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => openLegalPage(context, LegalLinks.terms),
              child: const Text('Kullanım Koşulları'),
            ),
            TextButton(
              onPressed: () => openLegalPage(context, LegalLinks.privacy),
              child: const Text('Gizlilik Politikası'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        IqumButton(
          'Kayıt ol',
          accent: true,
          busy: working,
          onPressed: _register,
        ),
        const SizedBox(height: 10),
        const Text(
          'Kayıttan sonra e-postana bir doğrulama bağlantısı gelir. '
          'Doğrulamadan giriş yapılamaz.',
          textAlign: TextAlign.center,
          style: AppColors.caption,
        ),
      ],
    ),
  );
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.register, required this.onChanged});
  final bool register;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.shade,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final (value, label) in const [
          (false, 'Giriş yap'),
          (true, 'Kayıt ol'),
        ])
          Expanded(
            child: Semantics(
              selected: register == value,
              button: true,
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: EdgeInsets.only(bottom: register == value ? 3 : 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: register == value
                        ? AppColors.paper
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: register == value
                        ? AppColors.lip(const Color(0xFFCDBFA6), 3)
                        : null,
                  ),
                  child: Text(
                    label,
                    style: AppColors.body.copyWith(
                      fontSize: 14,
                      color: register == value
                          ? AppColors.text
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog({required this.initial});
  final String initial;
  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  late final controller = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Şifreni sıfırla', style: AppColors.display(22)),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hesabının e-posta adresini yaz. Şifreni yenilemen için bir '
            'bağlantı göndereceğiz.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'E-posta'),
            validator: (v) =>
                _EmailAuthScreenState._emailPattern.hasMatch(v?.trim() ?? '')
                ? null
                : 'Geçerli bir e-posta adresi yaz.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Bağlantı gönder'),
      ),
    ],
  );
}
