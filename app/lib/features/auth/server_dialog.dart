import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';

/// Boîte de dialogue « Adresse du serveur ». Renvoie `true` si l'adresse a été modifiée.
Future<bool> showServerDialog(BuildContext context) async {
  final url = await showDialog<String>(context: context, builder: (_) => const _ServerDialog());
  if (url == null) return false;
  await Api.setBase(url);
  return true;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final c = TextEditingController(text: Api.base);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adresse du serveur'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'URL'),
          onSubmitted: (s) => Navigator.pop(context, s),
        ),
        Gaps.h8,
        Text(
          'PC (Windows) : http://localhost:3000\nÉmulateur Android : http://10.0.2.2:3000\nTéléphone : http://IP-DU-PC:3000',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Enregistrer')),
    ],
  );
}
