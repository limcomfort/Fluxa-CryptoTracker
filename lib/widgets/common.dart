import 'package:fl_chart/fl_chart.dart'
    show BarAreaData, FlBorderData, FlDotData, FlGridData, FlSpot, FlTitlesData, LineChart, LineChartBarData, LineChartData, LineTouchData;
import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/formatters.dart' as fmt;
import '../core/theme.dart';
import '../data/illustrative.dart';
import '../models/models.dart';

/// Coin logo circle: remote image when available, glyph/initials otherwise.
class CoinBadge extends StatelessWidget {
  const CoinBadge(this.asset, {super.key, this.size = 40, this.showInitials = true});

  final Asset asset;
  final double size;
  final bool showInitials;

  @override
  Widget build(BuildContext context) {
    final glyph = _shortGlyph(asset.glyph, asset.symbol);
    final bg = brandColorOf(asset);

    final inner = asset.imageUrl == null
        ? Center(child: _roundText(glyph, size))
        : Image.network(
            asset.imageUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Center(child: _roundText(glyph, size)),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  String _shortGlyph(String glyph, String symbol) => glyph.length <= 2 ? glyph : symbol.substring(0, 2);

  Widget _roundText(String glyph, double size) => Text(
        glyph,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      );
}

/// Mini price-trend line used in list rows (an oscilloscope of the asset flow).
class Sparkline extends StatelessWidget {
  const Sparkline(this.points, {super.key, this.width = 84, this.height = 36, this.color});

  final List<double> points;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(width: width, height: height);
    }
    var minY = points.first, maxY = points.first;
    for (final p in points) {
      if (p < minY) minY = p;
      if (p > maxY) maxY = p;
    }
    final pad = (maxY - minY) * 0.15 + maxY * 1e-6;
    final data = LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i])],
          isCurved: true,
          curveSmoothness: 0.35,
          barWidth: 1.8,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          color: color ?? AppColors.green,
        ),
      ],
    );
    return SizedBox(
      width: width,
      height: height,
      child: LineChart(data, duration: Duration.zero),
    );
  }
}

/// Pill filter chip from the mockups (All / Favorites / Gainers / Losers ...).
class FilterChip2 extends StatelessWidget {
  const FilterChip2({super.key, required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: selected ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
      foregroundColor: selected ? AppColors.accent : AppColors.textDim,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return OutlinedButton(style: style, onPressed: onTap, child: Text(label));
  }
}

/// Change-percentage text with its own color.
class ChangeText extends StatelessWidget {
  const ChangeText(this.pct, {super.key, this.textStyle, this.showSign = true});
  final double pct;
  final TextStyle? textStyle;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    return Text(
      showSign ? fmt.fmtSignedPct(pct) : fmt.fmtSignedPct(pct).replaceFirst(RegExp('^[+-]'), ''),
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600).copyWith(
        color: pct >= 0 ? AppColors.green : AppColors.red,
      ).merge(textStyle),
    );
  }
}

/// "ⓘ ..." footer line, tappable -> brand About dialog.
class InfoFooter extends StatelessWidget {
  const InfoFooter(this.text, {super.key, this.onTap, this.showAbout = true});
  final String text;
  final VoidCallback? onTap;
  final bool showAbout;

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      const Icon(Icons.info_outline, size: 14, color: AppColors.textFaint),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: AppText.micro, overflow: TextOverflow.ellipsis)),
    ]);
    return GestureDetector(
      onTap: onTap ?? (showAbout ? () => Brand.showAbout(context) : null),
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row),
    );
  }
}

/// Offline banner with the Retry button (exact mock copy).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.text, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Не удалось обновить цены', style: AppText.title),
            SizedBox(height: 3),
            Text('Рыночный API недоступен.\nПоказаны последние сохранённые цены.', style: AppText.body),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Повторить'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// Skeleton row used while the markets are loading.
class SkeletonRow extends StatefulWidget {
  const SkeletonRow({super.key});
  @override
  State<SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<SkeletonRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.9).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(children: [
          _Sk(w: 42, h: 42, r: 21),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Sk(w: 110, h: 12, r: 6),
            SizedBox(height: 7),
            _Sk(w: 64, h: 10, r: 5),
          ])),
          _Sk(w: 80, h: 30, r: 6),
          SizedBox(width: 28),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _Sk(w: 84, h: 12, r: 6),
            SizedBox(height: 7),
            _Sk(w: 52, h: 10, r: 5),
          ]),
        ]),
      ),
    );
  }
}

class _Sk extends StatelessWidget {
  const _Sk({required this.w, required this.h, required this.r});
  final double w, h, r;
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(r)),
      );
}

/// Market list row (Markets / Search / Watchlist share it).
class MarketRow extends StatelessWidget {
  const MarketRow(this.asset, {super.key, this.onTap, this.trailing});
  final Asset asset;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CoinBadge(asset, size: 40),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asset.name, style: AppText.title, overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 2),
              Text(asset.symbol, style: AppText.caption),
            ]),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Sparkline(
                asset.spark,
                color: asset.isUp ? AppColors.green : AppColors.red,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.fmtUsdPrice(asset.price), style: AppText.priceMd),
              const SizedBox(height: 2),
              ChangeText(asset.changePct24h),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}

/// Screen header used by tab screens (title + optional action button).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.actions});
  final String title;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.display)),
        ?actions,
      ]),
    );
  }
}

/// Rounded outlined button for the mock empty states.
class CtaButton extends StatelessWidget {
  const CtaButton(this.label, {super.key, this.onTap, this.filled = false});
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: filled ? Colors.black : AppColors.accent,
        backgroundColor: filled ? AppColors.accent : Colors.transparent,
        side: const BorderSide(color: AppColors.accent, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// Generic mock-style empty state (icon badge, title, subtitle, optional CTA).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.textDim, size: 27),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.body),
          if (ctaLabel != null) ...[
            const SizedBox(height: 18),
            CtaButton(ctaLabel!, onTap: onCta),
          ],
        ]),
      ),
    );
  }
}

/// Price text that flashes green/red whenever the quote changes.
class PriceFlash extends StatefulWidget {
  const PriceFlash({super.key, required this.price, this.style, this.flash = true});
  final double price;
  final TextStyle? style;
  final bool flash;

  @override
  State<PriceFlash> createState() => _PriceFlashState();
}

class _PriceFlashState extends State<PriceFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  Color? _flashColor;

  @override
  void didUpdateWidget(covariant PriceFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash && oldWidget.price != widget.price && widget.price != 0) {
      _flashColor = widget.price > oldWidget.price ? AppColors.green : AppColors.red;
      _c.forward(from: 0);
    } else if (!_c.isAnimating) {
      _flashColor = null;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = (1 - _c.value).clamp(0.0, 1.0); // fade out
        return Text(
          fmt.fmtUsdPrice(widget.price),
          style: widget.style == null
              ? const TextStyle(inherit: true)
              : widget.style!.merge(TextStyle(color: Color.lerp(
                  widget.style!.color ?? AppColors.text,
                  _flashColor,
                  (_flashColor != null ? t * 0.85 : 0),
                ))),
        );
      },
    );
  }
}
