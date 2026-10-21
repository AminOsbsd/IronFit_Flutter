import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/brand.dart';
import '../models/module.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import 'admin_screens.dart';
import 'auth_screen.dart';
import 'coach_screens.dart';
import 'crud_screen.dart';
import 'member_screens.dart';
import 'planning_screen.dart';

/// Navigation selon le rôle :
///  - Membre                      : Accueil · Planning · Explorer · Mon espace · Profil
///  - Coach « Mon entraînement »  : identique au membre (un coach est aussi membre)
///  - Coach « Espace coach »      : Accueil · Planning · Clients · Gestion · Profil
///  - Admin (administration)      : Accueil · Planning · Administration · Profil
/// Écran étroit : barre de navigation en bas. Écran large (≥ 900 px) : rail latéral avec le logo.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Dest {
  final IconData icon, selected;
  final String label;
  const _Dest(this.icon, this.selected, this.label);
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const _home = _Dest(Icons.home_outlined, Icons.home_rounded, 'Accueil');
  static const _plan = _Dest(Icons.event_outlined, Icons.event_rounded, 'Planning');
  static const _prof = _Dest(Icons.person_outline_rounded, Icons.person_rounded, 'Profil');

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Workspace>(
      valueListenable: Api.workspace,
      builder: (context, ws, _) {
        final List<Widget> pages;
        final List<_Dest> dests;
        if (Api.isAdmin) {
          pages = const [AdminHome(), PlanningPage(manage: true), ModulesGrid(), ProfilePage()];
          dests = const [_home, _plan, _Dest(Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded, 'Administration'), _prof];
        } else if (Api.inCoachSpace) {
          pages = const [CoachHome(), PlanningPage(manage: true), ClientsPage(), ModulesGrid(), ProfilePage()];
          dests = const [_home, _plan, _Dest(Icons.groups_outlined, Icons.groups_rounded, 'Clients'), _Dest(Icons.apps_outlined, Icons.apps_rounded, 'Gestion'), _prof];
        } else {
          pages = [MemberHome(goTab: go), const PlanningPage(), const ExplorePage(), const MySpacePage(), const ProfilePage()];
          dests = const [_home, _plan, _Dest(Icons.explore_outlined, Icons.explore_rounded, 'Explorer'), _Dest(Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Mon espace'), _prof];
        }
        if (tab >= pages.length) tab = 0;
        // La clé force la reconstruction des pages quand le coach change d'espace
        final body = KeyedSubtree(key: ValueKey('${Api.role}-${ws.name}-$tab'), child: pages[tab]);
        final width = MediaQuery.sizeOf(context).width;

        if (width >= 900) {
          final extended = width >= 1200;
          return Scaffold(
            body: Row(children: [
              NavigationRail(
                extended: extended,
                minExtendedWidth: 220,
                selectedIndex: tab,
                onDestinationSelected: go,
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Column(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: BrandLogo(size: extended ? 132 : 72)),
                    if (Api.isCoach) ...[const SizedBox(height: 12), _RailWorkspaceToggle(extended: extended, onChanged: () => setState(() => tab = 0))],
                  ]),
                ),
                destinations: [for (final d in dests) NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label))],
              ),
              VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
              Expanded(child: body),
            ]),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            if (Api.isCoach) WorkspaceSwitch(onChanged: () => setState(() => tab = 0)),
            NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: go,
              destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label)],
            ),
          ]),
        );
      },
    );
  }
}

/// Bascule entre l'entraînement personnel du coach et son espace professionnel (écran étroit).
class WorkspaceSwitch extends StatelessWidget {
  final VoidCallback onChanged;
  const WorkspaceSwitch({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? cs.surfaceContainerLow : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<Workspace>(
            segments: const [
              ButtonSegment(value: Workspace.personal, icon: Icon(Icons.fitness_center_rounded), label: Text('Mon entraînement')),
              ButtonSegment(value: Workspace.coach, icon: Icon(Icons.sports_rounded), label: Text('Espace coach')),
            ],
            selected: {Api.workspace.value},
            onSelectionChanged: (s) async {
              await Api.setWorkspace(s.first);
              onChanged();
            },
          ),
        ),
      ),
    );
  }
}

/// Même bascule, version verticale pour le rail latéral.
class _RailWorkspaceToggle extends StatelessWidget {
  final bool extended;
  final VoidCallback onChanged;
  const _RailWorkspaceToggle({required this.extended, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    Widget item(Workspace w, IconData icon, String label) {
      final selected = Api.workspace.value == w;
      final style = selected
          ? FilledButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))
          : FilledButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
      final onTap = selected
          ? null
          : () async {
              await Api.setWorkspace(w);
              onChanged();
            };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: label,
          child: SizedBox(
            width: extended ? 196 : 64,
            child: FilledButton(
              style: style.copyWith(foregroundColor: WidgetStatePropertyAll(selected ? AppColors.ink : Theme.of(context).colorScheme.onSurfaceVariant)),
              onPressed: onTap ?? () {},
              child: Row(mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                Icon(icon, size: 20),
                if (extended) ...[const SizedBox(width: 10), Flexible(child: Text(label, overflow: TextOverflow.ellipsis))],
              ]),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      item(Workspace.personal, Icons.fitness_center_rounded, 'Mon entraînement'),
      item(Workspace.coach, Icons.sports_rounded, 'Espace coach'),
    ]);
  }
}

// ---------------- Administration (admin) / Gestion (coach) ----------------
class ModulesGrid extends StatelessWidget {
  const ModulesGrid({super.key});

  Widget tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconBadge(icon),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paiements : en gestion, réservé à l'admin (le coach consulte les siens dans « Mon entraînement »)
    final list = modules.where((m) => m.read.contains(Api.role) && (Api.isAdmin || m.write.contains(Api.role))).toList();
    return Scaffold(
      appBar: AppBar(title: Text(Api.isAdmin ? 'Administration' : 'Gestion')),
      body: GridView.extent(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        maxCrossAxisExtent: 230,
        childAspectRatio: 1.25,
        mainAxisSpacing: 6,
        crossAxisSpacing: 8,
        children: [
          if (Api.isAdmin) ...[
            tile(context, Icons.assignment_ind_rounded, 'Demandes d\'abonnement', 'Valider les paiements', const RequestsPage()),
            tile(context, Icons.handshake_rounded, 'Suivis coaching', 'Relations coach / client', const CoachingAdminPage()),
          ],
          for (final m in list) tile(context, m.icon, m.title, m.write.contains(Api.role) ? 'Consulter et modifier' : 'Consulter', CrudPage(m)),
        ],
      ),
    );
  }
}

// ---------------- Profil ----------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _edit() async {
    final me = Api.user!;
    final n = TextEditingController(text: me.name), e = TextEditingController(text: me.email), p = TextEditingController(text: me.phone ?? '');
    final s = TextEditingController(text: me.specialty ?? '');
    String? err;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Mes informations'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.badge_outlined))),
              const SizedBox(height: 10),
              TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline))),
              const SizedBox(height: 10),
              TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined))),
              if (Api.isCoach) ...[
                const SizedBox(height: 10),
                TextField(controller: s, decoration: const InputDecoration(labelText: 'Spécialité (visible par les membres)', prefixIcon: Icon(Icons.sports_outlined))),
              ],
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  await AuthService.updateProfile(name: n.text, email: e.text, phone: p.text, specialty: Api.isCoach ? s.text : null);
                  if (d.mounted) Navigator.pop(d);
                  if (mounted) setState(() {});
                } catch (x) {
                  set(() => err = '$x');
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePw() async {
    final o = TextEditingController(), n = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: o, obscureText: true, decoration: const InputDecoration(labelText: 'Ancien mot de passe', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 10),
            TextField(controller: n, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau (6 car. min.)', prefixIcon: Icon(Icons.lock_reset_outlined))),
            const Padding(padding: EdgeInsets.only(top: 10), child: Text('Vos autres appareils seront déconnectés.', style: TextStyle(fontSize: 12))),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (n.text.length < 6) return set(() => err = '6 caractères minimum');
                try {
                  await AuthService.changePassword(o.text, n.text);
                  if (d.mounted) Navigator.pop(d);
                  if (mounted) snack(context, 'Mot de passe mis à jour');
                } catch (x) {
                  set(() => err = '$x');
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Widget action(IconData icon, String title, {String? subtitle, VoidCallback? onTap, Color? color}) => Card(
        child: ListTile(
          leading: IconBadge(icon, color: color),
          title: Text(title, style: color == null ? null : TextStyle(color: color, fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = Api.user!;
    final roleText = me.isCoach ? 'Coach · membre${me.specialty == null ? '' : ' · ${me.specialty}'}' : (roleLabels[me.role] ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        HeroCard(
          child: Row(children: [
            InitialAvatar(me.name, radius: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('@${me.login} · $roleText', style: const TextStyle(color: Colors.white70)),
                Text(me.email, style: const TextStyle(color: Colors.white70)),
                if ((me.phone ?? '').isNotEmpty) Text(me.phone!, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SectionHeader('Compte'),
        action(Icons.edit_outlined, 'Modifier mes informations', onTap: _edit),
        action(Icons.lock_outline, 'Changer le mot de passe', onTap: _changePw),
        const SectionHeader('Application'),
        action(Icons.dns_outlined, 'Adresse du serveur', subtitle: Api.base, onTap: () async {
          await serverDialog(context);
          if (mounted) setState(() {});
        }),
        action(Icons.logout_rounded, 'Se déconnecter', color: Theme.of(context).colorScheme.error, onTap: () => AuthService.logout()),
      ]),
    );
  }
}
