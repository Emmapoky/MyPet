import 'package:material_ui/material_ui.dart';


/// Logo mark (Figma Components, top right): a teal tile with a white paw and an apricot
/// dot on the pad.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      label: 'MyPet',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0E6B73),
          borderRadius: BorderRadius.circular(size * 28 / 96),
        ),
        child: CustomPaint(painter: PawPainter(dot: s.secondary)),
      ),
    );
  }
}

class PawPainter extends CustomPainter {
  PawPainter({required this.dot, this.paw = Colors.white});
  final Color dot;
  final Color paw;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()..color = paw;
    void toe(double cx, double cy, double rx, double ry) => canvas.drawOval(
        Rect.fromCenter(center: Offset(cx * w, cy * w), width: rx * 2 * w, height: ry * 2 * w), p);
    toe(0.30, 0.42, 0.075, 0.09);
    toe(0.42, 0.29, 0.075, 0.095);
    toe(0.58, 0.29, 0.075, 0.095);
    toe(0.70, 0.42, 0.075, 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0.5 * w, 0.62 * w), width: 0.36 * w, height: 0.28 * w),
        Radius.circular(0.13 * w),
      ),
      p,
    );
    canvas.drawCircle(Offset(0.5 * w, 0.63 * w), 0.06 * w, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(PawPainter old) => old.dot != dot || old.paw != paw;
}
