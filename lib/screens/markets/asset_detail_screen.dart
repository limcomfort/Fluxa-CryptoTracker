import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart'
    show AxisTitles, BarAreaData, ExtraLinesData, FlBorderData, FlDotData, FlGridData, FlLine, FlSpot, FlTitlesData, HorizontalLine, LineChart, LineChartBarData, LineChartData, LineTouchData, SideTitles;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as f;
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../data/market_repository.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

enum ChartMode { line, candles }

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key, required this.assetId});
  final String assetId;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  ChartRange _range = ChartRange.d1;
  ChartMode _mode = ChartMode.candles;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final asset = store.assetById(widget.assetId);
    if (asset == null) {
      return const Scaffold(body: Center(child: Text('Asset is unavailable', style: AppText.title)));
    }
    final fav = store.isFavorite(asset.id);
    final isUp = asset.isUp;
    final live = store.source == DataSource.live;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: context.read<UiState>().closeDetail,
        ),
        centerTitle: true,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          CoinBadge(asset, size: 30),
          const SizedBox(width: 9),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(asset.symbol, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            Text(asset.name, style: const TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.1)),
          ]),
        ],
        ),
        actions: [
          IconButton(
            icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? AppColors.accent : AppColors.textFaint),
            onPressed: () => context.read<MarketStore>().toggleFavorite(asset.id),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            // ---------- price header ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                PriceFlash(price: asset.price, style: AppText.priceLg, flash: live),
                const SizedBox(width: 6),
                const Text('USD', style: AppText.caption),
              ]),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(children: [
                Icon(isUp ? Icons.north_east : Icons.south_east,
                    size: 15, color: isUp ? AppColors.green : AppColors.red),
                const SizedBox(width: 4),
                Text('${fmt.fmtSignedUsd(asset.changeAbs24h)} (${fmt.fmtSignedPct(asset.changePct24h)})',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isUp ? AppColors.green : AppColors.red,
                    )),
                const SizedBox(width: 8),
                const Text('24h', style: AppText.caption),
              ]),
            ),
            const SizedBox(height: 18),

            // ---------- range selector ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  for (final r in ChartRange.values)
                    Expanded(
                      child: _RangeCell(
                        label: r.label,
                        selected: _range == r,
                        onTap: () => setState(() => _range = r),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ---------- chart section ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('Price chart', style: AppText.caption),
                const Spacer(),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Selector<MarketStore, int>(
              selector: (_, s) => s.generation,
              builder: (context, gen, _) => _SeriesAsset2 (
                asset: asset,
                range: _range,
                mode: _mode,
                generation: gen,
              ),
            ),
            const SizedBox(height: 24),

            // ---------- market statistics ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Market statistics',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 14),
                Row(children: [
                  _StatCell(label: '24h high', value: fmt.fmtUsdPrice(asset.high24h)),
                  _StatCell(label: '24h low', value: fmt.fmtUsdPrice(asset.low24h)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _StatCell(label: 'Market cap', value: fmt.fmtCompactUsd(asset.marketCap)),
                  _StatCell(label: '24h volume', value: fmt.fmtCompactUsd(asset.volume24h)),
                ]),
              ]),
            ),
            const SizedBox(height: 22),

            // ---------- about ----------
            _AboutTile(asset: asset),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InfoFooter(live ? 'Live market data · CoinGecko · USD' : 'Illustrative market data · USD'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------- widgets ----------------

class _RangeCell extends StatelessWidget {
  const _RangeCell({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.accent : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final ChartMode mode;
  final ValueChanged<ChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Segment('Line', mode == ChartMode.line, () => onChanged(ChartMode.line)),
        _Segment('Candles', mode == ChartMode.candles, () => onChanged(ChartMode.candles)),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.accent : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
      ]),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('About ${asset.name}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(asset.about, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textFaint),
        ]),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final store = context.read<MarketStore>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CoinBadge(asset, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asset.name, style: AppText.display.copyWith(fontSize: 22)),
              Text('#${asset.rank.toString().padLeft(2, '0')} · ${asset.symbol}', style: AppText.caption),
            ])),
          ]),
          const SizedBox(height: 16),
          Text(asset.about, style: AppText.body),
          const SizedBox(height: 18),
          _sheetRow('24h high', fmt.fmtUsdPrice(asset.high24h)),
          _sheetRow('24h low', fmt.fmtUsdPrice(asset.low24h)),
          _sheetRow('Market cap', fmt.fmtCompactUsd(asset.marketCap)),
          _sheetRow('24h volume', fmt.fmtCompactUsd(asset.volume24h)),
          _sheetRow('24h change', fmt.fmtSignedPct(asset.changePct24h)),
          _sheetRow('Data source',
              '${store.source == DataSource.live ? 'CoinGecko · live' : 'Illustrative (offline fallback)'} · USD'),
        ]),
      ),
    );
  }

  Widget _sheetRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: AppText.body),
          Text(v, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ---------------- chart ----------------

class _SeriesAsset2 extends StatelessWidget {
  // Name regulated to avoid a typo conflict: AssetDetail chart that owns the series future.
  const _SeriesAsset2({required this.asset, required this.range, required this.mode, required this.generation});
  final Asset asset;
  final ChartRange range;
  final ChartMode mode;
  final int generation;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MarketRepository>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<RangeSeries>(
        future: repo.loadRange(asset, range),
        key: ValueKey('${asset.id}-${range.name}-${mode.name}-$generation'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 268,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            );
          }
          final data = snap.data!;
          final series = mode == ChartMode.line || data.points.isEmpty ? null : data.candles;
          final pts = series == null ? data.points : null;
          return PriceChart(
            candles: series,
            points: pts,
            mode: mode,
            range: range,
            lastPrice: asset.price,
            height: 268,
          );
        },
      ),
    );
  }
}

class PriceChart extends StatelessWidget {
  const PriceChart({
    super.key,
    required this.candles,
    required this.points,
    required this.mode,
    required this.range,
    required this.lastPrice,
    this.height = 268,
  });

  final List<Candle>? candles; // non-null in candles mode
  final List<TimePoint>? points; // non-null in line mode
  final ChartMode mode;
  final ChartRange range;
  final double lastPrice;
  final double height;

  static const double rightReserved = 62;
  static const double bottomReserved = 30;

  @override
  Widget build(BuildContext context) {
    // Train values for the axis window.
    double minV, maxV;
    if (candles != null && candles!.isNotEmpty) {
      minV = candles!.first.l;
      maxV = candles!.first.h;
      for (final c in candles!) {
        if (c.l < minV) minV = c.l;
        if (c.h > maxV) maxV = c.h;
      }
    } else if (points != null && points!.isNotEmpty) {
      minV = maxV = points!.first.p;
      for (final p in points!) {
        if (p.p < minV) minV = p.p;
        if (p.p > maxV) maxV = p.p;
      }
    } else {
      return SizedBox(height: height);
    }
    minV = math.min(minV, lastPrice);
    maxV = math.max(maxV, lastPrice);
    var span = (maxV - minV).abs();
    if (span < 1e-9) span = maxV * 0.01 + 1e-9;
    minV -= span * 0.08;
    maxV += span * 0.08;
    span = maxV - minV;
    final step = fmt.niceStep(span);
    final gridMin = (minV / step).floorToDouble() * step;
    final gridMax = (maxV / step).ceilToDouble() * step;
    if (gridMax - gridMin < step) return SizedBox(height: height);

    final geom = _Geom(
      gridMin: gridMin,
      gridMax: gridMax,
      step: step,
      lastPrice: lastPrice,
      range: range,
      n: candles?.length ?? points!.length,
    );

    final chart = SizedBox(
      height: height + bottomReserved,
      child: Stack(
        children: [
          Positioned.fill(
            right: rightReserved,
            bottom: bottomReserved,
            child: candles != null
                ? CustomPaint(
                    painter: _CandleChartPainter(geom, candles!),
                    size: Size(double.infinity, height),
                  )
                : _buildLineChart(context, geom, points!),
          ),
          // Current-price badge, identical for both modes.
          Positioned(
            top: (geom.yFrac(lastPrice) * height - 12).clamp(0.0, height - 24),
            right: rightReserved + 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                fmt.fmtPricePlain(lastPrice),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        Padding(
          padding: const EdgeInsets.only(top: 10, right: rightReserved, left: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_rangeSubtitle(range), style: AppText.micro),
              const Text('UTC', style: AppText.micro),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, _Geom geom, List<TimePoint> pts) {
    final n = pts.length;
    final ticks = _tickIdx(n);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: geom.gridMin,
        maxY: geom.gridMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (geom.gridMax - geom.gridMin) / 2,
          getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFF191B1F), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: (geom.gridMax - geom.gridMin) / 2,
              getTitlesWidget: (v, meta) => Text(
                _axisFmt(v, geom.step),
                style: AppText.micro,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (!ticks.contains(idx)) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_xLabel(pts[idx].t, range), style: AppText.micro),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), pts[i].p)],
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            barWidth: 2.2,
            isStrokeCapRound: true,
            color: AppColors.accent,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: lastPrice,
              color: AppColors.accent,
              strokeWidth: 1.2,
              dashArray: [6, 5],
            ),
          ],
        ),
      ),
    );
  }
}

class _Geom {
  _Geom({
    required this.gridMin,
    required this.gridMax,
    required this.step,
    required this.lastPrice,
    required this.range,
    required this.n,
  });
  final double gridMin;
  final double gridMax;
  final double step;
  final double lastPrice;
  final ChartRange range;
  final int n;

  double yFrac(double v) => (gridMax - v) / (gridMax - gridMin);
}

/// Evenly spread tick indices (5 x-labels like the mock).
List<int> _tickIdx(int n) {
  if (n < 5) return [for (var i = 0; i < n; i++) i];
  return [0, ((n - 1) * 0.25).round(), ((n - 1) * 0.5).round(), ((n - 1) * 0.75).round(), n - 1];
}

String _axisFmt(double v, double step) {
  if (step >= 1) return f.NumberFormat('#,##0').format(v);
  if (step >= 0.1) return v.toStringAsFixed(2);
  if (step >= 0.001) return v.toStringAsFixed(4);
  return v.toStringAsFixed(6);
}

String _xLabel(DateTime t, ChartRange r) => switch (r) {
      ChartRange.h1 || ChartRange.d1 => f.DateFormat('HH:mm').format(t.toUtc()),
      ChartRange.w1 => f.DateFormat('E').format(t.toUtc()),
      ChartRange.m1 => f.DateFormat('d MMM').format(t.toUtc()),
      ChartRange.y1 => f.DateFormat('MMM').format(t.toUtc()),
    };

String _rangeSubtitle(ChartRange r) => switch (r) {
      ChartRange.h1 => '1 hour',
      ChartRange.d1 => '24 hours',
      ChartRange.w1 => '7 days',
      ChartRange.m1 => '30 days',
      ChartRange.y1 => '1 year',
    };

/// Candlestick painter with the same axis geometry as the fl_chart line mode.
class _CandleChartPainter extends CustomPainter {
  _CandleChartPainter(this.geom, this.candles);
  final _Geom geom;
  final List<Candle> candles;

  static const _gridColor = Color(0xFF191B1F);

  @override
  void paint(Canvas canvas, Size size) {
    final levels = [geom.gridMin, geom.gridMin + (geom.gridMax - geom.gridMin) / 2, geom.gridMax];
    final labelStyle = const TextStyle(fontSize: 11, color: Color(0xFF62686F));

    // horizontal grid + right labels
    for (final lvl in levels) {
      final y = geom.yFrac(lvl) * size.height;
      final paint = Paint()
        ..color = _gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      _drawText(canvas, _axisFmt(lvl, geom.step), Offset(size.width + 10, y - 6), labelStyle);
    }

    // x time labels
    final ticks = _tickIdx(candles.length);
    final columnW = size.width / candles.length;
    for (final i in ticks) {
      final x = (i + 0.5) * columnW;
      _drawText(canvas, _xLabel(candles[i].t, geom.range), Offset(x - 16, size.height + 10), labelStyle,
          width: 32);
    }

    // draw candles
    final bodyW = math.max(2.0, columnW * 0.58);
    final wickPaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.green;
    final bodyPaint = Paint()..color = AppColors.green;

    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final color = c.isUp ? AppColors.green : AppColors.red;
      final xc = (i + 0.5) * columnW;
      final yTop = geom.yFrac(c.h) * size.height;
      final yBot = geom.yFrac(c.l) * size.height;
      final yO = geom.yFrac(c.o) * size.height;
      final yC = geom.yFrac(c.c) * size.height;
      wickPaint.color = color;
      bodyPaint.color = color;
      canvas.drawLine(Offset(xc, yTop), Offset(xc, yBot), wickPaint);
      final bodyTop = math.min(yO, yC);
      final bodyBot = math.max(yO, yC);
      final rect = Rect.fromLTRB(xc - bodyW / 2, bodyTop, xc + bodyW / 2,
          math.max(bodyBot, bodyTop + 1.5));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(math.max(bodyW * 0.08, 0)), const Radius.circular(2)),
        bodyPaint,
      );
    }

    // dashed current price line
    final y = geom.yFrac(geom.lastPrice) * size.height;
    final dash = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.2;
    const gap = 6.0;
    for (var x = 0.0; x < size.width; x += gap * 2) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + gap, size.width), y), dash);
    }
  }

  void _drawText(Canvas canvas, String text, Offset off, TextStyle style, {double? width}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width ?? 56);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(covariant _CandleChartPainter old) => old.geom.n != geom.n || old.candles != candles;
}
