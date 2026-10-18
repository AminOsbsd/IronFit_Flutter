import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/module.dart';
import '../widgets/common_widgets.dart';
import 'admin_screens.dart';
import 'auth_screen.dart';
import 'coach_screens.dart';
import 'crud_screen.dart';
import 'member_screens.dart';
import 'planning_screen.dart';

/// Navigation selon le rôle :
///  - Membre                 : Accueil · Planning · Explorer · Mon espace · Profil
///  - Coach « Mon entraînement » : identique au membre (un coach est aussi membre)
///  - Coach « Espace coach »      : Accueil · Planning · Clients · Gestion · Profil
///  - Admin (administration)      : Accueil · Planning · Administration · Profil
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const _home = NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil');
  static const _plan = NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Planning');
  static const _prof = NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil');

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Workspace>(
      valueListenable: Api.workspace,
      builder: (context, ws, _) {
        final List<Widget> pages;
        final List<NavigationDestination> dests;
        if (Api.isAdmin) {
          pages = const [AdminHome(), PlanningPage(manage: true), ModulesGrid(), ProfilePage()];
          dests = const [_home, _plan, NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Administration'), _prof];
        } else if (Api.inCoachSpace) {
          pages = const [CoachHome(), PlanningPage(manage: true), ClientsPage(), ModulesGrid(), ProfilePage()];
          dests = const [
            _home, _plan,
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Clients'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Gestion'),
            _prof,
          ];
        } else {
          pages = [MemberHome(goTab: go), const PlanningPage(), const ExplorePage(), const MySpacePage(), const ProfilePage()];
          dests = const [
            _home, _plan,
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Mon espace'),
            _prof,
          ];
        }
        if (tab >= pages.length) tab = 0;
        return Scaffold(
          // La clé force la reconstruction des pages quand le coach change d'espace
          body: KeyedSubtree(key: ValueKey('${Api.role}-${ws.name}-$tab'), child: pages[tab]),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            if (Api.isCoach) WorkspaceSwitch(onChanged: () => setState(() => tab = 0)),
            NavigationBar(selectedIndex: tab, onDestinationSelected: go, destinations: dests),
          ]),
        );
      },
    );
  }
}

/// Bascule entre l'entraînement personnel du coach et son espace professionnel.
class WorkspaceSwitch extends StatelessWidget {
  final VoidCallback onChanged;
  const WorkspaceSwitch({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<Workspace>(
              segments: const [
                ButtonSegment(value: Workspace.personal, icon: Icon(Icons.fitness_center), label: Text('Mon entraînement')),
                ButtonSegment(value: Workspace.coach, icon: Icon(Icons.sports), label: Text('Espace coach')),
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

// ---------------- Administration (admin) / Gestion (coach) ----------------
class ModulesGrid extends StatelessWidget {
  const ModulesGrid({super.key});

  Widget tile(BuildContext context, IconData icon, String title, Widget page) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Paiements : en gestion, réservé à l'admin (le coach consulte les siens dans « Mon entraînement »)
    final list = modules.where((m) => m.read.contains(Api.role) && (Api.isAdmin || m.write.contains(Api.role))).toList();
    return Scaffold(
      appBar: AppBar(title: Text(Api.isAdmin ? 'Administration' : 'Gestion')),
      body: GridView.extent(
        padding: const EdgeInsets.all(12), maxCrossAxisExtent: 240, childAspectRatio: 1.35, mainAxisSpacing: 6, crossAxisSpacing: 6,
        children: [
          if (Api.isAdmin) ...[
            tile(context, Icons.assignment_ind, 'Demandes d\'abonnement', const RequestsPage()),
            tile(context, Icons.handshake, 'Suivis coaching', const CoachingAdminPage()),
          ],
          for (final m in list) tile(context, m.icon, m.title, CrudPage(m)),
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
    final me = Api.me!;
    final n = TextEditingController(text: '${me['name']}'), e = TextEditingController(text: '${me['email']}'), p = TextEditingController(text: '${me['phone'] ?? ''}');
    final s = TextEditingController(text: '${me['specialty'] ?? ''}');
    String? err;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Mes informations'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Nom complet')),
              TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
              if (Api.isCoach) TextField(controller: s, decoration: const InputDecoration(labelText: 'Spécialité (visible par les membres)')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  final r = await Api.call('PUT', 'profile', {'name': n.text, 'email': e.text, 'phone': p.text, if (Api.isCoach) 'specialty': s.text});
                  Api.me = Map<String, dynamic>.from(r as Map);
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
            TextField(controller: o, obscureText: true, decoration: const InputDecoration(labelText: 'Ancien mot de passe')),
            TextField(controller: n, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau (6 car. min.)')),
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Vos autres appareils seront déconnectés.', style: TextStyle(fontSize: 12))),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (n.text.length < 6) return set(() => err = '6 caractères minimum');
                try {
                  final r = await Api.call('POST', 'password', {'old': o.text, 'new': n.text});
                  // Le serveur révoque les anciens jetons et renvoie celui de cette session
                  await Api.setToken((r as Map)['token'] as String);
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

  @override
  Widget build(BuildContext context) {
    final me = Api.me!;
    final roleText = Api.isCoach ? 'Coach · membre${me['specialty'] == null ? '' : ' · ${me['specialty']}'}' : (roleLabels[me['role']] ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${me['name']}'.isEmpty ? '?' : '${me['name']}'[0].toUpperCase())),
            title: Text('${me['name']}'),
            subtitle: Text('$roleText · @${me['login']}\n${me['email']}${(me['phone'] ?? '') == '' ? '' : '\n${me['phone']}'}'),
            isThreeLine: true,
          ),
        ),
        Card(child: ListTile(leading: const Icon(Icons.edit), title: const Text('Modifier mes informations'), onTap: _edit)),
        Card(child: ListTile(leading: const Icon(Icons.lock), title: const Text('Changer le mot de passe'), onTap: _changePw)),
        Card(child: ListTile(leading: const Icon(Icons.dns), title: const Text('Adresse du serveur'), subtitle: Text(Api.base), onTap: () async { await serverDialog(context); if (mounted) setState(() {}); })),
        Card(child: ListTile(leading: const Icon(Icons.logout), title: const Text('Se déconnecter'), onTap: () => Api.logout())),
      ]),
    );
  }
}
