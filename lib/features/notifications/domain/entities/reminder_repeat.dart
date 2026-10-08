/// The preset a student picked on the reminder editor. Kept distinct from
/// the *resolved* set of days ([StudyReminder.resolvedDays]) so the editor
/// can round-trip "Weekdays" back into its own segmented control rather
/// than reverse-engineering a preset from a bare `{MON..FRI}` set (which
/// would be ambiguous with a custom selection that happens to equal the
/// same five days).
enum ReminderRepeat {
  everyDay,
  weekdays,
  weekends,
  custom,
  oneTime;

  static ReminderRepeat fromWire(String value) {
    switch (value) {
      case 'EVERY_DAY':
        return ReminderRepeat.everyDay;
      case 'WEEKDAYS':
        return ReminderRepeat.weekdays;
      case 'WEEKENDS':
        return ReminderRepeat.weekends;
      case 'CUSTOM':
        return ReminderRepeat.custom;
      case 'ONE_TIME':
        return ReminderRepeat.oneTime;
      default:
        throw FormatException('Unknown reminder repeat: $value');
    }
  }

  String toWire() => switch (this) {
    ReminderRepeat.everyDay => 'EVERY_DAY',
    ReminderRepeat.weekdays => 'WEEKDAYS',
    ReminderRepeat.weekends => 'WEEKENDS',
    ReminderRepeat.custom => 'CUSTOM',
    ReminderRepeat.oneTime => 'ONE_TIME',
  };
}
