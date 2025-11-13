/// Severity levels for log records.
enum Severity {
  trace(1),
  trace2(2),
  trace3(3),
  trace4(4),
  debug(5),
  debug2(6),
  debug3(7),
  debug4(8),
  info(9),
  info2(10),
  info3(11),
  info4(12),
  warn(13),
  warn2(14),
  warn3(15),
  warn4(16),
  error(17),
  error2(18),
  error3(19),
  error4(20),
  fatal(21),
  fatal2(22),
  fatal3(23),
  fatal4(24);

  final int value;
  const Severity(this.value);

  String get text {
    if (value <= 4) return 'TRACE';
    if (value <= 8) return 'DEBUG';
    if (value <= 12) return 'INFO';
    if (value <= 16) return 'WARN';
    if (value <= 20) return 'ERROR';
    return 'FATAL';
  }
}
