import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'app_theme.dart';

/// Logo officiel IronFit (proportions conservées).
/// [transparent] : variante sans fond noir, pour les surfaces claires ou colorées.
/// [darkText] : lettres anthracite au lieu de blanches (surfaces claires), l'ambre ne change pas.
/// [cropped] : enlève les marges vides au-dessus et au-dessous (barre de titre) ; [size] est alors la largeur.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool transparent, darkText, cropped;
  const BrandLogo({
    super.key,
    this.size = 160,
    this.transparent = false,
    this.darkText = false,
    this.cropped = false,
  });

  /// Le canal bleu distingue le blanc (255) de l'ambre (≈ 88) : seul le blanc est assombri.
  static const _whiteToCharcoal = ColorFilter.matrix([
    1, 0, -1.389, 0, 122, //
    0, 1, -1.389, 0, 122, //
    0, 0, -0.389, 0, 122, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final image = Image.asset(
      transparent ? AppConfig.logoTransparent : AppConfig.logo,
      width: size,
      height: cropped ? size * 0.56 : size,
      fit: cropped ? BoxFit.cover : BoxFit.contain,
      // décode à la taille affichée (le fichier source fait 3000 × 3000)
      cacheWidth: (size * dpr).round().clamp(64, 2048),
      filterQuality: FilterQuality.medium,
      semanticLabel: 'IronFit — Own your fitness',
    );
    return darkText ? ColorFiltered(colorFilter: _whiteToCharcoal, child: image) : image;
  }
}

/// Fond de marque : couleur du thème + filigrane discret du logo (silhouette à très faible opacité).
/// Ignore les interactions et reste derrière le contenu pour ne gêner ni la lecture ni les graphiques.
class BrandBackdrop extends StatelessWidget {
  final Color background;
  final Widget child;
  const BrandBackdrop({super.key, required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mark = dark ? Colors.white.withValues(alpha: 0.032) : AppColors.charcoal.withValues(alpha: 0.035);
    return ColoredBox(
      color: background,
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(
          child: LayoutBuilder(builder: (context, c) {
            final s = (c.biggest.shortestSide * 0.85).clamp(220.0, 620.0);
            return Align(
              alignment: const Alignment(0.75, 0.85),
              child: ExcludeSemantics(
                child: Image.asset(
                  AppConfig.logoTransparent,
                  width: s,
                  height: s,
                  fit: BoxFit.contain,
                  color: mark,
                  colorBlendMode: BlendMode.srcIn,
                  cacheWidth: 768,
                ),
              ),
            );
          }),
        ),
        child,
      ]),
    );
  }
}

/// Applique le fond de marque à chaque page (les Scaffold sont transparents) en gardant l'animation native de la plateforme.
/// Chaque page possède ainsi son propre fond opaque : aucun chevauchement visuel pendant les transitions.
class BrandPageTransitionsBuilder extends PageTransitionsBuilder {
  final Color background;
  final PageTransitionsBuilder inner;
  const BrandPageTransitionsBuilder(this.background, this.inner);

  static PageTransitionsTheme theme(Color background) {
    const cupertino = CupertinoPageTransitionsBuilder();
    const zoom = ZoomPageTransitionsBuilder();
    return PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values)
        p: BrandPageTransitionsBuilder(background, p == TargetPlatform.iOS || p == TargetPlatform.macOS ? cupertino : zoom),
    });
  }

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return inner.buildTransitions(route, context, animation, secondaryAnimation, BrandBackdrop(background: background, child: child));
  }

}
