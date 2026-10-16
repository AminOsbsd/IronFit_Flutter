import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum Mode { login, signup, forgot, reset }

Future<void> serverDialog(BuildContext context) async {
  final c = TextEditingController(text: Api.base);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Adresse du serveur'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL')),
        const SizedBox(height: 8),
        const Text('PC (Windows) : http://localhost:3000\nÉmulateur Android : http://10.0.2.2:3000\nTéléphone : http://IP-DU-PC:3000', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
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

  void go(Mode m) => setState(() { mode = m; msg = null; ok = false; formKey.currentState?.reset(); });

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { busy = true; msg = null; });
    try {
      switch (mode) {
        case Mode.login:
          await Api.setSession((await Api.call('POST', 'login', {'login': v('id'), 'password': t('pw').text})) as Map);
          break;
        case Mode.signup:
          await Api.setSession((await Api.call('POST', 'signup', {'name': v('name'), 'login': v('login'), 'email': v('email'), 'password': t('pw').text})) as Map);
          break;
        case Mode.forgot:
          final r = await Api.call('POST', 'forgot', {'email': v('email')});
          dev = (r as Map)['devCode'] as String?;
          mode = Mode.reset;
          msg = dev == null ? 'Si ce compte existe, un code a été envoyé par e-mail.' : null;
          ok = true;
          break;
        case Mode.reset:
          await Api.call('POST', 'reset', {'email': v('email'), 'code': v('code'), 'password': t('pw').text});
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

  Widget input(String k, String label, {bool pw = false, TextInputType? type, String? Function(String)? check, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: t(k),
        obscureText: pw && hide,
        keyboardType: type,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(), prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: pw ? IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)) : null,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = {Mode.login: 'Connexion', Mode.signup: 'Créer un compte', Mode.forgot: 'Mot de passe oublié', Mode.reset: 'Nouveau mot de passe'}[mode]!;
    final btn = {Mode.login: 'Se connecter', Mode.signup: 'S\'inscrire', Mode.forgot: 'Envoyer le code', Mode.reset: 'Réinitialiser'}[mode]!;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Serveur', icon: const Icon(Icons.settings), onPressed: () async { await serverDialog(context); setState(() {}); })),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    CircleAvatar(radius: 36, backgroundColor: cs.primary, child: Icon(Icons.fitness_center, size: 36, color: cs.onPrimary)),
                    const SizedBox(height: 12),
                    Text('IronFit', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 20),
                    if (mode == Mode.login) ...[
                      input('id', 'Identifiant ou e-mail', icon: Icons.person),
                      input('pw', 'Mot de passe', pw: true, icon: Icons.lock),
                    ],
                    if (mode == Mode.signup) ...[
                      input('name', 'Nom complet', icon: Icons.badge),
                      input('login', 'Identifiant', icon: Icons.person, check: (s) => RegExp(r'^[a-zA-Z0-9_.-]{3,20}$').hasMatch(s.trim()) ? null : '3 à 20 caractères (lettres, chiffres, . _ -)'),
                      input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail, check: _mail),
                      input('pw', 'Mot de passe', pw: true, icon: Icons.lock, check: _pw),
                    ],
                    if (mode == Mode.forgot) ...[
                      const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Entrez votre e-mail : un code à 6 chiffres vous sera envoyé.', textAlign: TextAlign.center)),
                      input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail, check: _mail),
                    ],
                    if (mode == Mode.reset) ...[
                      if (dev != null)
                        Container(
                          padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
                          child: Text('Mode démo — votre code : $dev', textAlign: TextAlign.center),
                        ),
                      input('email', 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail, check: _mail),
                      input('code', 'Code à 6 chiffres', type: TextInputType.number, icon: Icons.pin),
                      input('pw', 'Nouveau mot de passe', pw: true, icon: Icons.lock, check: _pw),
                    ],
                    if (msg != null)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(msg!, textAlign: TextAlign.center, style: TextStyle(color: ok ? Colors.green : cs.error))),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(btn)),
                    ),
                    const SizedBox(height: 8),
                    if (mode == Mode.login) ...[
                      TextButton(onPressed: () => go(Mode.forgot), child: const Text('Mot de passe oublié ?')),
                      TextButton(onPressed: () => go(Mode.signup), child: const Text('Pas de compte ? S\'inscrire')),
                    ] else
                      TextButton(onPressed: () => go(Mode.login), child: const Text('← Retour à la connexion')),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
