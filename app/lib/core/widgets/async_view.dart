import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Chargement asynchrone uniforme pour les écrans : `loading` → `error` (avec « Réessayer ») → données.
///
/// L'écran implémente [fetch] et affiche son contenu avec [AsyncStateView]. [reload] sert aux boutons
/// « Actualiser », au tirer-pour-rafraîchir et après chaque action (réservation, validation…).
mixin AsyncLoadMixin<W extends StatefulWidget, T> on State<W> {
  T? data;
  Object? error;
  bool loading = true;

  Future<T> fetch();

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (data == null && !loading) setState(() => loading = true);
    try {
      final d = await fetch();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }
}

/// Affiche l'état d'un [AsyncLoadMixin] : indicateur, erreur avec bouton « Réessayer », ou [builder].
class AsyncStateView<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final T? data;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  const AsyncStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.data,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (error != null) {
      return EmptyState(icon: Icons.wifi_off, text: '$error', cta: 'Réessayer', onTap: onRetry);
    }
    if (loading || d == null) {
      return const Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement'));
    }
    return builder(context, d);
  }
}

/// Bouton « Actualiser » des barres d'app (avec libellé pour les lecteurs d'écran).
class RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  const RefreshButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'Actualiser', onPressed: onPressed, icon: const Icon(Icons.refresh));
}
