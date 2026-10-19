import 'package:flutter/material.dart';

import '../theme/spacing.dart';

/// État vide (ou d'erreur) avec message et bouton d'action optionnel.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? cta;
  final VoidCallback? onTap;

  const EmptyState({super.key, required this.icon, required this.text, this.cta, this.onTap});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gaps.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline)),
          Gaps.h12,
          Text(text, textAlign: TextAlign.center),
          if (cta != null) ...[Gaps.h12, FilledButton.tonal(onPressed: onTap, child: Text(cta!))],
        ],
      ),
    ),
  );
}

/// [EmptyState] qui reste défilable : nécessaire sous un `RefreshIndicator`.
class ScrollableEmptyState extends StatelessWidget {
  final EmptyState child;
  const ScrollableEmptyState({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: child,
        ),
      ],
    ),
  );
}
