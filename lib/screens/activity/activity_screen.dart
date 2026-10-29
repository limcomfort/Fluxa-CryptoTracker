import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Activity tab: the full trade history grouped by day, with filters.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActFilter { all, buys, sells, swaps }

class _ActivityScreenState extends State<ActivityScreen> {
  _ActFilter _filter = _ActFilter.all;

  bool _matches(ActivityEntry e) => switch (_filter) {
        _ActFilter.all => true,
        _ActFilter.buys => e.type == TradeType.buy,
        _ActFilter.sells => e.type == TradeType.sell,
        _ActFilter.swaps => e.type == TradeType.convert,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final entries = store.activity.where(_matches).toList();
    final ui = context.read<UiState>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Activity',
                actions: entries.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Open portfolio',
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 22),
                        onPressed: () => ui.setTab(2),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    for (final f in _ActFilter.values) ...[
                      if (f != _ActFilter.all) const SizedBox(width: 8),
                      FilterChip2(
                        label: switch (f) {
                          _ActFilter.all => 'All',
                          _ActFilter.buys => 'Purchases',
                          _ActFilter.sells => 'Sales',
                          _ActFilter.swaps => 'Swaps',
                        },
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.schedule,
                  title: 'No activity yet',
                  subtitle: 'Buys, sells and conversions land here with full cost details. '
                      'Everything stays on this device.',
                ),
              )
            else
              _buildGroupedList(context, entries),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(String title, double change) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textFaint)),
        ),
      );

  Widget _buildGroupedList(BuildContext context, List<ActivityEntry> entries) {
    final now = DateTime.now();
    final groups = <String, List<ActivityEntry>>{};
    final order = <String>[];
    for (final e in entries) {
      final key = fmt.dayGroupLabel(e.ts, now);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(e);
    }
    return SliverMainAxisGroup(
      slivers: [
        for (final key in order) ...[
          _groupHeader(key, 0),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < groups[key]!.length; i++) ...[
                    _ActivityRow(e: groups[key]![i]),
                    if (i != groups[key]!.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Only demo trades from this device · Fluxa', style: AppText.micro),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.e});
  final ActivityEntry e;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, sub, trailing, trailingColor) = switch (e.type) {
      TradeType.buy => (
        Icons.south_west_rounded,
        AppColors.green,
        'Buy ${e.assetSymbol}',
        '${fmt.fmtActivityTime(e.ts)} · @ ${fmt.fmtUsdPrice(e.priceUsd)}',
        '-${fmt.fmtUsd(e.valueUsd)}',
        AppColors.text,
      ),
      TradeType.sell => (
        Icons.north_east_rounded,
        AppColors.red,
        'Sell ${e.assetSymbol}',
        '${fmt.fmtActivityTime(e.ts)} · @ ${fmt.fmtUsdPrice(e.priceUsd)}',
        '+${fmt.fmtUsd(e.valueUsd)}',
        AppColors.green,
      ),
      _ => (
        Icons.swap_horiz_rounded,
        AppColors.accent,
        'Swap ${e.assetSymbol}',
        '${fmt.fmtActivityTime(e.ts)} · ${fmt.fmtQty(e.qty)} ${e.assetSymbol} → '
            '${fmt.fmtQty(e.counterQty ?? 0)} ${e.counterSymbol ?? ''}',
        fmt.fmtUsd(e.valueUsd),
        AppColors.text,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.title),
            const SizedBox(height: 2),
            Text(sub, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Text(trailing,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: trailingColor)),
      ]),
    );
  }
}
