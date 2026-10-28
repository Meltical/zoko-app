DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime today() => dateOnly(DateTime.now());

int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

DateTime parseDbDate(String value) => dateOnly(DateTime.parse(value));

String formatDbDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

DateTime addMonths(DateTime from, int months) {
  final target = DateTime(from.year, from.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, from.day > lastDay ? lastDay : from.day);
}

DateTime addDays(DateTime from, int days) => DateTime(from.year, from.month, from.day + days);
