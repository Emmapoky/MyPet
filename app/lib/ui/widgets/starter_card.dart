import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/life_stage.dart';
import '../../models/pet.dart';
import '../../util/day.dart';
import '../theme.dart';
import 'common.dart';

/// "Getting to know Coco" (pet owner review, layer 1): what is typical for a pet of this
/// species, age and size, from the profile. Context only, never a flag or a judgement.
class StarterCard extends StatelessWidget {
  const StarterCard({super.key, required this.pet, required this.today, this.weightKg, this.learning = true, this.onEdit});
  final Pet pet;
  final Day today;

  /// The latest logged weight, else the profile weight.
  final double? weightKg;

  /// Still in the first 7 days, so say when MyPet learns the pet's own normal.
  final bool learning;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final lines = starterLines(pet, today, weightKg: weightKg, learning: learning);
    return MyCard(
      title: learning ? 'Getting to know ${pet.name}' : 'What is typical for ${pet.name}',
      accent: c.petAccent(pet),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines.body)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: Text(l, style: t.textTheme.bodyLarge),
          ),
        if (lines.missing.isNotEmpty && onEdit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_rounded),
              label: Text('Add ${lines.missing.join(' and ')}'),
              onPressed: onEdit,
            ),
          ),
        Text(lines.source, style: t.textTheme.bodySmall),
      ]),
    );
  }
}

/// The card's sentences, kept apart from the widget so they can be tested and reviewed.
({List<String> body, List<String> missing, String source}) starterLines(Pet pet, Day today,
    {double? weightKg, bool learning = true}) {
  final l = lifeStageOf(pet, today);
  final dog = pet.species == Species.dog;
  final kind = switch (l.stage) {
    LifeStage.baby || LifeStage.growing => dog ? 'puppy' : 'kitten',
    LifeStage.senior => dog ? 'older dog' : 'older cat',
    _ => dog ? 'adult dog' : 'adult cat',
  };
  final m = l.months;
  final age = m == null
      ? null
      : m < 24
          ? '$m months'
          : '${m ~/ 12} years';
  final about = pet.birthEstimated ? 'about ' : '';
  final size = l.size == null ? '' : ', ${sizeClassShort(l.size!)} size';
  final body = <String>[
    if (age != null) '${pet.name} is a $kind, $about$age old$size.',
    switch (l.stage) {
      LifeStage.baby => '${dog ? 'Puppies' : 'Kittens'} this young usually eat 3 to 4 small meals a day and gain weight every week.',
      LifeStage.growing => (m ?? 0) < 6
          ? '${dog ? 'Puppies' : 'Kittens'} this age usually eat about 3 meals a day and keep gaining weight.'
          : 'Still growing, so weight should keep going up slowly. Most eat 2 to 3 meals a day.',
      LifeStage.senior => 'Older pets can change slowly. A weekly weigh-in helps MyPet notice a slow change.',
      LifeStage.adult => 'Most adult ${dog ? 'dogs' : 'cats'} do well on 2 meals a day, with a steady weight.',
      null => '',
    },
  ].where((x) => x.isNotEmpty).toList();
  final need = dailyEnergyNeed(pet, today, weightKg: weightKg);
  if (need != null) {
    final (lo, hi) = need;
    final kg = (weightKg ?? pet.weightKg)!;
    final range = lo == hi ? 'about $lo' : '$lo to $hi';
    body.add('A rough daily energy need for ${NumberFormat('0.0').format(kg)} kg is $range kcal. '
        'Check the food bag for the amount in your own units.');
  }
  if (pet.portion.isNotEmpty) {
    body.add('Usual portion: ${pet.portion}${pet.mealsPerDay == null ? '' : ', ${pet.mealsPerDay} ${pet.mealsPerDay == 1 ? 'meal' : 'meals'} a day'}.');
  }
  if (learning) {
    body.add('After 7 days of logs, MyPet learns ${pet.name}\'s own normal and compares only with that.');
  }
  final missing = [
    if (pet.birthDate == null) 'age',
    if (weightKg == null && pet.weightKg == null) 'weight',
  ];
  return (
    body: body,
    missing: missing,
    source: 'From the AAHA 2021 and Pet Nutrition Alliance guides. A starting point, not a diagnosis.',
  );
}

/// Weight over time, one dot per weigh-in (review change 2). Change is shown as a fact.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.weights, required this.color});
  final List<(Day, double)> weights;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final f = DateFormat('d MMM');
    final first = weights.first, last = weights.last;
    final change = last.$2 - first.$2;
    final label = 'Weight from ${first.$2.toStringAsFixed(1)} kg on ${f.format(first.$1.asDateTime)} '
        'to ${last.$2.toStringAsFixed(1)} kg on ${f.format(last.$1.asDateTime)}, ${weights.length} weigh-ins';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _WeightPainter(weights, color, t.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(height: Tokens.space1),
        Row(children: [
          Text(f.format(first.$1.asDateTime), style: t.textTheme.bodySmall),
          const Spacer(),
          Text(f.format(last.$1.asDateTime), style: t.textTheme.bodySmall),
        ]),
        const SizedBox(height: Tokens.space2),
        Text(
          change.abs() < 0.05
              ? 'About the same: ${last.$2.toStringAsFixed(1)} kg'
              : '${last.$2.toStringAsFixed(1)} kg now, ${change.abs().toStringAsFixed(1)} kg '
                  '${change > 0 ? 'heavier' : 'lighter'} than on ${f.format(first.$1.asDateTime)}',
          style: t.textTheme.bodyLarge,
        ),
      ]),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.w, this.color, this.grid);
  final List<(Day, double)> w;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = w.map((x) => x.$2).reduce(math.min);
    final hi = w.map((x) => x.$2).reduce(math.max);
    final pad = math.max((hi - lo) * 0.2, 0.1);
    final span = math.max(1, w.last.$1.difference(w.first.$1));
    Offset at((Day, double) p) => Offset(
          8 + (size.width - 16) * p.$1.difference(w.first.$1) / span,
          size.height - 8 - (size.height - 16) * (p.$2 - (lo - pad)) / (hi - lo + 2 * pad),
        );
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 8 + (size.height - 16) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    final path = Path()..moveTo(at(w.first).dx, at(w.first).dy);
    for (final p in w.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    for (final p in w) {
      canvas.drawCircle(at(p), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.w != w || old.color != color;
}
