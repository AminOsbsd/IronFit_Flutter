import 'package:flutter/material.dart';
import '../services/api_service.dart';

const dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const monthShort = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
const payMethods = ['Espèces', 'Carte', 'Virement', 'Chèque'];

Future<List<Map<String, dynamic>>> safeList(String ep) async {
  try {
    return await Api.list(ep);
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

void snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

double num2(dynamic v) => ((v ?? 0) as num).toDouble();
bool isTrue(dynamic v) => v == 1 || v == true;
String todayIso() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Horodatage SQLite (« AAAA-MM-JJ HH:MM:SS », en UTC) → « AAAA-MM-JJ HH:MM » à l'heure locale.
String localStamp(dynamic utc) {
  final d = DateTime.tryParse('${'${utc ?? ''}'.replaceFirst(' ', 'T')}Z')?.toLocal();
  if (d == null) return '${utc ?? ''}';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// "Aujourd'hui" / "Demain" / nom du jour, selon l'indice de jour (0 = lundi).
String dayLabel(int day) {
  final k = (day - (DateTime.now().weekday - 1) + 7) % 7;
  return k == 0 ? 'Aujourd\'hui' : (k == 1 ? 'Demain' : const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'][day % 7]);
}

/// État vide avec message et bouton d'action optionnel.
class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? cta;
  final VoidCallback? onTap;
  const Empty(this.icon, this.text, {super.key, this.cta, this.onTap});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (cta != null) ...[const SizedBox(height: 12), FilledButton.tonal(onPressed: onTap, child: Text(cta!))],
          ]),
        ),
      );
}

/// Chargement / erreur avec bouton Réessayer / contenu.
class AsyncBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget Function() builder;
  const AsyncBody({super.key, required this.loading, required this.error, required this.onRetry, required this.builder});
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Empty(Icons.wifi_off, error!, cta: 'Réessayer', onTap: onRetry);
    return builder();
  }
}

/// Boîte de confirmation (renvoie true si l'utilisateur confirme).
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
    ) ==
    true;

/// Exécute un appel réseau et affiche l'erreur éventuelle ; renvoie true en cas de succès.
Future<bool> attempt(BuildContext context, Future<void> Function() f, {String? success}) async {
  try {
    await f();
    if (success != null && context.mounted) snack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) snack(context, '$e');
    return false;
  }
}

/// Cloche des notifications avec pastille du nombre de non lues.
class NotificationBell extends StatefulWidget {
  final Widget Function() page;
  const NotificationBell({super.key, required this.page});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    Api.refreshUnread();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Api.unread,
        builder: (_, n, _) => IconButton(
          tooltip: 'Notifications',
          icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(n > 0 ? Icons.notifications_active : Icons.notifications_none)),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => widget.page()));
            Api.refreshUnread();
          },
        ),
      );
}

Widget sectionTitle(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(t, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    );

Widget kpiCard(BuildContext c, IconData i, String label, String value, {Color? color}) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: color ?? Theme.of(c).colorScheme.primary),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(c).textTheme.bodySmall),
        ]),
      ),
    );

/// Grille d'indicateurs : colonnes adaptées à la largeur, hauteur fixe (pas de débordement sur écran étroit).
Widget kpiGrid(List<Widget> children) => GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: 132),
      children: children,
    );

Future<String?> pickMethod(BuildContext context, String title) {
  String v = payMethods.first;
  return showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(title),
        content: DropdownButton<String>(
          value: v, isExpanded: true,
          items: [for (final e in payMethods) DropdownMenuItem(value: e, child: Text(e))],
          onChanged: (x) => set(() => v = x!),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, v), child: const Text('Confirmer')),
        ],
      ),
    ),
  );
}

/// Histogramme simple (revenus par mois).
class BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color, textColor;
  BarsPainter(this.labels, this.values, this.color, this.textColor);

  void _text(Canvas c, String t, double cx, double y) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: textColor, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(cx - tp.width / 2, y));
  }

  @override
  void paint(Canvas c, Size s) {
    if (values.isEmpty) return;
    var mx = values.reduce((a, b) => a > b ? a : b);
    if (mx == 0) mx = 1;
    final w = s.width / values.length, ch = s.height - 32;
    for (var i = 0; i < values.length; i++) {
      final h = ch * values[i] / mx;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.2, ch - h + 14, w * 0.6, h), const Radius.circular(6)), Paint()..color = color);
      _text(c, values[i].toStringAsFixed(0), i * w + w / 2, ch - h);
      _text(c, labels[i], i * w + w / 2, s.height - 14);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

/// Courbe simple (évolution du poids).
class LinePainter extends CustomPainter {
  final List<double> v;
  final Color color, textColor;
  LinePainter(this.v, this.color, this.textColor);

  @override
  void paint(Canvas c, Size s) {
    if (v.length < 2) return;
    final mn = v.reduce((a, b) => a < b ? a : b), mx = v.reduce((a, b) => a > b ? a : b);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);
    const pad = 26.0;
    final pts = [
      for (var i = 0; i < v.length; i++) Offset(pad + (s.width - 2 * pad) * i / (v.length - 1), pad + (s.height - 2 * pad) * (1 - (v[i] - mn) / range)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3);
    for (var i = 0; i < pts.length; i++) {
      c.drawCircle(pts[i], 4.5, Paint()..color = color);
      final tp = TextPainter(text: TextSpan(text: v[i].toStringAsFixed(1), style: TextStyle(color: textColor, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(pts[i].dx - tp.width / 2, pts[i].dy - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
