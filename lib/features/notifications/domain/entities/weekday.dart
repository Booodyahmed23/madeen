/// ISO-8601 week order (Monday first) — matches `DateTime.weekday`'s own
/// numbering (`DateTime.monday == 1` ... `DateTime.sunday == 7`), so
/// converting to/from `DateTime.weekday` is a plain index lookup, not a
/// remapping table.
enum Weekday {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  static const Set<Weekday> weekdays = {
    Weekday.monday,
    Weekday.tuesday,
    Weekday.wednesday,
    Weekday.thursday,
    Weekday.friday,
  };

  static const Set<Weekday> weekends = {Weekday.saturday, Weekday.sunday};

  /// `DateTime.monday` (1) through `DateTime.sunday` (7).
  factory Weekday.fromDateTimeWeekday(int dateTimeWeekday) =>
      Weekday.values[dateTimeWeekday - 1];

  int get dateTimeWeekday => index + 1;

  static Weekday fromWire(String value) {
    switch (value) {
      case 'MON':
        return Weekday.monday;
      case 'TUE':
        return Weekday.tuesday;
      case 'WED':
        return Weekday.wednesday;
      case 'THU':
        return Weekday.thursday;
      case 'FRI':
        return Weekday.friday;
      case 'SAT':
        return Weekday.saturday;
      case 'SUN':
        return Weekday.sunday;
      default:
        throw FormatException('Unknown weekday: $value');
    }
  }

  String toWire() => switch (this) {
    Weekday.monday => 'MON',
    Weekday.tuesday => 'TUE',
    Weekday.wednesday => 'WED',
    Weekday.thursday => 'THU',
    Weekday.friday => 'FRI',
    Weekday.saturday => 'SAT',
    Weekday.sunday => 'SUN',
  };
}
