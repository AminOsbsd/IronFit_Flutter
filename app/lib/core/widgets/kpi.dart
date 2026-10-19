import 'package:flutter/material.dart';

import '../theme/spacing.dart';

/// Indicateur chiffré (icône, valeur, libellé). Lu en une seule phrase par les lecteurs d'écran.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;

  const KpiCard({super.key, required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Semantics(
        label: '$label : $value',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
              Gaps.h4,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.headlineSmall),
              ),
              Text(label, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille d'indicateurs : colonnes adaptées à la largeur (ou [columns] fixes), hauteur qui suit la taille du texte.
class KpiGrid extends StatelessWidget {
  final List<KpiCard> children;
  final int? columns;

  const KpiGrid({super.key, required this.children, this.columns});

  @override
  Widget build(BuildContext context) {
    // Hauteur fixe (icône, marges, espacements : 64) + texte mis à l'échelle (valeur + 2 lignes de libellé : 64).
    final extent = 64 + MediaQuery.textScalerOf(context).scale(64);
    final cols = columns;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: cols == null
          ? SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: extent)
          : SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: extent),
      children: children,
    );
  }
}

/// Titre de section dans une liste, annoncé comme titre par les lecteurs d'écran.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Gaps.xs, Gaps.lg, Gaps.xs, Gaps.sm),
    child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
  );
}

/// Ligne « titre · barre de remplissage · x/y » (remplissage des cours).
class FillRow extends StatelessWidget {
  final String label;
  final int taken, spots;

  const FillRow({super.key, required this.label, required this.taken, required this.spots});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label : $taken sur $spots places réservées',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, overflow: TextOverflow.ellipsis)),
          Gaps.w8,
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: spots == 0 ? 0 : (taken / spots).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Gaps.w8,
          Text('$taken/$spots'),
        ],
      ),
    ),
  );
}
