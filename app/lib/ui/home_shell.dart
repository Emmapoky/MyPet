import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'check_screen.dart';
import 'insights_screen.dart';
import 'pets_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

/// Bottom tabs, the same on every screen (report Fig 4.4 item 5; Figma "Bottom tabs").
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = [
    TodayScreen(),
    PetsScreen(),
    CheckScreen(),
    InsightsScreen(),
    RemindersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: s.tab, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: s.tab,
          onDestinationSelected: s.goToTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.pets_rounded), label: 'Pets'),
            NavigationDestination(icon: Icon(Icons.graphic_eq_rounded), label: 'Check'),
            NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Insights'),
            NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'Reminders'),
          ],
        ),
      ),
    );
  }
}

/// The trailing "more" menu in every top bar.
class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, this.extra = const []});
  final List<(String, VoidCallback)> extra;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: 'More',
        icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
        onSelected: (i) {
          if (i == -1) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          } else {
            extra[i].$2();
          }
        },
        itemBuilder: (_) => [
          for (var i = 0; i < extra.length; i++) PopupMenuItem(value: i, child: Text(extra[i].$1)),
          const PopupMenuItem(value: -1, child: Text('Settings')),
        ],
      );
}
