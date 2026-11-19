import 'care_entry.dart';

/// The current view of an append-only entry list.
///
/// Each edit chain keeps only its newest version. If two carers edited the same entry at
/// the same time (two entries supersede one), the winner is picked the same way on every
/// device: latest createdAt, then the larger id (FR09). The other version stays in
/// [conflicts] so it is never silently lost (FR-N04).
class Timeline {
  final List<CareEntry> current;
  final List<CareEntry> conflicts;

  const Timeline(this.current, this.conflicts);

  factory Timeline.resolve(Iterable<CareEntry> all) {
    final byId = {for (final e in all) e.id: e};
    final children = <String, List<CareEntry>>{};
    for (final e in byId.values) {
      final s = e.supersedes;
      if (s != null) children.putIfAbsent(s, () => []).add(e);
    }
    final conflicts = <CareEntry>[];
    final current = <CareEntry>[];

    CareEntry head(CareEntry e) {
      var node = e;
      while (true) {
        final kids = children[node.id];
        if (kids == null || kids.isEmpty) return node;
        kids.sort(_newestFirst);
        if (kids.length > 1) conflicts.addAll(kids.skip(1));
        node = kids.first;
      }
    }

    for (final e in byId.values) {
      // Roots are entries that do not replace anything we hold.
      if (e.supersedes != null && byId.containsKey(e.supersedes)) continue;
      final h = head(e);
      if (!h.voided) current.add(h);
    }
    current.sort((a, b) {
      final d = b.day.compareTo(a.day);
      return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
    });
    return Timeline(current, conflicts);
  }

  static int _newestFirst(CareEntry a, CareEntry b) {
    final t = b.createdAt.compareTo(a.createdAt);
    return t != 0 ? t : b.id.compareTo(a.id);
  }

  List<CareEntry> ofKind(EntryKind k) =>
      current.where((e) => e.kind == k).toList();

  /// Newest daily log, used for "same as last entry" (FR05).
  CareEntry? get lastDailyLog {
    for (final e in current) {
      if (e.kind == EntryKind.dailyLog) return e;
    }
    return null;
  }
}
