import 'package:intl/intl.dart';

/// Compact symbolic money formatting: $2.41T, $84.6B, $912.4M
final _compact = NumberFormat.compactCurrency(decimalDigits: 2, symbol: r'$');

final _priceFmt = NumberFormat.currency(symbol: '', decimalDigits: 2);
final _wholeFmt = NumberFormat('#,##0');
final _pct = NumberFormat('+0.00;-0.00');

String fmtUsdPrice(double v) {
  if (v == 0) return '\$0.00';
  if (v >= 0.0001 && v < 1) {
    return '\$${NumberFormat('0.0000').format(v)}';
  }
  if (v >= 1) return _priceFmt.format(v).replaceFirst(RegExp(r'\.00$'), '.00');
  // tiny values (< $0.0001) show up to 8 decimals
  return '\$${NumberFormat('0.00000000').format(v)}';
}

String fmtPricePlain(double v) => fmtUsdPrice(v).replaceFirst('\$', '');

String fmtCompactUsd(double v) => _compact.format(v);

String fmtQty(double v) {
  if (v >= 1000) return _wholeFmt.format(v);
  return NumberFormat('0.########').format(v);
}

/// Plain (no thousands separators) quantity for editable numeric fields.
String qtyPlain(double v) => NumberFormat('0.########').format(v);

String fmtSignedPct(double pct) => '${_pct.format(pct)}%';

/// "12.5%" without a deterministic sign, for allocation shares.
String pct1(double pct) => '${NumberFormat('0.#').format(pct)}%';

String fmtSignedUsd(double v) =>
    '${v >= 0 ? '+' : '-'}\$${NumberFormat('#,##0.00').format(v.abs())}';

String fmtUsd(double v) => '\$${NumberFormat('#,##0.00').format(v)}';

final _dayFmt = DateFormat('d MMM y');
final _hmFmt = DateFormat('HH:mm');

String fmtActivityTime(DateTime t) => '${_dayFmt.format(t)} · ${_hmFmt.format(t)}';

String dayGroupLabel(DateTime t, DateTime now) {
  final dayDiff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  if (dayDiff == 0) return 'Today';
  if (dayDiff == 1) return 'Yesterday';
  return _dayFmt.format(t);
}

String axisLabelForDuration(Duration span, DateTime t) {
  if (span.inDays <= 1) return _hmFmt.format(t);
  if (span.inDays <= 7) return DateFormat('E').format(t);
  if (span.inDays <= 31) return DateFormat('d MMM').format(t);
  return DateFormat('MMM').format(t);
}

/// Round a span to a "nice" tick step (1-2-5 progression), used by both chart
/// painters so line and candle modes share identical axis geometry.
double niceStep(double rawSpan) {
  final candidates = [1, 2, 2.5, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000, 20000, 25000, 50000, 100000, 200000, 250000, 500000, 1000000, 2000000, 2500000, 5000000, 10000000];
  final step = rawSpan / 4;
  for (final c in candidates) {
    if (c >= step) return c.toDouble();
  }
  return step;
}
