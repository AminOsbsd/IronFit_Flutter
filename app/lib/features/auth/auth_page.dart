import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/feedback.dart';
import 'server_dialog.dart';

enum AuthMode { login, signup, forgot, reset }

/// Règles de validation des formulaires d'authentification (partagées et testées).
abstract final class AuthValidators {
  static String? required(String? s) => (s ?? '').trim().isEmpty ? 'Obligatoire' : null;

  static String? email(String? s) =>
      required(s) ?? (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s!.trim()) ? null : 'E-mail invalide');

  static String? password(String? s) => required(s) ?? (s!.length < 6 ? '6 caractères minimum' : null);

  static String? login(String? s) =>
      required(s) ??
      (RegExp(r'^[a-zA-Z0-9_.-]{3,20}$').hasMatch(s!.trim()) ? null : '3 à 20 caractères (lettres, chiffres, . _ -)');

  static String? code(String? s) =>
      required(s) ?? (RegExp(r'^\d{6}$').hasMatch(s!.trim()) ? null : 'Code à 6 chiffres');
}

/// Connexion, inscription, mot de passe oublié et réinitialisation.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthMode mode = AuthMode.login;
  final _controllers = <String, TextEditingController>{};
  final formKey = GlobalKey<FormState>();
  bool busy = false, ok = false, hide = true;
  String? msg, devCode;

  TextEditingController t(String k) => _controllers.putIfAbsent(k, TextEditingController.new);
  String v(String k) => t(k).text.trim();

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void go(AuthMode m) => setState(() {
    mode = m;
    msg = null;
    ok = false;
    formKey.currentState?.reset();
  });

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      switch (mode) {
        case AuthMode.login:
          final r = await Api.call('POST', 'login', {'login': v('id'), 'password': t('pw').text});
          await Api.setSession(r as Map);
        case AuthMode.signup:
          final r = await Api.call('POST', 'signup', {
            'name': v('name'),
            'login': v('login'),
            'email': v('email'),
            'password': t('pw').text,
          });
          await Api.setSession(r as Map);
        case AuthMode.forgot:
          final r = await Api.call('POST', 'forgot', {'email': v('email')});
          devCode = (r as Map?)?['devCode'] as String?;
          mode = AuthMode.reset;
          msg = devCode == null ? 'Si ce compte existe, un code a été envoyé par e-mail.' : null;
          ok = true;
        case AuthMode.reset:
          await Api.call('POST', 'reset', {'email': v('email'), 'code': v('code'), 'password': t('pw').text});
          mode = AuthMode.login;
          devCode = null;
          t('pw').clear();
          msg = 'Mot de passe modifié. Connectez-vous.';
          ok = true;
      }
    } on ApiException catch (e) {
      msg = '$e';
      ok = false;
    }
    if (mounted) setState(() => busy = false);
  }

  Widget input(
    String k,
    String label, {
    bool pw = false,
    TextInputType? type,
    String? Function(String?) check = AuthValidators.required,
    IconData? icon,
    Iterable<String>? autofill,
    TextInputAction action = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gaps.md),
      child: TextFormField(
        controller: t(k),
        obscureText: pw && hide,
        keyboardType: type,
        autocorrect: false,
        enableSuggestions: !pw,
        autofillHints: autofill,
        textInputAction: action,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: pw
              ? IconButton(
                  tooltip: hide ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hide = !hide),
                )
              : null,
        ),
        validator: check,
        onFieldSubmitted: action == TextInputAction.done ? (_) => submit() : null,
      ),
    );
  }

  List<Widget> fields() => switch (mode) {
    AuthMode.login => [
      input('id', 'Identifiant ou e-mail', icon: Icons.person, autofill: const [AutofillHints.username]),
      input(
        'pw',
        'Mot de passe',
        pw: true,
        icon: Icons.lock,
        autofill: const [AutofillHints.password],
        action: TextInputAction.done,
      ),
    ],
    AuthMode.signup => [
      input('name', 'Nom complet', icon: Icons.badge, autofill: const [AutofillHints.name]),
      input(
        'login',
        'Identifiant',
        icon: Icons.person,
        check: AuthValidators.login,
        autofill: const [AutofillHints.newUsername],
      ),
      input(
        'email',
        'E-mail',
        type: TextInputType.emailAddress,
        icon: Icons.mail,
        check: AuthValidators.email,
        autofill: const [AutofillHints.email],
      ),
      input(
        'pw',
        'Mot de passe',
        pw: true,
        icon: Icons.lock,
        check: AuthValidators.password,
        autofill: const [AutofillHints.newPassword],
        action: TextInputAction.done,
      ),
    ],
    AuthMode.forgot => [
      const Padding(
        padding: EdgeInsets.only(bottom: Gaps.md),
        child: Text('Entrez votre e-mail : un code à 6 chiffres vous sera envoyé.', textAlign: TextAlign.center),
      ),
      input(
        'email',
        'E-mail',
        type: TextInputType.emailAddress,
        icon: Icons.mail,
        check: AuthValidators.email,
        autofill: const [AutofillHints.email],
        action: TextInputAction.done,
      ),
    ],
    AuthMode.reset => [
      if (devCode != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Gaps.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: Gaps.page,
              child: Text(
                'Mode démo — votre code : $devCode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
              ),
            ),
          ),
        ),
      input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail, check: AuthValidators.email),
      input(
        'code',
        'Code à 6 chiffres',
        type: TextInputType.number,
        icon: Icons.pin,
        check: AuthValidators.code,
        autofill: const [AutofillHints.oneTimeCode],
      ),
      input(
        'pw',
        'Nouveau mot de passe',
        pw: true,
        icon: Icons.lock,
        check: AuthValidators.password,
        autofill: const [AutofillHints.newPassword],
        action: TextInputAction.done,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = switch (mode) {
      AuthMode.login => 'Connexion',
      AuthMode.signup => 'Créer un compte',
      AuthMode.forgot => 'Mot de passe oublié',
      AuthMode.reset => 'Nouveau mot de passe',
    };
    final btn = switch (mode) {
      AuthMode.login => 'Se connecter',
      AuthMode.signup => 'S\'inscrire',
      AuthMode.forgot => 'Envoyer le code',
      AuthMode.reset => 'Réinitialiser',
    };
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gaps.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExcludeSemantics(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: cs.primary,
                              child: Icon(Icons.fitness_center, size: 36, color: cs.onPrimary),
                            ),
                          ),
                          Gaps.h12,
                          Text('IronFit', textAlign: TextAlign.center, style: tt.headlineMedium),
                          Semantics(
                            header: true,
                            child: Text(title, textAlign: TextAlign.center, style: tt.titleMedium),
                          ),
                          Gaps.h24,
                          ...fields(),
                          if (msg != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Gaps.md),
                              child: StatusMessage(msg!, success: ok),
                            ),
                          FilledButton(
                            onPressed: busy ? null : submit,
                            child: busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Envoi en cours'),
                                  )
                                : Text(btn),
                          ),
                          Gaps.h8,
                          if (mode == AuthMode.login) ...[
                            TextButton(
                              onPressed: () => go(AuthMode.forgot),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                            TextButton(
                              onPressed: () => go(AuthMode.signup),
                              child: const Text('Pas de compte ? S\'inscrire'),
                            ),
                          ] else
                            TextButton(
                              onPressed: () => go(AuthMode.login),
                              child: const Text('← Retour à la connexion'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Placé après le contenu pour rester au-dessus de celui-ci (cliquable).
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Adresse du serveur',
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  if (await showServerDialog(context) && mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
