import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config/thresholds.dart';
import '../detection/change_detector.dart';
import '../models/care_entry.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'home_shell.dart';
import 'quick_log_screen.dart';
import 'theme.dart';
import 'vet_export.dart';
import 'widgets/common.dart';
import 'widgets/flag_card.dart';
import 'widgets/pet_bar.dart';

/// Insights (report Table 4.4 screen 6; Figma screens 05 and 06): 7 or 30 days, the pet's
/// usual against today, change noticed, export for the vet. Hidden before 7 days (NFR07).
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
    final result = pet == null ? null : s.detectionOf(pet.id);

    final List<Widget> children;
    if (pet == null) {
      children = const [
        EmptyState(icon: Icons.insights_rounded, title: 'No pet yet', body: 'Add a pet to see insights.'),
      ];
    } else if (result == null || !result.ready) {
      final have = result?.loggedDays ?? 0;
      children = [
        EmptyState(
          icon: Icons.hourglass_top_rounded,
          title: 'Insights unlock after ${Thresholds.minLoggedDays} days',
          body: '$have of ${Thresholds.minLoggedDays} days logged',
          extra: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: have / Thresholds.minLoggedDays,
              minHeight: 8,
              semanticsLabel: '$have of ${Thresholds.minLoggedDays} days logged',
            ),
          ),
          action: FilledButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Log now'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet))),
          ),
        ),
      ];
    } else {
      children = _ready(context, s, pet, result);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          const SyncBadge(),
          const MoreMenu(),
        ],
      ),
      body: PageWash(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space4, Tokens.space5),
          children: [
            if (pet != null && s.activePets.length > 1) ...[
              PetStrip(pets: s.activePets, selected: pet.id, onSelect: () {}),
              const SizedBox(height: Tokens.space4),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _ready(BuildContext context, AppState s, Pet pet, DetectionResult result) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final today = s.today;
    final byDay = <Day, CareEntry>{};
    for (final e in s.timelineOf(pet.id).ofKind(EntryKind.dailyLog).reversed) {
      byDay[e.day] = e; // newest per day wins
    }
    // Baseline as the detector sees it: the 28 days before the last 3 (FR13).
    final baseTo = today.addDays(-Thresholds.recentDays);
    final baseFrom = baseTo.addDays(-(Thresholds.baselineDays - 1));
    final base = [
      for (final e in byDay.entries)
        if (!e.key.isBefore(baseFrom) && !e.key.isAfter(baseTo)) e.value
    ];
    final energies = [for (final e in base) if (e.energy != null) e.energy!.toDouble()];
    double? med, spread;
    if (energies.isNotEmpty) {
      med = ChangeDetector.median(energies);
      final mad = ChangeDetector.median([for (final x in energies) (x - med).abs()]);
      spread = math.max(Thresholds.madScale * mad, Thresholds.minEnergySpread);
    }
    bool low(int? v) =>
        v != null && med != null && (v - med) / spread! < -Thresholds.scoreCutoff;

    final days = [for (var i = range - 1; i >= 0; i--) today.addDays(-i)];
    final todayLog = byDay[today];
    final ateYes = base.where((e) => e.ate == true).length;
    final ateKnown = base.where((e) => e.ate != null).length;
    final energyFlag = result.flags.any((f) => f.measure == Measure.energy);
    final ateFlag = result.flags.any((f) => f.measure == Measure.ate);

    return [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('7 days')),
          ButtonSegment(value: 30, label: Text('30 days')),
        ],
        selected: {range},
        onSelectionChanged: (v) => setState(() => range = v.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(Tokens.minTarget)),
      ),
      const SizedBox(height: Tokens.space4),
      if (result.flags.isEmpty)
        Container(
          padding: const EdgeInsets.all(Tokens.space4),
          decoration: BoxDecoration(
            color: c.loggedContainer,
            borderRadius: BorderRadius.circular(Tokens.radiusCard),
            border: Border(left: BorderSide(color: c.loggedEdge, width: Tokens.accentEdge)),
          ),
          child: Row(children: [
            Icon(Icons.verified_rounded, color: c.loggedEdge),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text('Everything looks like usual',
                  style: t.textTheme.bodyLarge!.copyWith(color: c.onLoggedContainer)),
            ),
          ]),
        )
      else
        for (final f in result.flags) ...[
          FlagCard(flag: f, pet: pet),
          const SizedBox(height: Tokens.space4),
        ],
      if (result.flags.isEmpty) const SizedBox(height: Tokens.space4),
      MyCard(
        title: "${pet.name}'s usual and today",
        accent: c.petAccent(pet.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _EnergyBars(
            days: days,
            values: [for (final d in days) byDay[d]?.energy],
            low: [for (final d in days) low(byDay[d]?.energy)],
            band: med == null
                ? null
                : ((med - spread!).clamp(1, 5).toDouble(), (med + spread).clamp(1, 5).toDouble()),
          ),
          const SizedBox(height: Tokens.space2),
          Row(children: [
            Container(
              width: 20,
              height: 12,
              decoration: BoxDecoration(
                color: t.colorScheme.primaryContainer,
                border: Border.all(color: t.colorScheme.primary),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: Tokens.space2),
            Text('Usual range (${Thresholds.baselineDays} days)', style: t.textTheme.bodySmall),
          ]),
          const SizedBox(height: Tokens.space3),
          _UsualRow(
            label: 'Energy',
            value: todayLog?.energy == null ? 'Not logged today' : '${todayLog!.energy} of 5',
            status: energyFlag || low(todayLog?.energy) ? 'Lower' : 'As usual',
            changed: energyFlag || low(todayLog?.energy),
          ),
          _UsualRow(
            label: 'Ate',
            value: ateKnown == 0
                ? '—'
                : ateYes == ateKnown
                    ? 'Every day'
                    : '$ateYes of $ateKnown days',
            status: ateFlag ? 'Less' : 'As usual',
            changed: ateFlag,
          ),
        ]),
      ),
      const SizedBox(height: Tokens.space3),
      Text(
        'Only compared with ${pet.name}, '
        '${DateFormat('d MMM').format(baseFrom.asDateTime)} to ${DateFormat('d MMM').format(baseTo.asDateTime)}',
        style: t.textTheme.bodySmall,
      ),
      const SizedBox(height: Tokens.space4),
      FilledButton.tonalIcon(
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Export for the vet'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Tokens.minTarget)),
        onPressed: () => showVetExport(context, pet),
      ),
    ];
  }
}

class _UsualRow extends StatelessWidget {
  const _UsualRow({required this.label, required this.value, required this.status, required this.changed});
  final String label, value, status;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    return Semantics(
      label: '$label: $value, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: t.textTheme.titleSmall)),
          Expanded(child: Text(value, style: t.textTheme.bodyLarge!.copyWith(color: t.colorScheme.onSurfaceVariant))),
          Text(status,
              style: t.textTheme.labelLarge!
                  .copyWith(color: changed ? c.onChangeContainer : c.onLoggedContainer)),
        ]),
      ),
    );
  }
}

/// Energy per day as bars over the usual range band (Figma Insights). A day that counts as
/// unusual for the detector is amber; a missed day is left empty, never zero (report 4.4).
class _EnergyBars extends StatelessWidget {
  const _EnergyBars({required this.days, required this.values, required this.low, required this.band});
  final List<Day> days;
  final List<int?> values;
  final List<bool> low;
  final (double, double)? band;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final few = days.length <= 7;
    final label = 'Energy for the last ${days.length} days. '
        '${[for (var i = 0; i < days.length; i++) '${DateFormat('EEE d MMM').format(days[i].asDateTime)}: ${values[i] ?? 'not logged'}${low[i] ? ', lower than usual' : ''}'].join('; ')}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(
              values: values,
              low: low,
              band: band,
              bar: t.colorScheme.primary,
              lowBar: c.onChangeContainer,
              bandColor: Theme.of(context).colorScheme.primaryContainer,
              empty: t.colorScheme.outlineVariant,
              barWidth: few ? 28 : null,
            ),
          ),
        ),
        const SizedBox(height: Tokens.space1),
        Row(children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: few || i % 7 == days.length % 7 - 1 || i == days.length - 1
                  ? Text(
                      few ? DateFormat.E().format(days[i].asDateTime) : DateFormat('d/M').format(days[i].asDateTime),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: t.textTheme.bodySmall,
                    )
                  : const SizedBox(),
            ),
        ]),
      ]),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.low,
    required this.band,
    required this.bar,
    required this.lowBar,
    required this.bandColor,
    required this.empty,
    this.barWidth,
  });
  final List<int?> values;
  final List<bool> low;
  final (double, double)? band;
  final Color bar, lowBar, bandColor, empty;
  final double? barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double v) => size.height - v / 5 * size.height;
    if (band != null) {
      canvas.drawRect(
        Rect.fromLTRB(0, y(band!.$2 + 0.25), size.width, y(band!.$1 - 0.25)),
        Paint()..color = bandColor,
      );
    }
    final slot = size.width / values.length;
    final w = math.min(barWidth ?? slot * 0.6, slot * 0.8);
    for (var i = 0; i < values.length; i++) {
      final cx = slot * (i + 0.5);
      final v = values[i];
      if (v == null) {
        canvas.drawCircle(Offset(cx, size.height - 3), 2.5, Paint()..color = empty);
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - w / 2, y(v.toDouble()), cx + w / 2, size.height),
          topLeft: Radius.circular(math.min(6, w / 2)),
          topRight: Radius.circular(math.min(6, w / 2)),
        ),
        Paint()..color = low[i] ? lowBar : bar,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
