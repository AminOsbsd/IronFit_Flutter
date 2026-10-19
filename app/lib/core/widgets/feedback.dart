import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/values.dart';

/// Affiche un message temporaire en bas de l'écran.
void showSnack(BuildContext context, String message) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Boîte de confirmation (renvoie `true` si l'utilisateur confirme).
Future<bool> confirm(BuildContext context, String title, {String? body, String ok = 'Confirmer'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(ok)),
        ],
      ),
    ) ??
    false;

/// Exécute un appel réseau et affiche l'erreur éventuelle ; renvoie `true` en cas de succès.
Future<bool> attempt(BuildContext context, Future<void> Function() f, {String? success}) async {
  try {
    await f();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, '$e');
    return false;
  }
}

/// Message d'erreur ou de succès sous un formulaire, annoncé par les lecteurs d'écran.
class StatusMessage extends StatelessWidget {
  final String text;
  final bool success;

  const StatusMessage(this.text, {super.key, this.success = false});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.of(context).success : Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color),
      ),
    );
  }
}

/// Demande le mode de paiement (espèces, carte…). Renvoie `null` si annulé.
Future<String?> pickPaymentMethod(BuildContext context, String title) {
  var v = payMethods.first;
  return showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<String>(
          initialValue: v,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Mode de paiement'),
          items: [for (final e in payMethods) DropdownMenuItem(value: e, child: Text(e))],
          onChanged: (x) => set(() => v = x ?? v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, v), child: const Text('Confirmer')),
        ],
      ),
    ),
  );
}

/// Avatar rond avec l'initiale d'un nom (`?` si vide), ignoré par les lecteurs d'écran (le nom est lu à côté).
class InitialAvatar extends StatelessWidget {
  final Object? name;
  const InitialAvatar(this.name, {super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CircleAvatar(child: Text(initialOf(name))));
}
