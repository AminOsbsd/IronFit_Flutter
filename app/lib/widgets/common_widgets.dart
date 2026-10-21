import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';

const dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const monthShort = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
const payMethods = ['Espèces', 'Carte', 'Virement', 'Chèque'];

// ---------------- Petites aides ----------------

void snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

double num2(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
bool isTrue(dynamic v) => v == true || v == 1;

String todayIso() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// « 2026-10-21T22:27:25Z » ou « 2026-10-21 » → « 2026-10-21 ».
String dateOnly(dynamic v) {
  final s = '${v ?? ''}';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Horodatage du serveur (ISO 8601, UTC) → « AAAA-MM-JJ HH:MM » à l'heure locale.
String localStamp(dynamic utc) {
  final s = '${utc ?? ''}';
  final d = DateTime.tryParse(s.contains('T') || s.endsWith('Z') ? s : '${s.replaceFirst(' ', 'T')}Z')?.toLocal();
  if (d == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// Montant : « 60 DT », « 12,50 DT ».
String money(dynamic v) {
  final n = num2(v);
  final s = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2).replaceAll('.', ',');
  return '$s DT';
}

/// "Aujourd'hui" / "Demain" / nom du jour, selon l'indice de jour (0 = lundi).
String dayLabel(int day) {
  final k = (day - (DateTime.now().weekday - 1) + 7) % 7;
  return k == 0 ? 'Aujourd\'hui' : (k == 1 ? 'Demain' : const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'][day % 7]);
}

// ---------------- États ----------------

/// État vide avec message et bouton d'action optionnel.
class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? cta;
  final VoidCallback? onTap;
  const Empty(this.icon, this.text, {super.key, this.cta, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.7), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          if (cta != null) ...[const SizedBox(height: 14), FilledButton(onPressed: onTap, child: Text(cta!))],
        ]),
      ),
    );
  }
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
    if (error != null) return Empty(Icons.wifi_off_rounded, error!, cta: 'Réessayer', onTap: onRetry);
    return builder();
  }
}

/// Boîte de confirmation (renvoie true si l'utilisateur confirme).
Future<bool> confirm(BuildContext context, String title, {String? body, String ok = 'Confirmer', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error, foregroundColor: Theme.of(d).colorScheme.onError) : null,
            onPressed: () => Navigator.pop(d, true),
            child: Text(ok),
          ),
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

// ---------------- Composants ----------------

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
    NotificationService.refreshUnread();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Api.unread,
        builder: (_, n, _) => IconButton(
          tooltip: 'Notifications',
          icon: Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: Icon(n > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded)),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => widget.page()));
            NotificationService.refreshUnread();
          },
        ),
      );
}

/// Titre de section, avec action optionnelle à droite.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?action,
        ]),
      );
}

Widget sectionTitle(BuildContext c, String t) => SectionHeader(t);

/// Indicateur chiffré : icône dans une pastille teintée, valeur, libellé.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final c = color ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.amber : AppColors.amberDeep);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: t.headlineSmall)),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

Widget kpiCard(BuildContext c, IconData i, String label, String value, {Color? color}) => StatTile(icon: i, label: label, value: value, color: color);

/// Grille d'indicateurs : colonnes adaptées à la largeur, hauteur fixe (pas de débordement sur écran étroit).
Widget kpiGrid(List<Widget> children) => GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: 158, crossAxisSpacing: 4),
      children: children,
    );

/// Carte « héros » sombre aux couleurs de la marque, avec le logo en filigrane.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Stack(children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: ExcludeSemantics(child: Image.asset(AppConfig.logoTransparent, width: 200, height: 200, color: Colors.white.withValues(alpha: 0.07), colorBlendMode: BlendMode.srcIn, cacheWidth: 400)),
          ),
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 5, decoration: const BoxDecoration(gradient: AppColors.amberGradient))),
          Padding(padding: padding, child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child)),
        ]),
      );
}

/// Petite étiquette colorée (statut).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill(this.label, {super.key, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Pastille ronde avec l'initiale.
class InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const InitialAvatar(this.name, {super.key, this.radius = 20});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
      );
}

/// Icône dans une pastille arrondie teintée (en-tête de ligne de liste).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconBadge(this.icon, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.amber : AppColors.amberDeep);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: c, size: 22),
    );
  }
}

Future<String?> pickMethod(BuildContext context, String title) {
  String v = payMethods.first;
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

// ---------------- Graphiques ----------------

/// Histogramme (revenus par mois) : barres arrondies en dégradé ambre.
class BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color, textColor;
  BarsPainter(this.labels, this.values, this.color, this.textColor);

  void _text(Canvas c, String t, double cx, double y, {bool bold = false}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: textColor, fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(cx - tp.width / 2, y));
  }

  @override
  void paint(Canvas c, Size s) {
    if (values.isEmpty) return;
    var mx = values.reduce((a, b) => a > b ? a : b);
    if (mx == 0) mx = 1;
    final w = s.width / values.length, ch = s.height - 34;
    for (var i = 0; i < values.length; i++) {
      final h = ch * values[i] / mx;
      final bw = (w * 0.56).clamp(8.0, 56.0); // largeur plafonnée : une seule barre ne remplit pas tout le graphique
      final rect = Rect.fromLTWH(i * w + (w - bw) / 2, ch - h + 16, bw, h);
      final paint = Paint()..shader = const LinearGradient(colors: [AppColors.amber, AppColors.ember], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect);
      c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
      _text(c, values[i].toStringAsFixed(0), i * w + w / 2, ch - h, bold: true);
      _text(c, labels[i], i * w + w / 2, s.height - 14);
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter old) => old.values != values || old.color != color || old.textColor != textColor;
}

/// Courbe (évolution du poids) avec aire en dégradé.
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
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, s.height - 6)
      ..lineTo(pts.first.dx, s.height - 6)
      ..close();
    c.drawPath(area, Paint()..shader = LinearGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Offset.zero & s));
    c.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < pts.length; i++) {
      c.drawCircle(pts[i], 5.5, Paint()..color = color);
      c.drawCircle(pts[i], 2.5, Paint()..color = Colors.white);
      final tp = TextPainter(text: TextSpan(text: v[i].toStringAsFixed(1), style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(pts[i].dx - tp.width / 2, pts[i].dy - 22));
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter old) => old.v != v || old.color != color || old.textColor != textColor;
}
