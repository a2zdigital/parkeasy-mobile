import 'package:intl/intl.dart';

/// Converts between UTC instants and the wall-clock time at a facility.
///
/// Bookings are shown and chosen in the **facility's** time zone, not the
/// phone's. The pilot runs in India, which has one zone and no daylight
/// saving, so the zones the app knows are a fixed table. A zone that is
/// not in the table is treated as UTC and labelled as such; adding a full
/// time-zone database is a dependency decision for when another country
/// is added.
///
/// A "wall" time is a UTC [DateTime] whose fields hold the local clock
/// reading. It is only for display and for pickers.
abstract final class FacilityTime {
  static const Map<String, Duration> _offsets = {
    'Asia/Kolkata': Duration(hours: 5, minutes: 30),
    'Asia/Calcutta': Duration(hours: 5, minutes: 30),
    'UTC': Duration.zero,
  };

  static bool knows(String zone) => _offsets.containsKey(zone);

  /// The name to show for a zone: its own name, or UTC when unknown.
  static String label(String zone) => knows(zone) ? zone : 'UTC';

  static DateTime toWall(DateTime instant, String zone) =>
      instant.toUtc().add(_offsets[zone] ?? Duration.zero);

  static DateTime fromWall(DateTime wall, String zone) => DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  ).subtract(_offsets[zone] ?? Duration.zero);

  /// `Tue 3 Nov, 10:00 AM`
  static String dayAndTime(DateTime instant, String zone, String locale) =>
      DateFormat('EEE d MMM, h:mm a', locale).format(toWall(instant, zone));

  /// `10:00 AM`
  static String time(DateTime instant, String zone, String locale) =>
      DateFormat('h:mm a', locale).format(toWall(instant, zone));

  /// The name of a day of the week, where 1 is Monday and 7 is Sunday.
  static String weekday(int dayOfWeek, String locale) =>
      // 5 January 2026 is a Monday.
      DateFormat.EEEE(locale).format(DateTime.utc(2026, 1, 4 + dayOfWeek));

  /// Turns a stored `HH:mm` opening time into `6:00 AM`. `24:00`, the end
  /// of the day, is shown as midnight.
  static String clock(String hhmm, String locale) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateFormat(
      'h:mm a',
      locale,
    ).format(DateTime.utc(2026, 1, 5, hour % 24, minute));
  }
}
