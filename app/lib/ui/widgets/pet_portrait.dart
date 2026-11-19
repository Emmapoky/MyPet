import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/pet.dart';

/// Flat illustration of a cat or dog face (three of each, from the design), used as the pet's picture until the
/// carer adds a photo. Each pet gets one of a few looks (fur colour and markings),
/// chosen from its id so it stays the same everywhere.
class PetPortrait extends StatelessWidget {
  const PetPortrait({super.key, required this.species, required this.seed, required this.background, this.size = 56});
  final Species species;
  final int seed;
  final Color background;
  final double size;

  factory PetPortrait.of(Pet p, {required Color background, double size = 56}) => PetPortrait(
        species: p.species,
        seed: p.id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff),
        background: background,
        size: size,
      );

  static const _cats = ['cat-1-ginger', 'cat-2-grey', 'cat-3-tuxedo'];
  static const _dogs = ['dog-1-golden', 'dog-2-spotted', 'dog-3-pointy'];

  /// The design's illustration for this pet (assets/illustrations, from the design thread).
  String get asset {
    final set = species == Species.cat ? _cats : _dogs;
    return 'assets/illustrations/${set[seed % set.length]}.svg';
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: ColoredBox(
            color: background,
            child: SvgPicture.asset(
              asset,
              fit: BoxFit.cover,
              // Drawn face as a stand-in while the illustration loads.
              placeholderBuilder: (_) => CustomPaint(painter: _FacePainter(species, seed, background)),
            ),
          ),
        ),
      );
}

class _Fur {
  const _Fur(this.main, this.dark, this.light);
  final Color main, dark, light;
}

const _catFur = [
  _Fur(Color(0xFFF0A65E), Color(0xFFD27F35), Color(0xFFFFF4E6)), // ginger
  _Fur(Color(0xFFA7ADBC), Color(0xFF7C8294), Color(0xFFF4F4F8)), // grey
  _Fur(Color(0xFF45404F), Color(0xFF2E2A36), Color(0xFFF6F2EE)), // black and white
  _Fur(Color(0xFFF3DCB8), Color(0xFFC9A67A), Color(0xFFFFFBF4)), // cream
];

const _dogFur = [
  _Fur(Color(0xFFDDA764), Color(0xFFB27C3B), Color(0xFFFFF3E2)), // golden
  _Fur(Color(0xFF94603F), Color(0xFF6B4129), Color(0xFFF5E6D8)), // brown
  _Fur(Color(0xFFF1E1C6), Color(0xFFC9AB80), Color(0xFFFFFCF6)), // cream
  _Fur(Color(0xFF3F3A46), Color(0xFF2A2630), Color(0xFFF3EEE8)), // black and white
];

const _ink = Color(0xFF2B2340);
const _pinkNose = Color(0xFFE88AA6);

class _FacePainter extends CustomPainter {
  _FacePainter(this.species, this.seed, this.background);
  final Species species;
  final int seed;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.scale(s, s); // draw in a 1 x 1 box
    if (species == Species.cat) {
      _cat(canvas);
    } else {
      _dog(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  void _eyes(Canvas c, double y, double dx, double r) {
    for (final x in [0.5 - dx, 0.5 + dx]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 1.7, height: r * 2.1), _fill(_ink));
      c.drawCircle(Offset(x + r * 0.3, y - r * 0.45), r * 0.35, _fill(Colors.white));
    }
  }

  void _cat(Canvas c) {
    final fur = _catFur[seed % _catFur.length];
    final tabby = (seed ~/ 4) % 2 == 0;
    // Ears
    for (final m in [1.0, -1.0]) {
      Offset p(double x, double y) => Offset(0.5 + m * (x - 0.5), y);
      c.drawPath(Path()
        ..moveTo(p(0.20, 0.50).dx, 0.50)
        ..lineTo(p(0.24, 0.16).dx, 0.16)
        ..lineTo(p(0.47, 0.36).dx, 0.36)
        ..close(), _fill(fur.main));
      c.drawPath(Path()
        ..moveTo(p(0.25, 0.43).dx, 0.43)
        ..lineTo(p(0.27, 0.24).dx, 0.24)
        ..lineTo(p(0.40, 0.36).dx, 0.36)
        ..close(), _fill(_pinkNose.withValues(alpha: 0.75)));
    }
    // Head
    c.drawOval(Rect.fromCenter(center: const Offset(0.5, 0.60), width: 0.66, height: 0.54), _fill(fur.main));
    if (tabby) {
      final stripe = _fill(fur.dark);
      for (final x in [0.44, 0.5, 0.56]) {
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 0.40), width: 0.035, height: 0.11),
                const Radius.circular(0.02)),
            stripe);
      }
    }
    // Muzzle
    c.drawOval(Rect.fromCenter(center: const Offset(0.5, 0.71), width: 0.30, height: 0.19), _fill(fur.light));
    _eyes(c, 0.58, 0.12, 0.042);
    // Nose and mouth
    c.drawPath(Path()
      ..moveTo(0.465, 0.655)
      ..lineTo(0.535, 0.655)
      ..lineTo(0.5, 0.695)
      ..close(), _fill(_pinkNose));
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    c.drawArc(Rect.fromCenter(center: const Offset(0.47, 0.71), width: 0.06, height: 0.05), 0, math.pi * 0.9, false, line);
    c.drawArc(Rect.fromCenter(center: const Offset(0.53, 0.71), width: 0.06, height: 0.05), math.pi * 0.1, math.pi * 0.9, false, line);
    final whisker = Paint()
      ..color = _ink.withValues(alpha: 0.45)
      ..strokeWidth = 0.008
      ..strokeCap = StrokeCap.round;
    for (final m in [1.0, -1.0]) {
      c.drawLine(Offset(0.5 + m * 0.13, 0.70), Offset(0.5 + m * 0.30, 0.67), whisker);
      c.drawLine(Offset(0.5 + m * 0.13, 0.73), Offset(0.5 + m * 0.30, 0.75), whisker);
    }
  }

  void _dog(Canvas c) {
    final fur = _dogFur[seed % _dogFur.length];
    final floppy = (seed ~/ 4) % 2 == 0;
    final spot = (seed ~/ 8) % 2 == 0;
    if (floppy) {
      for (final m in [1.0, -1.0]) {
        c.save();
        c.translate(0.5 + m * 0.27, 0.50);
        c.rotate(m * 0.35);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.20, height: 0.40), _fill(fur.dark));
        c.restore();
      }
    } else {
      for (final m in [1.0, -1.0]) {
        Offset p(double x, double y) => Offset(0.5 + m * (x - 0.5), y);
        c.drawPath(Path()
          ..moveTo(p(0.22, 0.44).dx, 0.44)
          ..quadraticBezierTo(p(0.20, 0.20).dx, 0.18, p(0.30, 0.16).dx, 0.16)
          ..lineTo(p(0.45, 0.32).dx, 0.32)
          ..close(), _fill(fur.main));
      }
    }
    // Head
    c.drawOval(Rect.fromCenter(center: const Offset(0.5, 0.56), width: 0.58, height: 0.60), _fill(fur.main));
    if (spot) {
      c.drawOval(Rect.fromCenter(center: const Offset(0.39, 0.51), width: 0.17, height: 0.16), _fill(fur.dark));
    }
    // Muzzle
    c.drawOval(Rect.fromCenter(center: const Offset(0.5, 0.70), width: 0.34, height: 0.25), _fill(fur.light));
    _eyes(c, 0.51, 0.11, 0.042);
    // Nose, mouth, tongue
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0.5, 0.645), width: 0.13, height: 0.085),
            const Radius.circular(0.04)),
        _fill(_ink));
    c.drawCircle(const Offset(0.478, 0.632), 0.012, _fill(Colors.white.withValues(alpha: 0.7)));
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(0.5, 0.685), const Offset(0.5, 0.72), line);
    c.drawArc(Rect.fromCenter(center: const Offset(0.465, 0.72), width: 0.07, height: 0.05), 0, math.pi * 0.9, false, line);
    c.drawArc(Rect.fromCenter(center: const Offset(0.535, 0.72), width: 0.07, height: 0.05), math.pi * 0.1, math.pi * 0.9, false, line);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0.5, 0.77), width: 0.07, height: 0.07),
            const Radius.circular(0.035)),
        _fill(_pinkNose));
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.seed != seed || old.species != species || old.background != background;
}
