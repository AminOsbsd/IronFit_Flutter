import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../admin/coaching_admin_page.dart';
import '../admin/requests_page.dart';
import '../crud/crud_page.dart';
import '../crud/module.dart';
import '../crud/module_catalogue.dart';

/// Modules visibles dans « Administration » (admin) ou « Gestion » (coach) pour [role].
/// Paiements : en gestion, réservé à l'admin (le coach consulte les siens dans « Mon entraînement »).
List<Module> managedModules(String role) =>
    modules.where((m) => m.canRead(role) && (role == 'admin' || m.canWrite(role))).toList();

/// Onglet « Administration » (admin) / « Gestion » (coach) : une tuile par module.
class ModulesGrid extends StatelessWidget {
  const ModulesGrid({super.key});

  Widget tile(BuildContext context, IconData icon, String title, Widget page) => Card(
    child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)),
      child: Padding(
        padding: Gaps.page,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary)),
            Gaps.h8,
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Fixe (marge de carte, padding, icône, espacement : 74) + titre sur 2 lignes mis à l'échelle (46).
    final extent = 74 + MediaQuery.textScalerOf(context).scale(46);
    return Scaffold(
      appBar: AppBar(title: Text(Api.isAdmin ? 'Administration' : 'Gestion')),
      body: GridView(
        padding: Gaps.page,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisExtent: extent,
          mainAxisSpacing: Gaps.xs,
          crossAxisSpacing: Gaps.xs,
        ),
        children: [
          if (Api.isAdmin) ...[
            tile(context, Icons.assignment_ind, 'Demandes d\'abonnement', const RequestsPage()),
            tile(context, Icons.handshake, 'Suivis coaching', const CoachingAdminPage()),
          ],
          for (final m in managedModules(Api.role)) tile(context, m.icon, m.title, CrudPage(m)),
        ],
      ),
    );
  }
}
