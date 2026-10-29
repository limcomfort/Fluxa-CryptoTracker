import 'package:fl_chart/fl_chart.dart'
    show PieChart, PieChartData, PieChartSectionData;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../data/illustrative.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';
import 'trade_sheet.dart';

/// Portfolio tab: total value, allocation donut (fl_chart), holdings list
/// and the trade sheet for buy / sell / convert.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final holdings = store.holdings;
    final value = store.portfolioValue;
    final pnl = store.portfolioPnl;

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
                  actions: IconButton(
                    icon: const Icon(Icons.add, size: 26),
                    tooltip: 'Trade',
                    onPressed: () => showTradeSheet(context),
                  ),
                ),
              ),
              if (holdings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      _PortfolioEmpty(),
                    ],
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmt.fmtUsd(value), style: AppText.display),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(pnl.pnl >= 0 ? Icons.north_east : Icons.south_east,
                              size: 15, color: pnl.pnl >= 0 ? AppColors.green : AppColors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${fmt.fmtSignedUsd(pnl.pnl)} (${fmt.fmtSignedPct(pnl.pnlPct)})',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: pnl.pnl >= 0 ? AppColors.green : AppColors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('vs cost basis', style: AppText.caption),
                        ]),
                      ],
                    ),
                  ),
                ),
                // ---------- allocation donut ----------
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: _AllocationDonut(holdings: holdings),
                  ),
                ),
                // ---------- assets ----------
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: const SliverToBoxAdapter(
                    child: Text('Assets', style: AppText.caption),
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
                          _HoldingRow(holding: holdings[i]),
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
                    child: InfoFooter(
                      'Cost basis is recorded at the moment of every fake trade · Price: '
                      '${store.status == MarketStatus.offline ? 'illustrative' : 'live'}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioEmpty extends StatelessWidget {
  const _PortfolioEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Portfolio is empty',
            subtitle: "Track what you own in one flow. Buy, sell and convert "
                "at the current market prices.",
            ctaLabel: 'Add first purchase',
            onCta: () => showTradeSheet(context, tab: TradeTab.buy),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('${Brand.name} keeps your data on this device.', style: AppText.micro),
        ),
      ],
    );
  }
}

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
    sections() => [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              color: brandColorOf(entries[i].asset).withValues(alpha: 0.95),
              radius: 46,
              showTitle: false,
            ),
        ];

    return SizedBox(
      height: 150,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: PieChart(
              PieChartData(
                sections: sections(),
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
                Text(
                  'Allocation',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDim),
                ),
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

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final asset = store.assetById(holding.assetId);
    if (asset == null) return const SizedBox.shrink();
    final value = holding.qty * asset.price;
    final pnlPct = holding.costBasis > 0 ? (value - holding.costBasis) / holding.costBasis * 100 : 0.0;
    final ui = context.read<UiState>();

    return InkWell(
      onTap: () => ui.openDetail(asset.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CoinBadge(asset, size: 40),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmt.fmtQty(holding.qty)} ${asset.symbol}', style: AppText.title),
              const SizedBox(height: 2),
              Text('Cost ${fmt.fmtUsd(holding.costBasis)}', style: AppText.caption),
            ]),
          ),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.fmtUsd(value), style: AppText.priceMd),
              const SizedBox(height: 2),
              ChangeText(pnlPct),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.swap_horiz, color: AppColors.textDim, size: 22),
            tooltip: 'Trade this asset',
            onPressed: () => showTradeSheet(context, tab: TradeTab.convert, prefillAssetId: asset.id),
          ),
        ]),
      ),
    );
  }
}
