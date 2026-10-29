import 'package:fl_chart/fl_chart.dart' show PieChart, PieChartData, PieChartSectionData;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../data/illustrative.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';
import 'trade_sheet.dart';

/// Portfolio tab.
///
/// Structure:
///   ● Hero card — total value, 24h drift, P&L vs cost basis
///   ● Allocation donut (fl_chart) with legend
///   ● Top / flop movers of the holdings
///   ● Positions: badge, qty+avg, 24h spark, value + position P&L
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final holdings = store.holdings
        .where((h) => store.assetById(h.assetId) != null)
        .toList();
    final value = store.portfolioValue;
    final pnl = store.portfolioPnl;
    final dayChange = _dayChange(store);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () => context.read<MarketStore>().refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: 'Portfolio',
                  actions: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Trade',
                      icon: const Icon(Icons.add, size: 26),
                      onPressed: () => showTradeSheet(context),
                    ),
                    _PortfolioMenu(),
                  ]),
                ),
              ),
              if (holdings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PortfolioEmpty(),
                )
              else ...[
                SliverToBoxAdapter(child: _HeroCard(value: value, pnl: pnl, dayChange: dayChange)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: _AllocationDonut(holdings: holdings),
                  ),
                ),
                if (holdings.length >= 2)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _MoversStrip(holdings: holdings),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(children: [
                      const Text('Positions', style: AppText.caption),
                      const Spacer(),
                      Text('${holdings.length} assets', style: AppText.micro),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < holdings.length; i++) ...[
                          _PositionRow(holding: holdings[i]),
                          if (i != holdings.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: InfoFooter('${Brand.name} records every fake trade at the market price '
                        'and keeps the ledger on this device.'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static double? _dayChange(MarketStore store) {
    if (store.holdings.isEmpty) return null;
    var sum = 0.0;
    for (final h in store.holdings) {
      final a = store.assetById(h.assetId);
      if (a == null || h.qty <= 0) continue;
      final prev = a.price / (1 + a.changePct24h / 100);
      sum += h.qty * (a.price - prev);
    }
    return sum;
  }
}

// ---------------- hero ----------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.value, required this.pnl, required this.dayChange});
  final double value;
  final ({double pnl, double pnlPct}) pnl;
  final double? dayChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Total value', style: AppText.caption),
          const Spacer(),
          const Icon(Icons.trending_up, size: 16, color: AppColors.textFaint),
          const SizedBox(width: 2),
          const Text('USD', style: AppText.micro),
        ]),
        const SizedBox(height: 8),
        Text(fmt.fmtUsd(value), style: AppText.display),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _MiniStat(
              label: '24h change',
              valueText: dayChange == null ? '—' : fmt.fmtSignedUsd(dayChange!),
              pctText: dayChange == null ? null : fmt.fmtSignedPct(value > 0 ? dayChange! / value * 100 : 0),
              color: (dayChange ?? 0) >= 0 ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniStat(
              label: 'P&L all time',
              valueText: fmt.fmtSignedUsd(pnl.pnl),
              pctText: fmt.fmtSignedPct(pnl.pnlPct),
              color: pnl.pnl >= 0 ? AppColors.green : AppColors.red,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.valueText, required this.pctText, required this.color});
  final String label;
  final String valueText;
  final String? pctText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.micro),
        const SizedBox(height: 4),
        Text(valueText, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: color)),
        if (pctText != null) ...[
          const SizedBox(height: 2),
          Text(pctText!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ]),
    );
  }
}

// ---------------- movers ----------------

class _MoversStrip extends StatelessWidget {
  const _MoversStrip({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final scored = <({Holding h, double pct})>[];
    for (final h in holdings) {
      final a = store.assetById(h.assetId);
      if (a == null || h.costBasis <= 0) continue;
      final value = h.qty * a.price;
      scored.add((h: h, pct: (value - h.costBasis) / h.costBasis * 100));
    }
    if (scored.length < 2) return const SizedBox.shrink();
    scored.sort((x, y) => y.pct.compareTo(x.pct));
    final best = scored.first;
    final flop = scored.last;

    Widget tile(String tag, {required ({Holding h, double pct}) item, required bool isTop}) {
      final a = store.assetById(item.h.assetId)!;
      final color = isTop ? AppColors.green : AppColors.red;
      return Expanded(
        child: InkWell(
          onTap: () => context.read<UiState>().openDetail(a.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(children: [
              CoinBadge(a, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tag, style: AppText.micro),
                  Text(a.symbol, style: AppText.title),
                ]),
              ),
              Icon(isTop ? Icons.trending_up : Icons.trending_down, size: 16, color: color),
              const SizedBox(width: 6),
              Text(fmt.fmtSignedPct(item.pct),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      tile('Top asset', item: best, isTop: true),
      const SizedBox(width: 10),
      tile('Weakest asset', item: flop, isTop: false),
    ]);
  }
}

// ---------------- positions ----------------

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final asset = store.assetById(holding.assetId)!;
    final value = holding.qty * asset.price;
    final posPct = holding.costBasis > 0 ? (value - holding.costBasis) / holding.costBasis * 100 : 0.0;

    return InkWell(
      onTap: () => context.read<UiState>().openDetail(asset.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          CoinBadge(asset, size: 40),
          const SizedBox(width: 11),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asset.name, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${fmt.fmtQty(holding.qty)} ${asset.symbol} · avg ${fmt.fmtPricePlain(holding.avgCost)}',
                  style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Center(
              heightFactor: 1.15,
              child: Sparkline(asset.spark, width: 64, height: 30, color: posPct >= 0 ? AppColors.green : AppColors.red),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.fmtUsd(value), style: AppText.priceMd),
              const SizedBox(height: 2),
              ChangeText(posPct),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- donut ----------------

class _AllocationDonut extends StatelessWidget {
  const _AllocationDonut({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final entries = <({Asset asset, double value, double share})>[];
    var total = 0.0;
    for (final h in holdings) {
      final a = store.assetById(h.assetId);
      if (a == null) continue;
      final v = h.qty * a.price;
      entries.add((asset: a, value: v, share: 0));
      total += v;
    }
    if (total <= 0) return const SizedBox(height: 40);
    final shares = [for (final e in entries) e.value / total];

    return SizedBox(
      height: 150,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: PieChart(
              PieChartData(
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: brandColorOf(entries[i].asset).withValues(alpha: 0.95),
                      radius: 46,
                      showTitle: false,
                    ),
                ],
                sectionsSpace: 2.5,
                centerSpaceRadius: 34,
                startDegreeOffset: -90,
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Allocation', style: AppText.caption),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: brandColorOf(entries[i].asset),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(entries[i].asset.symbol, style: AppText.caption),
                              const Spacer(),
                              Text(fmt.pct1(shares[i] * 100),
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- misc ----------------

class _PortfolioMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          child: const Text('Reset portfolio'),
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Reset portfolio?',
              text: 'All positions and their cost basis will be erased. Trade history stays.',
            );
            if (confirmed && context.mounted) {
              await context.read<MarketStore>().clearPortfolio();
            }
          },
        ),
        MenuItemButton(
          child: const Text('Load demo data'),
          onPressed: () async {
            await context.read<MarketStore>().seedDemoData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loaded 5 demo positions and trade feed')),
              );
            }
          },
        ),
        MenuItemButton(
          child: const Text('About Fluxa'),
          onPressed: () => Brand.showAbout(context),
        ),
      ],
      builder: (ctx, controller, child) => IconButton(
        icon: const Icon(Icons.more_horiz, size: 24),
        onPressed: () => controller.open(),
      ),
    );
  }
}

class _PortfolioEmpty extends StatelessWidget {
  const _PortfolioEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Portfolio is empty',
            subtitle: 'Track what you own in one flow. Buy, sell and convert '
                'at the current market prices.',
            ctaLabel: 'Add first purchase',
            onCta: () => showTradeSheet(context, tab: TradeTab.buy),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${Brand.name} keeps your data on this device.', style: AppText.micro),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, {required String title, required String text}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title, style: AppText.title),
      content: Text(text, style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Reset', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  return res ?? false;
}
