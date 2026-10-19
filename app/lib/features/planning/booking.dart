import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/feedback.dart';

/// Réserve le cours, ou annule la réservation si elle existe déjà (le serveur bascule).
Future<void> toggleBooking(Object? classId) => Api.call('POST', 'book', {'class_id': classId});

/// État d'un cours du point de vue du membre connecté.
class ClassSlot {
  final double taken, spots;
  final bool mine;

  /// Le membre connecté anime ce cours (coach).
  final bool teaching;

  ClassSlot(Json c)
    : taken = toDouble(c['taken']),
      spots = toDouble(c['spots']),
      mine = asBool(c['mine']),
      teaching = c['coach_id'] != null && c['coach_id'] == Api.myId;

  bool get full => taken >= spots && !mine;
  double get ratio => spots == 0 ? 0 : (taken / spots).clamp(0.0, 1.0);
}

/// Bouton Réserver / Annuler / Complet (ou « Vous animez ») pour un cours.
class BookButton extends StatelessWidget {
  final Json cls;
  final Future<void> Function() onChanged;

  const BookButton({super.key, required this.cls, required this.onChanged});

  Future<void> _toggle(BuildContext context) async {
    if (await attempt(context, () => toggleBooking(cls['id']))) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final slot = ClassSlot(cls);
    if (slot.teaching) return const Chip(label: Text('Vous animez'));
    if (slot.mine) return OutlinedButton(onPressed: () => _toggle(context), child: const Text('Annuler'));
    return FilledButton(
      onPressed: slot.full ? null : () => _toggle(context),
      child: Text(slot.full ? 'Complet' : 'Réserver'),
    );
  }
}

/// [RowAction] du module « Séances » : bouton de réservation pour les membres (pas dans l'espace coach).
Widget? bookAction(BuildContext context, Json row, Future<void> Function() reload) {
  if (!Api.isMember || Api.inCoachSpace || ClassSlot(row).teaching) return null;
  return BookButton(cls: row, onChanged: reload);
}
