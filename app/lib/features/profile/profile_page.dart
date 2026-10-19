import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/feedback.dart';
import '../auth/server_dialog.dart';
import '../crud/module_catalogue.dart';

/// Libellé du rôle affiché sur le profil (« Coach · membre · Musculation »).
String roleText(Json me) => me['role'] == 'coach'
    ? 'Coach · membre${me['specialty'] == null ? '' : ' · ${me['specialty']}'}'
    : (roleLabels[me['role']] ?? '');

/// Profil : informations, modification, mot de passe, adresse du serveur, déconnexion.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _edit() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const _EditProfileDialog());
    if ((saved ?? false) && mounted) setState(() {});
  }

  Future<void> _changePw() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
    if ((saved ?? false) && mounted) showSnack(context, 'Mot de passe mis à jour');
  }

  @override
  Widget build(BuildContext context) {
    final me = Api.me ?? const <String, dynamic>{};
    final phone = '${me['phone'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: Gaps.page,
        children: [
          Card(
            child: ListTile(
              leading: InitialAvatar(me['name']),
              title: Text('${me['name'] ?? ''}'),
              subtitle: Text(
                '${roleText(me)} · @${me['login'] ?? ''}\n${me['email'] ?? ''}${phone.isEmpty ? '' : '\n$phone'}',
              ),
              isThreeLine: true,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier mes informations'),
              onTap: _edit,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Changer le mot de passe'),
              onTap: _changePw,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('Adresse du serveur'),
              subtitle: Text(Api.base),
              onTap: () async {
                if (await showServerDialog(context) && mounted) setState(() {});
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: const Text('Se déconnecter'),
              onTap: Api.logout,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final Json me = Api.me ?? const <String, dynamic>{};
  late final name = TextEditingController(text: '${me['name'] ?? ''}');
  late final email = TextEditingController(text: '${me['email'] ?? ''}');
  late final phone = TextEditingController(text: '${me['phone'] ?? ''}');
  late final specialty = TextEditingController(text: '${me['specialty'] ?? ''}');
  String? err;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    specialty.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final r = await Api.call('PUT', 'profile', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        if (Api.isCoach) 'specialty': specialty.text.trim(),
      });
      Api.me = Map<String, dynamic>.from(r as Map);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (x) {
      if (mounted) {
        setState(() {
          err = '$x';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mes informations'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nom complet'),
          ),
          Gaps.h12,
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          Gaps.h12,
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          if (Api.isCoach) ...[
            Gaps.h12,
            TextField(
              controller: specialty,
              decoration: const InputDecoration(labelText: 'Spécialité (visible par les membres)'),
            ),
          ],
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: Gaps.sm),
              child: StatusMessage(err!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      FilledButton(onPressed: busy ? null : save, child: const Text('Enregistrer')),
    ],
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final old = TextEditingController(), fresh = TextEditingController();
  String? err;
  bool busy = false;

  @override
  void dispose() {
    old.dispose();
    fresh.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (fresh.text.length < 6) {
      setState(() => err = '6 caractères minimum');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final r = await Api.call('POST', 'password', {'old': old.text, 'new': fresh.text});
      // Le serveur révoque les anciens jetons et renvoie celui de cette session
      await Api.setToken((r as Map)['token'] as String);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (x) {
      if (mounted) {
        setState(() {
          err = '$x';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Changer le mot de passe'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: old,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Ancien mot de passe'),
        ),
        Gaps.h12,
        TextField(
          controller: fresh,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '6 caractères minimum'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Gaps.sm),
          child: Text('Vos autres appareils seront déconnectés.', style: Theme.of(context).textTheme.bodySmall),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: Gaps.sm),
            child: StatusMessage(err!),
          ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      FilledButton(onPressed: busy ? null : save, child: const Text('Valider')),
    ],
  );
}
