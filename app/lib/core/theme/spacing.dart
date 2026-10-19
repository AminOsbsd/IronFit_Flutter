import 'package:flutter/widgets.dart';

/// Échelle d'espacement (multiples de 4) partagée par tous les écrans.
abstract final class Gaps {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24;

  static const h4 = SizedBox(height: xs), h8 = SizedBox(height: sm), h12 = SizedBox(height: md);
  static const h16 = SizedBox(height: lg), h24 = SizedBox(height: xl);
  static const w8 = SizedBox(width: sm), w12 = SizedBox(width: md), w16 = SizedBox(width: lg);

  /// Marge intérieure des listes de pages.
  static const page = EdgeInsets.all(md);

  /// Marge intérieure des cartes.
  static const card = EdgeInsets.all(lg);

  static const radius = 16.0;
}
