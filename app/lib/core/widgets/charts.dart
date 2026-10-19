import 'package:flutter/material.dart';

/// Histogramme simple (revenus par mois), avec un résumé textuel pour les lecteurs d'écran.
class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String semanticsLabel;
  final double height;

  const BarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.semanticsLabel,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: BarsPainter(labels, values, cs.primary, cs.onSurface, scaler)),
      ),
    );
  }
}

/// Courbe simple (évolution du poids), avec un résumé textuel pour les lecteurs d'écran.
class LineChart extends StatelessWidget {
  final List<double> values;
  final String semanticsLabel;
  final double height;

  const LineChart({super.key, required this.values, required this.semanticsLabel, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: LinePainter(values, cs.primary, cs.onSurface, MediaQuery.textScalerOf(context))),
      ),
    );
  }
}

TextPainter _label(String text, Color color, TextScaler scaler) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(color: color, fontSize: 11),
  ),
  textDirection: TextDirection.ltr,
  textScaler: scaler,
)..layout();

class BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color, textColor;
  final TextScaler scaler;

  BarsPainter(this.labels, this.values, this.color, this.textColor, [this.scaler = TextScaler.noScaling]);

  @override
  void paint(Canvas c, Size s) {
    if (values.isEmpty) return;
    var mx = values.reduce((a, b) => a > b ? a : b);
    if (mx == 0) mx = 1;
    final w = s.width / values.length, ch = s.height - 32;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = ch * values[i] / mx, cx = i * w + w / 2;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.2, ch - h + 14, w * 0.6, h), const Radius.circular(6)),
        paint,
      );
      final v = _label(values[i].toStringAsFixed(0), textColor, scaler);
      v.paint(c, Offset(cx - v.width / 2, ch - h));
      final l = _label(i < labels.length ? labels[i] : '', textColor, scaler);
      l.paint(c, Offset(cx - l.width / 2, s.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter old) =>
      old.values != values || old.labels != labels || old.color != color || old.textColor != textColor;
}

class LinePainter extends CustomPainter {
  final List<double> v;
  final Color color, textColor;
  final TextScaler scaler;

  LinePainter(this.v, this.color, this.textColor, [this.scaler = TextScaler.noScaling]);

  @override
  void paint(Canvas c, Size s) {
    if (v.length < 2) return;
    final mn = v.reduce((a, b) => a < b ? a : b), mx = v.reduce((a, b) => a > b ? a : b);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);
    const pad = 26.0;
    final pts = [
      for (var i = 0; i < v.length; i++)
        Offset(pad + (s.width - 2 * pad) * i / (v.length - 1), pad + (s.height - 2 * pad) * (1 - (v[i] - mn) / range)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < pts.length; i++) {
      c.drawCircle(pts[i], 4.5, dot);
      final tp = _label(v[i].toStringAsFixed(1), textColor, scaler);
      tp.paint(c, Offset(pts[i].dx - tp.width / 2, pts[i].dy - 20));
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter old) => old.v != v || old.color != color || old.textColor != textColor;
}
