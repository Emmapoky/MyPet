import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../behaviour/analysis.dart';
import '../behaviour/engine.dart';
import '../data/local_backend.dart';
import '../models/care_entry.dart';
import '../state/app_state.dart';
import '../state/demo_data.dart';
import 'feedback.dart';
import 'home_shell.dart';
import 'pet_detail_screen.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/pet_bar.dart';
import 'widgets/pet_portrait.dart';

/// First-run tour, told by Pip the guide dog. One bubble per tab.
List<GuideStep> tourSteps() => const [
      GuideStep(0, "Hi, I'm Pip! I'll show you around. Today is where you log your pet's day in three taps."),
      GuideStep(1, 'Pets holds each pet, with a photo and their records. Open a pet to share a PDF with your vet.'),
      GuideStep(2, 'Check films 5 to 10 seconds. Sound and picture are read on this phone, then the clip is deleted.'),
      GuideStep(3, "After 7 days of logs, Insights learns what's usual for your pet and points out changes."),
      GuideStep(4, "Reminders for food, medicine and walks. Anything missed shows on Today. That's it, have fun!"),
    ];

/// Story bubbles for one demo pet, told by the pet itself.
List<GuideStep> storySteps(AppState s, DemoPet d) {
  final pet = s.activePets.where((p) => p.name == d.name).firstOrNull;
  final days = pet == null
      ? 0
      : {for (final e in s.timelineOf(pet.id).ofKind(EntryKind.dailyLog)) e.day}.length;
  GuideStep step(int tab, String text, {String? target, GuideOpen open = GuideOpen.none}) =>
      GuideStep(tab, text, petName: d.name, target: target, open: open);
  return switch (d.id) {
    'demo-biscuit' => [
        step(0, "Woof! I'm Biscuit. Every evening my carer logs 3 things: did I eat, my energy, my toilet. Three taps.",
            target: 'log'),
        step(0, "They've logged $days days for me. MyPet needs 7 to learn what's usual for me. Before that it stays quiet.",
            target: 'stats'),
        step(0, 'This week I had low energy on 2 of the last 3 days. MyPet shows it in amber: a change from my usual, not a diagnosis.',
            target: 'flag'),
        step(3, 'Insights compares me only with my own usual range, the shaded band. The low bars are my flat days.',
            target: 'usual'),
        step(2, 'My carer just filmed me howling. Watch: MyPet reads the sound and the picture right here on the phone.',
            open: GuideOpen.check),
        step(1, 'My page keeps every check. Tap this one to replay it and hear each howl MyPet found.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(1, 'Before the vet, my carer taps this PDF button to share my record. Vet letters can be added too.',
            open: GuideOpen.petPage, target: 'pdf'),
        step(4, "And I never miss dinner. That's my story! Try another pet, or start with your own."),
      ],
    'demo-mochi' => [
        step(0, "Meow, I'm Mochi. I usually clear my bowl. This week I ate only some, then none. MyPet noticed.",
            target: 'flag'),
        step(3, "For me that's rare, so MyPet points it out, with the days it saw. It's a change, not a diagnosis. A vet can tell why.",
            target: 'insightsFlag'),
        step(2, 'My carer filmed me hissing at the vacuum. Watch: sound and picture are read on the phone, never uploaded.',
            open: GuideOpen.check),
        step(1, 'My page keeps every check. Tap one to replay my hiss, or my purr from last week.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(1, 'Settings decides what Save keeps: the video, only the sound, or just the results.',
            open: GuideOpen.settings, target: 'savedClips'),
        step(4, "Reminders keep my meals on time. That's my story!"),
      ],
    'demo-pepper' => [
        step(0, "Hi, I'm Pepper, a puppy! $days days of logs, and everything looks normal for me, so Today stays calm.",
            target: 'stats'),
        step(3, "I'm growing, so my weight goes up every week. MyPet expects that, and would only say something if it stopped.",
            target: 'weight'),
        step(3, 'My energy sits inside my usual band, so there is nothing to flag.', target: 'usual'),
        step(2, "Checks aren't only for worries. My carer filmed me barking at the gate. Watch MyPet find each bark.",
            open: GuideOpen.check),
        step(1, 'My page keeps those clips, so we can replay my good days too.',
            open: GuideOpen.petPage, target: 'savedCheck'),
        step(4, "Walks and meals are on Reminders. That's my story!"),
      ],
    _ => [
        step(0, "Mew, I'm Bean. I came home $days days ago, so I only have $days days of logs.", target: 'stats'),
        step(3, "MyPet needs 7 days to learn what's usual for me. Until then it shows what's typical for a kitten my age.",
            target: 'starter'),
        step(2, 'Checks work from day one. My carer filmed me meowing on my first night. Watch.', open: GuideOpen.check),
        step(1, 'My page already has my photo, my first check and my logs.', open: GuideOpen.petPage, target: 'photo'),
        step(4, "That's my story! Your pet's story starts with one log."),
      ],
  };
}

/// "Log while driving": Carl, a demo owner, answers the daily reminder by voice and the
/// log fills itself in as he speaks. Runs on Biscuit's demo data.
List<GuideStep> carlSteps() => const [
      GuideStep(0, "Meet Carl. He's driving home and remembers he hasn't logged Biscuit's day yet.",
          petName: 'Biscuit', open: GuideOpen.driving),
      GuideStep(0, "Hands on the wheel, so no tapping. MyPet's reminder pops up, and Carl just answers it by voice.",
          petName: 'Biscuit', open: GuideOpen.closeUp),
      GuideStep(0, "Listen. As Carl talks, MyPet fills in Biscuit's log. Watch 'Ate' change when he corrects himself.",
          petName: 'Biscuit', open: GuideOpen.voiceLog),
      GuideStep(0, 'All of it was understood on the phone, with no account and nothing uploaded. Once parked, Carl checks it and taps Save.',
          petName: 'Biscuit', stay: true, target: 'save'),
      GuideStep(0, "That's logging on the go. Try the mic on any daily log, or answer the evening reminder the same way.",
          petName: 'Biscuit'),
    ];

/// Soft in-car sound for the driving demo: road and engine, very quiet, looped. Starts with
/// the driving scene, carries on under Carl's voice note, and fades out once he parks.
/// Off when the app's sounds are off; the speaker button on the scene mutes it.
class DriveSound {
  static AudioPlayer? _player;
  static Timer? _fade;
  static bool muted = false;
  static final on = ValueNotifier<bool>(true);
  static const _volume = 0.22;

  static bool get _allowed =>
      Feel.sounds && !const bool.fromEnvironment('FLUTTER_TEST') && !Platform.environment.containsKey('FLUTTER_TEST');

  static Future<void> start() async {
    on.value = !muted;
    if (!_allowed || _player != null) return;
    final p = _player = AudioPlayer();
    try {
      await p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('demo_voice/drive_ambience.m4a'), volume: 0);
      if (!muted) _ramp(_volume, 1200);
    } catch (_) {}
  }

  static void setMuted(bool m) {
    muted = m;
    on.value = !m;
    _ramp(m ? 0 : _volume, 400);
  }

  /// Engine off: a slow fade, then the player goes.
  static void stop() {
    final p = _player;
    if (p == null) return;
    _ramp(0, 1500, then: () {
      p.dispose();
      if (identical(_player, p)) _player = null;
    });
  }

  static void _ramp(double to, int ms, {VoidCallback? then}) {
    final p = _player;
    _fade?.cancel();
    if (p == null) return then?.call();
    final from = p.volume;
    var i = 0;
    const steps = 15;
    _fade = Timer.periodic(Duration(milliseconds: ms ~/ steps), (t) {
      i++;
      p.setVolume(from + (to - from) * i / steps).catchError((_) {});
      if (i >= steps) {
        t.cancel();
        then?.call();
      }
    });
  }
}

/// The scene's palette: a soft day in light mode, a calm night in dark mode, in the app's
/// violet family. Flat fills only.
class _DriveColors {
  const _DriveColors({
    required this.sky,
    required this.sun,
    required this.hillFar,
    required this.hillNear,
    required this.ground,
    required this.road,
    required this.lane,
    required this.post,
    required this.body,
    required this.bodyShade,
    required this.glass,
    required this.tyre,
    required this.light,
    required this.dash,
    required this.wheel,
  });
  final Color sky, sun, hillFar, hillNear, ground, road, lane, post;
  final Color body, bodyShade, glass, tyre, light, dash, wheel;

  static _DriveColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? night : day;

  static const day = _DriveColors(
    sky: Color(0xFFF3F0FF),
    sun: Color(0xFFFFE3A1),
    hillFar: Color(0xFFE3DCFA),
    hillNear: Color(0xFFD3C8F5),
    ground: Color(0xFFE9E3FB),
    road: Color(0xFF5F5794),
    lane: Color(0xFFFFFFFF),
    post: Color(0xFFFFFFFF),
    body: Color(0xFF6A4FD6),
    bodyShade: Color(0xFF5B43BF),
    glass: Color(0xFF3A3170),
    tyre: Color(0xFF2B2550),
    light: Color(0xFFFFC94D),
    dash: Color(0xFF3B3468),
    wheel: Color(0xFF26214A),
  );

  static const night = _DriveColors(
    sky: Color(0xFF1B1735),
    sun: Color(0xFFF3EAC6),
    hillFar: Color(0xFF26214A),
    hillNear: Color(0xFF2E2858),
    ground: Color(0xFF221D42),
    road: Color(0xFF37315F),
    lane: Color(0xFFF6E7B0),
    post: Color(0xFF8D84C2),
    body: Color(0xFF8B75F0),
    bodyShade: Color(0xFF7760DB),
    glass: Color(0xFF221D45),
    tyre: Color(0xFF15122B),
    light: Color(0xFFFF8FA8),
    dash: Color(0xFF141128),
    wheel: Color(0xFF0D0B1E),
  );
}

/// A full-screen scene for the driving demo: Carl's car on the road, then the view from
/// the driver's seat as MyPet's reminder arrives.
class VoiceScene extends StatefulWidget {
  const VoiceScene({super.key, required this.closeUp, required this.petName});
  final bool closeUp;
  final String petName;

  @override
  State<VoiceScene> createState() => _VoiceSceneState();
}

class _VoiceSceneState extends State<VoiceScene> with SingleTickerProviderStateMixin {
  // One slow loop drives everything: lane marks, roadside posts and the car's gentle sway.
  late final _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    // Endless only on a real device; a test would never settle.
    if (!const bool.fromEnvironment('FLUTTER_TEST') && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _move.repeat();
    } else {
      _move.value = 0.35;
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _DriveColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: d.sky,
      body: Stack(fit: StackFit.expand, children: [
        Semantics(
          label: widget.closeUp ? 'The road from the driver\'s seat' : 'Carl driving home',
          child: AnimatedBuilder(
            animation: _move,
            builder: (_, _) => CustomPaint(painter: _DrivePainter(_move.value, d, inside: widget.closeUp)),
          ),
        ),
        if (widget.closeUp)
          Positioned(
            top: top + Tokens.space3 + 56,
            left: Tokens.space4,
            right: Tokens.space4,
            child: _ReminderBanner(petName: widget.petName),
          ),
        Positioned(top: top + Tokens.space2, right: Tokens.space3, child: const _SoundButton()),
      ]),
    );
  }
}

/// Mutes or unmutes the driving sound.
class _SoundButton extends StatelessWidget {
  const _SoundButton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF3B3468);
    return ValueListenableBuilder<bool>(
      valueListenable: DriveSound.on,
      builder: (_, on, _) => Semantics(
        button: true,
        label: on ? 'Mute road sound' : 'Play road sound',
        child: Material(
          color: fg.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => DriveSound.setMuted(on),
            child: SizedBox(
              width: Tokens.minTarget,
              height: Tokens.minTarget,
              child: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 22, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// MyPet's evening reminder, sliding down like a phone notification.
class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: 1 - v,
        child: FractionalTranslation(translation: Offset(0, -0.4 * v), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Tokens.space4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Tokens.radiusHero),
          boxShadow: const [BoxShadow(color: Color(0x141B1735), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pets_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('MyPet', style: t.textTheme.labelMedium!.copyWith(color: const Color(0xFF6B6690))),
                const Spacer(),
                Text('now', style: t.textTheme.labelSmall!.copyWith(color: const Color(0xFF8D88A8))),
              ]),
              const SizedBox(height: 2),
              Text("How was $petName's day?",
                  style: t.textTheme.titleSmall!.copyWith(color: const Color(0xFF1F1A3D))),
              Text('Hold to answer by voice',
                  style: t.textTheme.bodySmall!.copyWith(color: const Color(0xFF6B6690))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The whole scene in flat shapes: sky, sun (or moon), two lines of hills, the road with
/// lane marks and posts rushing past, then either Carl's car from behind or the inside of
/// the car (windscreen frame, dashboard, steering wheel and his phone on its mount).
class _DrivePainter extends CustomPainter {
  _DrivePainter(this.v, this.c, {required this.inside});
  final double v;
  final _DriveColors c;
  final bool inside;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * (inside ? 0.40 : 0.50);
    final p = Paint()..isAntiAlias = true;

    canvas.drawRect(Offset.zero & size, p..color = c.sky);
    canvas.drawCircle(Offset(w * 0.74, horizon - h * 0.13), w * 0.085, p..color = c.sun);

    Path hills(double base, double amp, double phase) {
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 4) {
        final y = base - amp * (0.6 + 0.4 * math.sin(x / w * 2.4 * math.pi + phase)) * (0.7 + 0.3 * math.sin(x / w * 5.3 + phase * 2));
        path.lineTo(x, y);
      }
      return path
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(hills(horizon, h * 0.07, 0.8), p..color = c.hillFar);
    canvas.drawPath(hills(horizon + 1, h * 0.035, 2.6), p..color = c.hillNear);
    canvas.drawRect(Rect.fromLTRB(0, horizon, w, h), p..color = c.ground);

    // Road in perspective, every line meeting at one point on the horizon. Carl keeps left
    // (as in Malaysia and Australia), so the centre line runs to the right of his lane.
    final cx = w / 2;
    final bottom = inside ? h * 0.80 : h;
    final (left, right, mid) = inside ? (-0.80 * w, 0.95 * w, 0.30 * w) : (-0.62 * w, 0.98 * w, 0.22 * w);
    double k(double y) => ((y - horizon) / (bottom - horizon)).clamp(0.0, 1.0);
    double xAt(double edge, double y) => cx + edge * k(y);
    canvas.drawPath(
        Path()
          ..moveTo(cx - 1, horizon)
          ..lineTo(cx + 1, horizon)
          ..lineTo(xAt(right, bottom), bottom)
          ..lineTo(xAt(left, bottom), bottom)
          ..close(),
        p..color = c.road);

    // Lane marks and roadside posts, spaced evenly in depth, so they speed up as they near.
    const n = 7;
    for (var i = 0; i < n; i++) {
      final f = (i + v) / n;
      final e = f * f * f;
      final y0 = horizon + (bottom - horizon) * e;
      final f1 = (i + v + 0.45) / n;
      final y1 = math.min(bottom, horizon + (bottom - horizon) * f1 * f1 * f1);
      final lw0 = w * 0.016 * k(y0), lw1 = w * 0.016 * k(y1);
      final m0 = xAt(mid, y0), m1 = xAt(mid, y1);
      canvas.drawPath(
          Path()
            ..moveTo(m0 - lw0, y0)
            ..lineTo(m0 + lw0, y0)
            ..lineTo(m1 + lw1, y1)
            ..lineTo(m1 - lw1, y1)
            ..close(),
          p..color = c.lane.withValues(alpha: 0.9));
      final postH = 6 + 70 * e;
      final postW = 1.5 + 6 * e;
      for (final edge in [left * 1.12, right * 1.08]) {
        final x = xAt(edge, y0);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x - postW / 2, y0 - postH, postW, postH), Radius.circular(postW / 2)),
            p..color = c.post.withValues(alpha: 0.35 + 0.6 * e));
      }
    }

    if (inside) {
      _cabin(canvas, size, p);
    } else {
      final y = h * 0.80;
      _car(canvas, Offset((xAt(left, y) + xAt(mid, y)) / 2, y), w * 0.46, p);
    }
  }

  /// Carl's car from behind, with a gentle sway as it drives.
  void _car(Canvas canvas, Offset at, double cw, Paint p) {
    final bob = math.sin(v * 2 * math.pi * 2) * 1.2;
    canvas.save();
    canvas.translate(at.dx, at.dy + bob);
    final bh = cw * 0.34; // lower body height
    canvas.drawOval(Rect.fromCenter(center: Offset(0, bh * 0.62 - bob), width: cw * 1.08, height: cw * 0.10),
        p..color = const Color(0x22000000));
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(s * cw * 0.36, bh * 0.48), width: cw * 0.17, height: bh * 0.34),
              Radius.circular(cw * 0.04)),
          p..color = c.tyre);
    }
    // Cabin and rear window.
    final roof = Path()
      ..moveTo(-cw * 0.40, -bh * 0.02)
      ..lineTo(-cw * 0.30, -bh * 0.82)
      ..quadraticBezierTo(-cw * 0.28, -bh * 0.92, -cw * 0.20, -bh * 0.92)
      ..lineTo(cw * 0.20, -bh * 0.92)
      ..quadraticBezierTo(cw * 0.28, -bh * 0.92, cw * 0.30, -bh * 0.82)
      ..lineTo(cw * 0.40, -bh * 0.02)
      ..close();
    canvas.drawPath(roof, p..color = c.bodyShade);
    final glass = Path()
      ..moveTo(-cw * 0.33, -bh * 0.10)
      ..lineTo(-cw * 0.255, -bh * 0.76)
      ..lineTo(cw * 0.255, -bh * 0.76)
      ..lineTo(cw * 0.33, -bh * 0.10)
      ..close();
    canvas.drawPath(glass, p..color = c.glass);
    // A tiny head and shoulders: Carl at the wheel.
    canvas.drawCircle(Offset(cw * 0.10, -bh * 0.42), cw * 0.055, p..color = c.bodyShade);
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromCenter(center: Offset(cw * 0.10, -bh * 0.17), width: cw * 0.20, height: bh * 0.22),
            topLeft: Radius.circular(cw * 0.06), topRight: Radius.circular(cw * 0.06)),
        p);
    // Lower body.
    final body = RRect.fromRectAndRadius(Rect.fromLTRB(-cw / 2, -bh * 0.08, cw / 2, bh * 0.52), Radius.circular(cw * 0.09));
    canvas.drawRRect(body, p..color = c.body);
    // Tail lights, plate and a bumper line.
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(s * cw * 0.36, bh * 0.10), width: cw * 0.16, height: bh * 0.12),
              Radius.circular(bh * 0.06)),
          p..color = c.light);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, bh * 0.20), width: cw * 0.22, height: bh * 0.14),
            Radius.circular(bh * 0.04)),
        p..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(-cw * 0.44, bh * 0.38, cw * 0.44, bh * 0.43), Radius.circular(bh * 0.03)),
        p..color = c.bodyShade);
    canvas.restore();
  }

  /// The driver's view: windscreen frame, dashboard, wheel and the phone on its mount.
  void _cabin(Canvas canvas, Size size, Paint p) {
    final w = size.width, h = size.height;
    p.color = c.dash;
    // Roof edge and pillars.
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h * 0.10)
          ..quadraticBezierTo(w / 2, h * 0.035, 0, h * 0.10)
          ..close(),
        p);
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w * 0.10, 0)..lineTo(0, h * 0.70)..close(), p);
    canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w * 0.90, 0)..lineTo(w, h * 0.70)..close(), p);
    // Dashboard.
    final dashTop = h * 0.74;
    canvas.drawPath(
        Path()
          ..moveTo(0, dashTop + h * 0.02)
          ..quadraticBezierTo(w / 2, dashTop - h * 0.035, w, dashTop + h * 0.02)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        p);
    // Steering wheel, swaying a touch.
    final sway = math.sin(v * 2 * math.pi) * 0.025;
    canvas.save();
    canvas.translate(w * 0.64, h * 1.02);
    canvas.rotate(sway);
    final r = w * 0.36;
    canvas.drawCircle(Offset.zero, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..color = c.wheel);
    final spoke = Paint()
      ..color = c.wheel
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-r, -r * 0.05), Offset(-r * 0.2, -r * 0.12), spoke);
    canvas.drawLine(Offset(r, -r * 0.05), Offset(r * 0.2, -r * 0.12), spoke);
    canvas.drawCircle(Offset(0, -r * 0.08), r * 0.24, Paint()..color = c.wheel);
    canvas.restore();
    // Phone on its mount, screen lit with MyPet's colour.
    final phone = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.18, dashTop - h * 0.045), width: w * 0.15, height: w * 0.27),
        Radius.circular(w * 0.03));
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.18, dashTop + h * 0.02), width: w * 0.03, height: h * 0.05),
        p..color = c.wheel);
    canvas.drawRRect(phone, p..color = c.wheel);
    canvas.drawRRect(phone.deflate(w * 0.008), p..color = const Color(0xFF6A4FD6));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: phone.center.translate(0, -w * 0.06), width: w * 0.11, height: w * 0.045),
            Radius.circular(w * 0.01)),
        p..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_DrivePainter old) => old.v != v || old.c != c || old.inside != inside;
}

/// A demo owner's face: a friendly drawn person in the brand colours.
class CarerFace extends StatelessWidget {
  const CarerFace({super.key, required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MyPetColors.of(context);
    return Semantics(
      label: name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.brandContainer, shape: BoxShape.circle),
        child: Icon(Icons.face_6_rounded, size: size * 0.8, color: c.brand),
      ),
    );
  }
}

/// The pet's newest saved check with a clip, copied so the demo can play and check it
/// as if it was just filmed (the bundled copy stays for replays).
Future<DemoCheckRun?> demoCheckFor(AppState s, String petId) async {
  final e = s.timelineOf(petId).ofKind(EntryKind.behaviourResult).where((e) => s.clipOf(e) != null).firstOrNull;
  final path = e == null ? null : s.clipOf(e);
  if (e == null || path == null || !File(path).existsSync()) return null;
  final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.mp4';
  final copy = '${Directory.systemTemp.path}/demo_check_${DateTime.now().millisecondsSinceEpoch}$ext';
  await File(path).copy(copy);
  return DemoCheckRun(petId, copy, outcomeFromEntry(e.data, clip: copy));
}

/// Opens one demo pet's story on fresh demo data, over the app. Your own pets are never
/// touched. Ends back where it started.
Future<void> startStory(BuildContext context, DemoPet pet, {List<GuideStep>? steps, String? narrator}) async {
  final engine = context.read<BehaviourEngine>();
  final nav = Navigator.of(context);
  final parent = context.read<AppState>();
  final demo = AppState(LocalBackend(), clock: parent.clock, detectInBackground: parent.detectInBackground);
  await demo.backend.signIn('', '');
  for (var i = 0; i < 50 && !demo.carerKnown; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  final clips = await loadDemoClips();
  final dir = await unpackDemoClips(clips);
  demo.clipDir = dir;
  await addDemoPets(demo, fixedIds: true, clips: clips, clipDir: dir);
  for (var i = 0; i < 50 && demo.activePets.length < demoPets.length; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  demo.demo = true;
  demo.look = parent.look;
  demo.clipKeep = parent.clipKeep;
  demo.startGuide(Guide(steps: steps ?? storySteps(demo, pet), narrator: narrator ?? pet.name, onDone: () => nav.pop()));
  await nav.push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (c) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: demo),
        Provider.value(value: engine),
      ],
      // A navigator of its own, so every page the demo opens (pet page, log, settings)
      // sits under the demo's AppState and finds the demo pets.
      child: const _DemoNavigator(),
    ),
  ));
  demo.dispose();
}

class _DemoNavigator extends StatefulWidget {
  const _DemoNavigator();

  @override
  State<_DemoNavigator> createState() => _DemoNavigatorState();
}

class _DemoNavigatorState extends State<_DemoNavigator> {
  final _key = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _key.currentState?.maybePop(),
      child: Navigator(
        key: _key,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      ),
    );
  }
}

/// "Try a demo": example pets, each with a month of logs and real clips, told as a story.
class DemoPickerScreen extends StatelessWidget {
  const DemoPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Try a demo')),
      body: PageWash(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          Text('Example pets with a month of logs and real clips from Wikimedia Commons. Your own pets are not touched.',
              style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.space4),
          for (final (i, d) in demoPets.indexed) ...[
            MyCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(Tokens.radiusCard),
                onTap: () {
                  Feel.tap();
                  startStory(context, d);
                },
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space4),
                  child: Row(children: [
                    PetPortrait.of(d.pet, background: MyPetColors.of(context).petAccents[i], size: 64),
                    const SizedBox(width: Tokens.space4),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, style: t.textTheme.titleMedium),
                        const SizedBox(height: Tokens.space1),
                        Text(d.subtitle,
                            style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space3),
          ],
          MyCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
              onTap: () {
                Feel.tap();
                startStory(context, demoPets.first, steps: carlSteps(), narrator: 'Carl');
              },
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Row(children: [
                  const CarerFace(name: 'Carl', size: 64),
                  const SizedBox(width: Tokens.space4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Log by voice while driving', style: t.textTheme.titleMedium),
                      const SizedBox(height: Tokens.space1),
                      Text("Carl tells MyPet about Biscuit's day, and the log fills itself in",
                          style: t.textTheme.bodyMedium!.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Keeps the guide's bubble on top of every page while a walkthrough runs, without
/// blocking the app: the person can tap around, open pages, and come back to it.
class GuideHost extends StatefulWidget {
  const GuideHost({super.key, required this.child});
  final Widget child;

  @override
  State<GuideHost> createState() => _GuideHostState();
}

class _GuideHostState extends State<GuideHost> {
  OverlayEntry? _entry;
  String? _stepKey;

  /// Shows the step: back to the tabs, then the page it opens, then its clip on Check.
  Future<void> _perform(AppState s, Guide g) async {
    final st = g.steps[g.at];
    if (st.stay) return;
    final nav = Navigator.of(context);
    final home = ModalRoute.of(context);
    if (home != null && !home.isCurrent) nav.popUntil((r) => r == home);
    final pet = s.activePets.where((p) => p.name == (st.petName ?? g.narrator)).firstOrNull;
    if (st.open != GuideOpen.check && s.demoCheck != null) s.runDemoCheck(null);
    switch (st.open) {
      case GuideOpen.petPage when pet != null:
        nav.push(MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id)));
      case GuideOpen.settings:
        nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      case GuideOpen.driving || GuideOpen.closeUp:
        nav.push(PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => VoiceScene(closeUp: st.open == GuideOpen.closeUp, petName: pet?.name ?? 'Biscuit'),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ));
      case GuideOpen.voiceLog when pet != null:
        final script = await VoiceScript.load('carl_voice_log');
        if (identical(s.guide, g) && g.steps[g.at] == st) {
          nav.push(MaterialPageRoute(builder: (_) => QuickLogScreen(pet: pet, script: script)));
        }
      case GuideOpen.check when pet != null:
        final run = await demoCheckFor(s, pet.id);
        if (run != null && identical(s.guide, g) && g.steps[g.at] == st) s.runDemoCheck(run);
      default:
        break;
    }
  }

  void _sync(AppState s) {
    if (!mounted) return;
    final g = s.guide;
    final key = g == null ? null : '${identityHashCode(g)}:${g.at}';
    if (key != _stepKey) {
      _stepKey = key;
      if (g != null) _perform(s, g);
      // The road sound plays while Carl drives and fades out once he parks.
      final open = g?.steps[g.at].open;
      if (open == GuideOpen.driving || open == GuideOpen.closeUp || open == GuideOpen.voiceLog) {
        DriveSound.start();
      } else {
        DriveSound.stop();
      }
    }
    if (s.guide != null && _entry == null) {
      final nav = Navigator.of(context);
      final home = ModalRoute.of(context);
      final e = OverlayEntry(
        builder: (_) => ChangeNotifierProvider.value(
          value: s,
          // Next and Back show a tab, so first close any page opened on top of the tabs.
          child: GuideOverlay(backToTabs: () {
            if (home != null && !home.isCurrent) nav.popUntil((r) => r == home);
          }),
        ),
      );
      _entry = e;
      Overlay.of(context, rootOverlay: true).insert(e);
    } else if (s.guide == null && _entry != null) {
      _remove();
    }
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    DriveSound.stop();
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(s));
    return widget.child;
  }
}

/// The guide's speech bubble, pointing at the tab it talks about. It never blocks the app.
/// It can shrink to just the guide's face (tap the face to open it again) or be closed.
class GuideOverlay extends StatelessWidget {
  const GuideOverlay({super.key, this.backToTabs});
  final VoidCallback? backToTabs;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final g = s.guide;
    if (g == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    final st = g.steps[g.at];
    final last = g.at == g.steps.length - 1;
    final narrator = g.narrator == null ? null : s.activePets.where((p) => p.name == g.narrator).firstOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    final arrowX = ((st.tab + 0.5) / 5 * (width - 2 * Tokens.space3) + Tokens.space3).clamp(40.0, width - 40);
    final who = g.narrator ?? 'Pip';
    Widget face(double size) => narrator != null
        ? PetAvatar(pet: narrator, size: size)
        : g.narrator != null
            ? CarerFace(name: g.narrator!, size: size)
            : ClipOval(
            child: Container(
              width: size,
              height: size,
              color: c.brandContainer,
              child: SvgPicture.asset('assets/illustrations/guide-dog.svg', fit: BoxFit.cover),
            ),
          );
    void step(int d) {
      Feel.guideNext();
      s.guideStep(d);
    }

    // An off-white tinted with the brand colour, so the bubble stands out on white pages.
    final fill = Color.alphaBlend(c.brand.withValues(alpha: t.brightness == Brightness.dark ? 0.22 : 0.09), t.colorScheme.surface);
    void shrink() {
      Feel.tap();
      s.setGuideCollapsed(true);
    }

    if (g.collapsed) {
      // Just the guide's face in the corner, with how far along the story is.
      return Stack(children: [
        Positioned(
          right: Tokens.space4,
          bottom: bottom,
          child: Semantics(
            button: true,
            label: 'Open $who\'s guide, step ${g.at + 1} of ${g.steps.length}',
            excludeSemantics: true,
            child: Material(
              color: t.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: Colors.black38,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  Feel.tap();
                  s.setGuideCollapsed(false);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Stack(clipBehavior: Clip.none, children: [
                    face(56),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(10)),
                        child: Text('${g.at + 1}/${g.steps.length}',
                            style: t.textTheme.labelSmall!.copyWith(color: MyPetColors.onAccent(c.brand))),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    return Stack(children: [
      Positioned(
        left: arrowX - 10,
        bottom: bottom - 12,
        child: CustomPaint(size: const Size(20, 12), painter: _Arrow(fill)),
      ),
      Positioned(
        left: Tokens.space3,
        right: Tokens.space3,
        bottom: bottom,
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: fill,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusHero),
              side: BorderSide(color: c.brand.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.space4, Tokens.space2, Tokens.space2, Tokens.space3),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Tap the face to shrink the guide; a hint says so until it has been used once.
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.space2),
                    child: Column(children: [
                      Tooltip(
                        message: 'Tap me to shrink',
                        child: Semantics(
                          button: true,
                          label: 'Shrink the guide',
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: shrink,
                            radius: 30,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.brand, width: 2)),
                              child: face(48),
                            ),
                          ),
                        ),
                      ),
                      if (!s.guideHintSeen)
                        GestureDetector(
                          onTap: shrink,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(8)),
                            child: Text('Tap me\nto shrink',
                                textAlign: TextAlign.center,
                                style: t.textTheme.labelSmall!.copyWith(color: MyPetColors.onAccent(c.brand), height: 1.1)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Tokens.space2),
                      child: Text(st.text, style: t.textTheme.bodyLarge),
                    ),
                  ),
                  Column(children: [
                    // The tour just closes; a demo story closes by leaving the demo.
                    IconButton(
                      tooltip: g.onDone == null ? 'Close the guide' : 'Leave the demo',
                      onPressed: () {
                        Feel.tap();
                        backToTabs?.call();
                        s.endGuide();
                      },
                      icon: Icon(g.onDone == null ? Icons.close_rounded : Icons.logout_rounded),
                    ),
                  ]),
                ]),
                Row(children: [
                  // Step dots
                  for (var i = 0; i < g.steps.length; i++)
                    Container(
                      width: i == g.at ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == g.at ? c.brand : c.cardBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const Spacer(),
                  if (g.at > 0)
                    IconButton(tooltip: 'Back', onPressed: () => step(-1), icon: const Icon(Icons.arrow_back_rounded)),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, Tokens.minTarget)),
                    onPressed: () => step(1),
                    child: Text(last ? 'Done' : 'Next'),
                  ),
                  const SizedBox(width: Tokens.space2),
                ]),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Arrow extends CustomPainter {
  _Arrow(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = colour);

  @override
  bool shouldRepaint(_Arrow old) => old.colour != colour;
}
