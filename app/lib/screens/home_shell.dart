import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'athlete_screens.dart';
import 'auth_screen.dart';
import '../widgets/common_widgets.dart';
import 'crud_screen.dart';
import '../models/module.dart';
import 'planning_screen.dart';
import 'staff_screens.dart';

/// Navigation différente selon le rôle :
///  - Athlète : Accueil · Planning · Explorer · Mon espace · Profil
///  - Coach / Admin : Accueil (tableau de bord) · Planning · Modules (gestion) · Profil
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final ath = Api.role == 'athlete';
    final pages = ath
        ? <Widget>[AthleteHome(goTab: (i) => setState(() => tab = i)), const PlanningPage(), const ExplorePage(), const MySpacePage(), const ProfilePage()]
        : <Widget>[const StaffHome(), const PlanningPage(), const ModulesGrid(), const ProfilePage()];
    const home = NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil');
    const plan = NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Planning');
    const prof = NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil');
    final dests = ath
        ? const [
            home, plan,
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Mon espace'),
            prof,
          ]
        : const [
            home, plan,
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Gestion'),
            prof,
          ];
    if (tab >= pages.length) tab = 0;
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: dests),
    );
  }
}

// ---------------- Gestion (admin / coach) ----------------
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
    final list = modules.where((m) => m.read.contains(Api.role)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion')),
      body: GridView.count(
        padding: const EdgeInsets.all(12), crossAxisCount: 2, childAspectRatio: 1.35, mainAxisSpacing: 6, crossAxisSpacing: 6,
        children: [
          if (Api.role == 'admin') tile(context, Icons.assignment_ind, 'Demandes d\'abonnement', const RequestsPage()),
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
              if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  final r = await Api.call('PUT', 'profile', {'name': n.text, 'email': e.text, 'phone': p.text});
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
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(d).colorScheme.error))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.call('POST', 'password', {'old': o.text, 'new': n.text});
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
    const labels = {'admin': 'Administrateur', 'coach': 'Coach', 'athlete': 'Athlète'};
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${me['name']}'.isEmpty ? '?' : '${me['name']}'[0].toUpperCase())),
            title: Text('${me['name']}'),
            subtitle: Text('${labels[me['role']] ?? ''} · @${me['login']}\n${me['email']}${(me['phone'] ?? '') == '' ? '' : '\n${me['phone']}'}'),
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
