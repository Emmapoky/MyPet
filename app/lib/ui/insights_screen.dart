import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config/thresholds.dart';
import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/flag_card.dart';
import 'widgets/pet_bar.dart';
import 'wording.dart';

/// Insights (report Table 4.4 screen 6): 7 or 30 days, the pet's normal against today,
/// change noticed. Hidden before 7 logged days (NFR07).
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int range = 7;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pet = s.selectedPet;
    final t = Theme.of(context);
    final result = pet == null ? null : s.detectionOf(pet.id);

    Widget body;
    if (pet == null) {
      body = const EmptyState(
          icon: Icons.insights, title: 'No pet yet', body: 'Add a pet to see insights.');
    } else if (result == null || !result.ready) {
      final have = result?.loggedDays ?? 0;
      final left = Thresholds.minLoggedDays - have;
      body = EmptyState(
        icon: Icons.hourglass_empty,
        title: 'Insights start after ${Thresholds.minLoggedDays} logged days',
        body: 'MyPet needs a week to learn what is normal for ${pet.name}. '
            '$have of ${Thresholds.minLoggedDays} days logged, $left to go.',
      );
    } else {
      final logs = s.timelineOf(pet.id).ofKind(EntryKind.dailyLog);
      final byDay = <Day, CareEntry>{};
      for (final e in logs.reversed) {
        byDay[e.day] = e; // newest per day wins
      }
      final today = s.today;
      final days = [for (var i = range - 1; i >= 0; i--) today.addDays(-i)];
      final baseFrom = today.addDays(-(Thresholds.recentDays + Thresholds.baselineDays - 1));
      final baseTo = today.addDays(-Thresholds.recentDays);
      final baseline = [
        for (final e in byDay.entries)
          if (!e.key.isBefore(baseFrom) && !e.key.isAfter(baseTo)) e.value
      ];
      final energies = [for (final e in baseline) if (e.energy != null) e.energy!.toDouble()];
      final usualEnergy = energies.isEmpty ? null : ChangeDetector.median(energies);
      int count(bool? Function(CareEntry) f, bool v) =>
          baseline.where((e) => f(e) == v).length;
      final todayLog = byDay[today];

      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {range},
          onSelectionChanged: (v) => setState(() => range = v.first),
        ),
        const SectionTitle('Changes'),
        if (result.flags.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: t.colorScheme.primary),
              title: Text('No change noticed'),
              subtitle: Text("${pet.name}'s last 3 days look like their usual."),
            ),
          )
        else
          for (final f in result.flags) ...[
            FlagCard(flag: f, pet: pet, expanded: true),
            const SizedBox(height: Tokens.space3),
          ],
        SectionTitle('Energy, last $range days'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: _EnergyChart(
              days: days,
              values: [for (final d in days) byDay[d]?.energy],
              usual: usualEnergy,
              today: today,
            ),
          ),
        ),
        SectionTitle("${pet.name}'s normal against today"),
        Card(
          child: Column(children: [
            _NormalRow(
              label: 'Energy',
              usual: usualEnergy == null ? '—' : '${usualEnergy.toStringAsFixed(1)} of 5',
              today: todayLog?.energy == null ? 'not logged' : '${todayLog!.energy} of 5',
            ),
            _NormalRow(
              label: 'Ate',
              usual: 'Yes on ${count((e) => e.ate, true)} of ${baseline.length} days',
              today: todayLog?.ate == null ? 'not logged' : (todayLog!.ate! ? 'Yes' : 'No'),
            ),
            _NormalRow(
              label: 'Toileting normal',
              usual:
                  'Yes on ${count((e) => e.toiletingNormal, true)} of ${baseline.length} days',
              today: todayLog?.toiletingNormal == null
                  ? 'not logged'
                  : (todayLog!.toiletingNormal! ? 'Yes' : 'No'),
            ),
          ]),
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          'Compared only with ${pet.name}\'s own logs from ${Wording.shortDate(baseFrom)} '
          'to ${Wording.shortDate(baseTo)}. ${Wording.notDiagnosis}',
          style: t.textTheme.bodySmall,
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const PetSwitcher(), actions: const [SyncBadge()]),
      body: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [body]),
    );
  }
}

class _NormalRow extends StatelessWidget {
  const _NormalRow({required this.label, required this.usual, required this.today});
  final String label, usual, today;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        subtitle: Text('Usual: $usual\nToday: $today'),
        isThreeLine: true,
      );
}

/// Energy per day as dots joined by a line, with the usual level as a dashed line.
class _EnergyChart extends StatelessWidget {
  const _EnergyChart(
      {required this.days, required this.values, required this.usual, required this.today});
  final List<Day> days;
  final List<int?> values;
  final double? usual;
  final Day today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final logged = values.whereType<int>().length;
    final label = 'Energy chart. $logged of ${days.length} days logged.'
        '${usual == null ? '' : ' Usual level ${usual!.toStringAsFixed(1)} of 5.'}'
        ' ${[for (var i = 0; i < days.length; i++) if (values[i] != null) '${Wording.shortDate(days[i])}: ${values[i]}'].join(', ')}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _EnergyPainter(
              values: values,
              usual: usual,
              line: t.colorScheme.primary,
              guide: t.colorScheme.outlineVariant,
              usualColor: t.colorScheme.tertiary,
            ),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(Wording.shortDate(days.first), style: t.textTheme.bodySmall),
          if (usual != null)
            Text('- - usual ${usual!.toStringAsFixed(1)}', style: t.textTheme.bodySmall),
          Text('Today', style: t.textTheme.bodySmall),
        ]),
      ]),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter(
      {required this.values,
      required this.usual,
      required this.line,
      required this.guide,
      required this.usualColor});
  final List<int?> values;
  final double? usual;
  final Color line, guide, usualColor;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double v) => size.height - (v - 1) / 4 * size.height;
    double x(int i) => values.length == 1 ? size.width / 2 : i / (values.length - 1) * size.width;
    final g = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (var v = 1; v <= 5; v++) {
      canvas.drawLine(Offset(0, y(v.toDouble())), Offset(size.width, y(v.toDouble())), g);
    }
    if (usual != null) {
      final p = Paint()
        ..color = usualColor
        ..strokeWidth = 2;
      for (double sx = 0; sx < size.width; sx += 10) {
        canvas.drawLine(Offset(sx, y(usual!)), Offset(sx + 5, y(usual!)), p);
      }
    }
    final lp = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = line;
    Offset? prev;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        prev = null; // a missed day leaves a gap, never a zero (report 4.4)
        continue;
      }
      final o = Offset(x(i), y(v.toDouble()));
      if (prev != null) canvas.drawLine(prev, o, lp);
      canvas.drawCircle(o, values.length > 10 ? 3 : 5, dot);
      prev = o;
    }
  }

  @override
  bool shouldRepaint(_EnergyPainter old) => old.values != values || old.usual != usual;
}
