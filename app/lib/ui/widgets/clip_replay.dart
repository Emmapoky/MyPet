import '../../util/media.dart';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../behaviour/analysis.dart';
import '../feedback.dart';
import '../theme.dart';

/// Sound moments are pink and picture moments sky blue, on the player and the pills.
const soundColour = Color(0xFFCC3F7A);
const pictureColour = Color(0xFF2B74BE);
const _playerColour = Color(0xFF1B1530);

String clock(double s) => '${s ~/ 60}:${(s.floor() % 60).toString().padLeft(2, '0')}';

/// The checked clip with what was found in it: a dark player, a timeline with
/// coloured stretches (pink = sound, blue = picture), and one pill per moment.
/// Tapping a pill plays just that part of the clip. The clip is never uploaded; after
/// Save it is kept as video, sound only, or not at all (Settings).
class ClipReplay extends StatefulWidget {
  const ClipReplay({super.key, required this.clip, required this.seconds, required this.moments});
  final String? clip;
  final double seconds;
  final List<Moment> moments;

  @override
  State<ClipReplay> createState() => _ClipReplayState();
}

class _ClipReplayState extends State<ClipReplay> {
  VideoPlayerController? _video;
  bool _ready = false;
  int? _active;
  double? _stopAt;
  double _at = 0;

  @override
  void initState() {
    super.initState();
    final path = widget.clip;
    final v = path == null ? null : clipPlayer(path);
    if (v != null) {
      _video = v;
      v.initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }, onError: (_) {});
      v.addListener(_tick);
    }
  }

  void _tick() {
    final v = _video!;
    final at = v.value.position.inMilliseconds / 1000;
    final stop = _stopAt;
    if (stop != null && at >= stop && v.value.isPlaying) {
      v.pause();
      _stopAt = null;
    }
    if (mounted) setState(() => _at = at);
  }

  @override
  void dispose() {
    _video?.removeListener(_tick);
    _video?.dispose();
    super.dispose();
  }

  double get _length {
    final d = _ready ? _video!.value.duration.inMilliseconds / 1000 : 0.0;
    return d > 0 ? d : (widget.seconds > 0 ? widget.seconds : 10);
  }

  Future<void> _play(int? i) async {
    Feel.tap();
    final v = _video;
    setState(() => _active = i);
    if (v == null || !_ready) return;
    if (i == null) {
      _stopAt = null;
      if (v.value.isPlaying) {
        await v.pause();
      } else {
        if (_at >= _length - 0.05) await v.seekTo(Duration.zero);
        await v.play();
      }
      return;
    }
    final m = widget.moments[i];
    // A little before and after, so a short sound is not cut mid-way.
    final from = (m.start - 0.3).clamp(0.0, _length);
    _stopAt = (m.end + 0.3).clamp(0.0, _length);
    await v.seekTo(Duration(milliseconds: (from * 1000).round()));
    await v.play();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final v = _video;
    final playing = v != null && _ready && v.value.isPlaying;
    final hasPicture = _ready && v!.value.size.width > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: ColoredBox(
          color: _playerColour,
          child: Column(children: [
            SizedBox(
              height: 220,
              child: Stack(fit: StackFit.expand, children: [
                if (hasPicture)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: v.value.size.width,
                      height: v.value.size.height,
                      child: VideoPlayer(v),
                    ),
                  )
                else
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(v == null ? 'Clip not kept · moments below' : 'Sound only',
                        style: t.textTheme.labelMedium!.copyWith(color: Colors.white70)),
                    const SizedBox(height: Tokens.space3),
                  ]),
                if (!hasPicture) const Center(child: Icon(Icons.graphic_eq_rounded, size: 120, color: Colors.white10)),
                if (v != null)
                Center(
                  child: Semantics(
                    button: true,
                    label: playing ? 'Pause the clip' : 'Play the clip',
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _play(null),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 32, color: _playerColour),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.space3, Tokens.space3, Tokens.space3, Tokens.space3),
              child: Row(children: [
                Text(clock(_at), style: t.textTheme.labelMedium!.copyWith(color: Colors.white)),
                const SizedBox(width: Tokens.space2),
                Expanded(child: _Timeline(length: _length, at: _at, moments: widget.moments, active: _active)),
                const SizedBox(width: Tokens.space2),
                Text(clock(_length), style: t.textTheme.labelMedium!.copyWith(color: Colors.white)),
              ]),
            ),
          ]),
        ),
      ),
      if (widget.moments.isNotEmpty) ...[
        const SizedBox(height: Tokens.space3),
        Wrap(spacing: Tokens.space2, runSpacing: Tokens.space2, children: [
          for (var i = 0; i < widget.moments.length; i++)
            _MomentPill(moment: widget.moments[i], active: _active == i, onTap: () => _play(i)),
        ]),
      ],
    ]);
  }
}

/// Two thin lanes under the player: pink stretches where a pet sound was heard,
/// blue where the picture showed the pet. A white line marks the play position.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.length, required this.at, required this.moments, required this.active});
  final double length, at;
  final List<Moment> moments;
  final int? active;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          double x(double s) => (s / length).clamp(0.0, 1.0) * w;
          Widget lane(double top, MomentSource src, Color colour) => Positioned(
                top: top,
                left: 0,
                right: 0,
                height: 8,
                child: Stack(children: [
                  Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4))),
                  for (var i = 0; i < moments.length; i++)
                    if (moments[i].source == src)
                      Positioned(
                        left: x(moments[i].start),
                        width: (x(moments[i].end) - x(moments[i].start)).clamp(3.0, w),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: active == null || active == i ? colour : colour.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                            border: active == i ? Border.all(color: Colors.white, width: 1.5) : null,
                          ),
                        ),
                      ),
                ]),
              );
          return SizedBox(
            height: 24,
            child: Stack(children: [
              lane(2, MomentSource.sound, soundColour),
              lane(14, MomentSource.picture, pictureColour),
              Positioned(
                left: (x(at) - 1).clamp(0.0, w - 2),
                top: 0,
                bottom: 0,
                width: 2,
                child: const ColoredBox(color: Colors.white),
              ),
            ]),
          );
        }),
      );
}

class _MomentPill extends StatelessWidget {
  const _MomentPill({required this.moment, required this.active, required this.onTap});
  final Moment moment;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sound = moment.source == MomentSource.sound;
    return Semantics(
      button: true,
      label: 'Play ${moment.label}, ${(100 * moment.p).round()} percent, at ${clock(moment.start)}, ${sound ? 'sound' : 'picture'}',
      excludeSemantics: true,
      child: Material(
        color: sound ? soundColour : pictureColour,
        shape: StadiumBorder(side: active ? const BorderSide(color: _playerColour, width: 2) : BorderSide.none),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Tokens.minTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: Tokens.space2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_circle_rounded, size: 20, color: Colors.white),
                const SizedBox(width: Tokens.space1),
                Icon(sound ? Icons.graphic_eq_rounded : Icons.visibility_rounded, size: 16, color: Colors.white),
                const SizedBox(width: Tokens.space2),
                Text('${clock(moment.start)} ${moment.label}',
                    style: t.textTheme.labelLarge!.copyWith(color: Colors.white)),
                if (moment.p > 0) ...[
                  const SizedBox(width: Tokens.space1),
                  Text('${(100 * moment.p).round()}%',
                      style: t.textTheme.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
