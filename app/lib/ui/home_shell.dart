import 'speed_test_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'check_screen.dart';
import 'insights_screen.dart';
import 'pets_screen.dart';
import 'reminders_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'today_screen.dart';
import 'feedback.dart';
import 'guide.dart';

/// Bottom tabs, the same on every screen (report Fig 4.4 item 5; Figma "Bottom tabs").
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = [TodayScreen(), PetsScreen(), CheckScreen(), InsightsScreen(), RemindersScreen()];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context);
    // First time in the app: Pip the guide dog shows each tab once.
    if (!s.tourSeen && s.guide == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!s.tourSeen && s.guide == null) {
          s.startGuide(Guide(steps: tourSteps()));
        }
      });
    }
    // The guide (tour or demo story) floats above every page without blocking the app.
    return GuideHost(
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(index: s.tab, children: _pages),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(Tokens.space3, 0, Tokens.space3, Tokens.space2),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: t.colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: s.tab,
                  onDestinationSelected: (i) {
                    Feel.tap();
                    s.goToTab(i);
                  },
                  // Very large text: icons only (each still has its name for screen readers),
                  // so labels never get cut off.
                  labelBehavior: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? NavigationDestinationLabelBehavior.alwaysHide
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Today'),
                    NavigationDestination(icon: Icon(Icons.pets_rounded), label: 'Pets'),
                    NavigationDestination(icon: Icon(Icons.center_focus_strong_rounded), label: 'Check'),
                    NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Insights'),
                    NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Reminders'),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      } else if (i == -2) {
        final s = context.read<AppState>();
        s.goToTab(0);
        s.startGuide(Guide(steps: tourSteps()));
      } else if (i == -4) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
      } else if (i == -5) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpeedTestScreen()));
      } else if (i == -3) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DemoPickerScreen()));
      } else {
        extra[i].$2();
      }
    },
    itemBuilder: (_) => [
      for (var i = 0; i < extra.length; i++) PopupMenuItem(value: i, child: Text(extra[i].$1)),
      const PopupMenuItem(value: -2, child: Text('Show me around')),
      const PopupMenuItem(value: -3, child: Text('Try a demo')),
      const PopupMenuItem(value: -4, child: Text('Guide and FAQ')),
      const PopupMenuItem(value: -5, child: Text('Test this phone')),
      const PopupMenuItem(value: -1, child: Text('Settings')),
    ],
  );
}

/// One-tap light/dark switch. Opens light the first time; the choice is remembered.
class LookToggle extends StatelessWidget {
  const LookToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      icon: Icon(
        dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        Feel.tap();
        s.setLook(dark ? ThemeMode.light : ThemeMode.dark);
      },
    );
  }
}
