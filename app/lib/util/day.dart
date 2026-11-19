/// A calendar day in the carer's local time, stored as yyyy-MM-dd.
///
/// Logs are counted per day (report 4.1), so the date matters, not the clock time.
class Day implements Comparable<Day> {
  final int year;
  final int month;
  final int dayOfMonth;

  const Day(this.year, this.month, this.dayOfMonth);

  factory Day.of(DateTime t) => Day(t.year, t.month, t.day);
  factory Day.today() => Day.of(DateTime.now());

  factory Day.parse(String s) {
    final p = s.split('-');
    return Day(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  DateTime get asDateTime => DateTime(year, month, dayOfMonth);

  Day addDays(int n) => Day.of(DateTime(year, month, dayOfMonth + n));

  /// Whole days from [other] to this day (positive when this is later).
  int difference(Day other) =>
      DateTime.utc(year, month, dayOfMonth)
          .difference(DateTime.utc(other.year, other.month, other.dayOfMonth))
          .inDays;

  bool isBefore(Day o) => compareTo(o) < 0;
  bool isAfter(Day o) => compareTo(o) > 0;

  @override
  int compareTo(Day other) => year != other.year
      ? year - other.year
      : month != other.month
          ? month - other.month
          : dayOfMonth - other.dayOfMonth;

  @override
  bool operator ==(Object other) => other is Day && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month, dayOfMonth);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${dayOfMonth.toString().padLeft(2, '0')}';
}
