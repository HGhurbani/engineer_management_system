import '../models/holiday.dart';

/// Utility to provide official Saudi Arabia holidays with their names.

const int _islamicEpoch = 1948439; // Julian day of 1 Muharram, year 1 AH.

int _gregorianToJD(int year, int month, int day) {
  int a = ((14 - month) ~/ 12);
  int y = year + 4800 - a;
  int m = month + 12 * a - 3;
  return day + ((153 * m + 2) ~/ 5) + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
}

DateTime _jdToGregorian(int jd) {
  int l = jd + 68569;
  int n = (4 * l) ~/ 146097;
  l = l - (146097 * n + 3) ~/ 4;
  int i = (4000 * (l + 1)) ~/ 1461001;
  l = l - (1461 * i) ~/ 4 + 31;
  int j = (80 * l) ~/ 2447;
  int day = l - (2447 * j) ~/ 80;
  l = j ~/ 11;
  int month = j + 2 - 12 * l;
  int year = 100 * (n - 49) + i + l;
  return DateTime(year, month, day);
}

int _islamicToJD(int year, int month, int day) {
  return day + ((29.5 * (month - 1)).ceil()) + (year - 1) * 354 + ((3 + 11 * year) ~/ 30) + _islamicEpoch - 1;
}

int _jdToIslamicYear(int jd) {
  return ((30 * (jd - _islamicEpoch) + 10646) / 10631).floor();
}

DateTime _islamicToGregorianDate(int year, int month, int day) {
  int jd = _islamicToJD(year, month, day);
  return _jdToGregorian(jd);
}

DateTime _calculateIslamicHoliday(int gregorianYear, int hijriMonth, int hijriDay) {
  int startYear = _jdToIslamicYear(_gregorianToJD(gregorianYear, 1, 1));
  DateTime result = _islamicToGregorianDate(startYear, hijriMonth, hijriDay);
  if (result.year != gregorianYear) {
    result = _islamicToGregorianDate(startYear + 1, hijriMonth, hijriDay);
  }
  return result;
}

List<Holiday> saudiOfficialHolidays(int year) {
  final eidFitr = _calculateIslamicHoliday(year, 10, 1); // 1 Shawwal
  final dayArafah = _calculateIslamicHoliday(year, 12, 9); // 9 Dhul Hijjah
  final eidAdha = _calculateIslamicHoliday(year, 12, 10); // 10 Dhul Hijjah

  return [
    Holiday(name: 'عيد الفطر', date: eidFitr),
    Holiday(name: 'يوم عرفة', date: dayArafah),
    Holiday(name: 'عيد الأضحى', date: eidAdha),
    Holiday(name: 'يوم التأسيس', date: DateTime(year, 2, 22)),
    Holiday(name: 'اليوم الوطني', date: DateTime(year, 9, 23)),
    Holiday(name: 'يوم العلم', date: DateTime(year, 3, 11)),
  ];
}
