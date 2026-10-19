import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../admin/admin_home_page.dart';
import '../coach/clients_page.dart';
import '../coach/coach_home_page.dart';
import '../member/explore_page.dart';
import '../member/member_home_page.dart';
import '../member/my_space_page.dart';
import '../planning/planning_page.dart';
import '../profile/profile_page.dart';
import 'modules_grid.dart';

/// Navigation selon le rôle :
///  - Membre                     : Accueil · Planning · Explorer · Mon espace · Profil
///  - Coach « Mon entraînement » : identique au membre (un coach est aussi membre)
///  - Coach « Espace coach »     : Accueil · Planning · Clients · Gestion · Profil
///  - Admin                      : Accueil · Planning · Administration · Profil
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const _home = NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Accueil',
  );
  static const _plan = NavigationDestination(
    icon: Icon(Icons.event_outlined),
    selectedIcon: Icon(Icons.event),
    label: 'Planning',
  );
  static const _prof = NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Profil',
  );

  void go(int i) => setState(() => tab = i);

  (List<Widget>, List<NavigationDestination>) _layout() {
    if (Api.isAdmin) {
      return (
        const [AdminHome(), PlanningPage(manage: true), ModulesGrid(), ProfilePage()],
        const [
          _home,
          _plan,
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Administration',
          ),
          _prof,
        ],
      );
    }
    if (Api.inCoachSpace) {
      return (
        const [CoachHome(), PlanningPage(manage: true), ClientsPage(), ModulesGrid(), ProfilePage()],
        const [
          _home,
          _plan,
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Gestion'),
          _prof,
        ],
      );
    }
    return (
      [MemberHome(goTab: go), const PlanningPage(), const ExplorePage(), const MySpacePage(), const ProfilePage()],
      const [
        _home,
        _plan,
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
        NavigationDestination(
          icon: Icon(Icons.fitness_center_outlined),
          selectedIcon: Icon(Icons.fitness_center),
          label: 'Mon espace',
        ),
        _prof,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Workspace>(
      valueListenable: Api.workspace,
      builder: (context, ws, _) {
        final (pages, dests) = _layout();
        final current = tab < pages.length ? tab : 0;
        return Scaffold(
          // La clé force la reconstruction des pages quand le coach change d'espace
          body: KeyedSubtree(key: ValueKey('${Api.role}-${ws.name}-$current'), child: pages[current]),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Api.isCoach) WorkspaceSwitch(onChanged: () => setState(() => tab = 0)),
              NavigationBar(selectedIndex: current, onDestinationSelected: go, destinations: dests),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, 0),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          label: 'Espace affiché',
          child: SegmentedButton<Workspace>(
            segments: const [
              ButtonSegment(
                value: Workspace.personal,
                icon: Icon(Icons.fitness_center),
                label: Text('Mon entraînement'),
              ),
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
    ),
  );
}
