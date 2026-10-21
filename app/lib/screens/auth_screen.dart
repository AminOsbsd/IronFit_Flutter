import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/brand.dart';
import '../services/auth_service.dart';

enum Mode { login, signup, forgot, reset }

Future<void> serverDialog(BuildContext context) async {
  final c = TextEditingController(text: Api.base);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Adresse du serveur'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL de l\'API', prefixIcon: Icon(Icons.dns_outlined))),
        const SizedBox(height: 12),
        Text(
          'PC (Windows / Web) : http://localhost:${AppConfig.apiPort}/api\n'
          'Émulateur Android : http://10.0.2.2:${AppConfig.apiPort}/api\n'
          'Téléphone : http://IP-DU-PC:${AppConfig.apiPort}/api',
          style: Theme.of(d).textTheme.bodySmall,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => c.text = AppConfig.defaultApiBase, child: const Text('Par défaut')),
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enregistrer')),
      ],
    ),
  );
  if (ok == true) await Api.setBase(c.text);
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  Mode mode = Mode.login;
  final _c = <String, TextEditingController>{};
  final formKey = GlobalKey<FormState>();
  bool busy = false, ok = false, hide = true;
  String? msg, dev;

  TextEditingController t(String k) => _c.putIfAbsent(k, () => TextEditingController());
  String v(String k) => t(k).text.trim();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void go(Mode m) => setState(() {
        mode = m;
        msg = null;
        ok = false;
        formKey.currentState?.reset();
      });

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      switch (mode) {
        case Mode.login:
          await AuthService.login(v('id'), t('pw').text);
          break;
        case Mode.signup:
          await AuthService.signup(name: v('name'), login: v('login'), email: v('email'), password: t('pw').text);
          break;
        case Mode.forgot:
          dev = await AuthService.forgotPassword(v('email'));
          mode = Mode.reset;
          msg = dev == null ? 'Si ce compte existe, un code a été envoyé par e-mail.' : null;
          ok = true;
          break;
        case Mode.reset:
          await AuthService.resetPassword(email: v('email'), code: v('code'), password: t('pw').text);
          mode = Mode.login;
          dev = null;
          t('pw').clear();
          msg = 'Mot de passe modifié. Connectez-vous.';
          ok = true;
          break;
      }
    } catch (e) {
      msg = '$e';
      ok = false;
    }
    if (mounted) setState(() => busy = false);
  }

  Widget input(String k, String label, {bool pw = false, TextInputType? type, String? Function(String)? check, IconData? icon, Iterable<String>? autofill}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: t(k),
        obscureText: pw && hide,
        keyboardType: type,
        autocorrect: false,
        autofillHints: autofill,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: pw ? IconButton(tooltip: hide ? 'Afficher' : 'Masquer', icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)) : null,
        ),
        validator: (s) {
          s = s ?? '';
          if (s.trim().isEmpty) return 'Obligatoire';
          return check?.call(s);
        },
        onFieldSubmitted: (_) => submit(),
      ),
    );
  }

  String? _mail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim()) ? null : 'E-mail invalide';
  String? _pw(String s) => s.length < 6 ? '6 caractères minimum' : null;

  Widget form(BuildContext context) {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final title = {Mode.login: 'Connexion', Mode.signup: 'Créer un compte', Mode.forgot: 'Mot de passe oublié', Mode.reset: 'Nouveau mot de passe'}[mode]!;
    final subtitle = {
      Mode.login: 'Ravi de vous revoir. Prêt pour la séance ?',
      Mode.signup: 'Rejoignez la salle en quelques secondes.',
      Mode.forgot: 'Entrez votre e-mail : un code à 6 chiffres vous sera envoyé.',
      Mode.reset: 'Saisissez le code reçu et votre nouveau mot de passe.',
    }[mode]!;
    final btn = {Mode.login: 'Se connecter', Mode.signup: 'S\'inscrire', Mode.forgot: 'Envoyer le code', Mode.reset: 'Réinitialiser'}[mode]!;
    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: tt.headlineMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 22),
          if (mode == Mode.login) ...[
            input('id', 'Identifiant ou e-mail', icon: Icons.person_outline, autofill: const [AutofillHints.username]),
            input('pw', 'Mot de passe', pw: true, icon: Icons.lock_outline, autofill: const [AutofillHints.password]),
          ],
          if (mode == Mode.signup) ...[
            input('name', 'Nom complet', icon: Icons.badge_outlined, autofill: const [AutofillHints.name]),
            input('login', 'Identifiant', icon: Icons.person_outline, check: (s) => RegExp(r'^[a-zA-Z0-9_.-]{3,20}$').hasMatch(s.trim()) ? null : '3 à 20 caractères (lettres, chiffres, . _ -)'),
            input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail_outline, check: _mail, autofill: const [AutofillHints.email]),
            input('pw', 'Mot de passe', pw: true, icon: Icons.lock_outline, check: _pw, autofill: const [AutofillHints.newPassword]),
          ],
          if (mode == Mode.forgot) input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail_outline, check: _mail),
          if (mode == Mode.reset) ...[
            if (dev != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text('Mode démo — votre code : $dev', textAlign: TextAlign.center, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
            input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail_outline, check: _mail),
            input('code', 'Code à 6 chiffres', type: TextInputType.number, icon: Icons.pin_outlined),
            input('pw', 'Nouveau mot de passe', pw: true, icon: Icons.lock_outline, check: _pw),
          ],
          if (msg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: (ok ? AppColors.success : cs.error).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: ok ? AppColors.success : cs.error),
                const SizedBox(width: 10),
                Expanded(child: Text(msg!, style: TextStyle(color: ok ? AppColors.success : cs.error, fontWeight: FontWeight.w600))),
              ]),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : submit,
              child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(btn),
            ),
          ),
          const SizedBox(height: 10),
          if (mode == Mode.login) ...[
            TextButton(onPressed: () => go(Mode.forgot), child: const Text('Mot de passe oublié ?')),
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Pas encore membre ?', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              TextButton(onPressed: () => go(Mode.signup), child: const Text('S\'inscrire')),
            ]),
          ] else
            TextButton.icon(onPressed: () => go(Mode.login), icon: const Icon(Icons.arrow_back), label: const Text('Retour à la connexion')),
        ]),
      ),
    );
  }

  /// Panneau de marque : fond noir identique à celui du logo, pour une intégration sans cadre.
  Widget brandPanel({required double logo, bool tagline = true}) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BrandLogo(size: logo),
          if (tagline) ...[
            const SizedBox(height: 4),
            Container(width: 56, height: 4, decoration: BoxDecoration(gradient: AppColors.amberGradient, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Text('Salle · Coaching · Suivi', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w600)),
          ],
        ]),
      );

  Widget settingsButton(Color color) => IconButton(
        tooltip: 'Adresse du serveur',
        icon: Icon(Icons.settings_outlined, color: color),
        onPressed: () async {
          await serverDialog(context);
          if (mounted) setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      // fond opaque : l'écran de connexion affiche le logo en grand, pas en filigrane
      backgroundColor: cs.surface,
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Row(children: [
            Expanded(flex: 5, child: brandPanel(logo: (c.maxHeight * 0.62).clamp(260.0, 520.0))),
            Expanded(
              flex: 4,
              child: Stack(children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form(context)),
                  ),
                ),
                Positioned(top: 12, right: 12, child: SafeArea(child: settingsButton(cs.onSurfaceVariant))),
              ]),
            ),
          ]);
        }
        final logo = (c.maxWidth * 0.62).clamp(170.0, 280.0);
        return Stack(children: [
          SingleChildScrollView(
            child: Column(children: [
              SafeArea(bottom: false, child: SizedBox(width: double.infinity, child: brandPanel(logo: logo, tagline: false))),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form(context))),
                ),
              ),
            ]),
          ),
          // bandeau noir derrière la barre d'état
          Positioned(top: 0, left: 0, right: 0, height: MediaQuery.paddingOf(context).top, child: const ColoredBox(color: Colors.black)),
          Positioned(top: 4, right: 4, child: SafeArea(child: settingsButton(Colors.white70))),
        ]);
      }),
    );
  }
}
