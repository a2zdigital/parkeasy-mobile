import 'package:app/core/time/facility_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const india = 'Asia/Kolkata';

  // The running app gets this from its localisation delegates.
  setUpAll(initializeDateFormatting);

  test(
    'shows an instant on the facility clock, whatever the phone is set to',
    () {
      final instant = DateTime.utc(2026, 11, 2, 4, 30);

      expect(
        FacilityTime.dayAndTime(instant, india, 'en'),
        'Mon 2 Nov, 10:00 AM',
      );
      expect(FacilityTime.time(instant, india, 'en'), '10:00 AM');
    },
  );

  test('a late-evening UTC instant is the next day in India', () {
    expect(
      FacilityTime.dayAndTime(DateTime.utc(2026, 11, 2, 19), india, 'en'),
      'Tue 3 Nov, 12:30 AM',
    );
  });

  test('wall time converts back to the same instant', () {
    final instant = DateTime.utc(2026, 12, 31, 20, 45);

    final wall = FacilityTime.toWall(instant, india);

    expect(wall, DateTime.utc(2027, 1, 1, 2, 15));
    expect(FacilityTime.fromWall(wall, india), instant);
  });

  test('an unknown zone is treated and labelled as UTC', () {
    final instant = DateTime.utc(2026, 11, 2, 4, 30);

    expect(FacilityTime.knows('Europe/Paris'), isFalse);
    expect(FacilityTime.label('Europe/Paris'), 'UTC');
    expect(FacilityTime.toWall(instant, 'Europe/Paris'), instant);
    expect(FacilityTime.label(india), india);
  });

  test('names the days with Monday as 1', () {
    expect(FacilityTime.weekday(1, 'en'), 'Monday');
    expect(FacilityTime.weekday(7, 'en'), 'Sunday');
  });

  test('formats stored opening times', () {
    expect(FacilityTime.clock('06:00', 'en'), '6:00 AM');
    expect(FacilityTime.clock('22:30', 'en'), '10:30 PM');
    expect(FacilityTime.clock('24:00', 'en'), '12:00 AM');
  });
}
