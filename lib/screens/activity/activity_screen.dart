import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Activity tab — the trade ledger of the app.
///
/// Structure:
///   ● Flow summary: total bought / sold / swaps
///   ● Filters: All · Purchases · Sales · Swaps
///   ● Entries grouped by day (Today / Yesterday / date)
///   ● Header menu: clear feed, reset portfolio, about
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Activity',
                actions: _ActivityMenu(hasEntries: entries.isNotEmpty),
              ),
            ),
            if (store.activity.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(children: [
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.schedule,
                      title: 'No activity yet',
                      subtitle: 'Buys, sells and conversions land here with full cost details. '
                          'Everything stays on this device.',
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('${Brand.name} keeps your data on this device.', style: AppText.micro),
                  ),
                ]),
              )
            else ...[
              SliverToBoxAdapter(child: _FlowSummary(entries: store.activity)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: switch (_filter) {
                      _ActFilter.buys => Icons.south_west_rounded,
                      _ActFilter.sells => Icons.north_east_rounded,
                      _ => Icons.swap_horiz_rounded,
                    },
                    title: 'Nothing here yet',
                    subtitle: 'No trades match this filter.',
                  ),
                )
              else
                _buildGroupedList(context, entries),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: InfoFooter('Demo trades only · stored on this device'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, List<ActivityEntry> entries) {
    final now = DateTime.now();
    final groups = <String, List<ActivityEntry>>{};
    final order = <String>[];
    for (final e in entries) {
      final key = fmt.dayGroupLabel(e.ts, now);
      (groups[key] ??= []).add(e);
      if (!order.contains(key)) order.add(key);
    }
    return SliverMainAxisGroup(
      slivers: [
        for (final key in order) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                key == fmt.dayGroupLabel(now, now) ? 'Today' : key,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textFaint),
              ),
            ),
          ),
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
                      const Divider(height: 1, indent: 66, endIndent: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------- summary ----------------

class _FlowSummary extends StatelessWidget {
  const _FlowSummary({required this.entries});
  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    var bought = 0.0, sold = 0.0, swaps = 0;
    for (final e in entries) {
      switch (e.type) {
        case TradeType.buy:
          bought += e.valueUsd;
        case TradeType.sell:
          sold += e.valueUsd;
        default:
          swaps++;
      }
    }
    final hasAny = bought > 0 || sold > 0 || swaps > 0;
    if (!hasAny) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _FlowCard(
            icon: Icons.south_west_rounded,
            color: AppColors.green,
            label: 'In buys',
            value: bought > 0 ? fmt.fmtCompactUsd(bought) : '—',
          ),
          const SizedBox(width: 10),
          _FlowCard(
            icon: Icons.north_east_rounded,
            color: AppColors.red,
            label: 'Out sales',
            value: sold > 0 ? fmt.fmtCompactUsd(sold) : '—',
          ),
          const SizedBox(width: 10),
          _FlowCard(
            icon: Icons.swap_horiz_rounded,
            color: AppColors.accent,
            label: 'Swaps',
            value: swaps > 0 ? '$swaps' : '—',
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text(label, style: AppText.micro),
        ]),
      ),
    );
  }
}

// ---------------- menu ----------------

class _ActivityMenu extends StatelessWidget {
  const _ActivityMenu({required this.hasEntries});
  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          child: const Text('Clear activity feed'),
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Clear activity feed?',
              text: 'The trade history will be wiped. Portfolios are kept.',
            );
            if (confirmed && context.mounted) {
              await context.read<MarketStore>().clearActivity();
            }
          },
        ),
        MenuItemButton(
          child: const Text('Reset portfolio'),
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Reset portfolio?',
              text: 'All positions and their cost basis will be erased.',
            );
            if (confirmed && context.mounted) {
              final store = context.read<MarketStore>();
              await store.clearActivity();
              await store.clearPortfolio();
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

// ---------------- rows ----------------

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.e});
  final ActivityEntry e;

  @override
  Widget build(BuildContext context) {
    final ((String, IconData, Color), String, String, (String, Color?)) t = switch (e.type) {
      TradeType.buy => (
        ('Buy ${fmt.fmtQty(e.qty)} ${e.assetSymbol}', Icons.south_west_rounded, AppColors.green),
        '@ ${fmt.fmtPricePlain(e.priceUsd)}',
        fmt.fmtActivityTime(e.ts),
        ('-${fmt.fmtUsd(e.valueUsd)}', null),
      ),
      TradeType.sell => (
        ('Sell ${fmt.fmtQty(e.qty)} ${e.assetSymbol}', Icons.north_east_rounded, AppColors.red),
        '@ ${fmt.fmtPricePlain(e.priceUsd)}',
        fmt.fmtActivityTime(e.ts),
        ('+${fmt.fmtUsd(e.valueUsd)}', AppColors.green),
      ),
      _ => (
        (
          'Swap ${fmt.fmtQty(e.counterQty ?? 0)} ${e.counterSymbol ?? ''}',
          Icons.swap_horiz_rounded,
          AppColors.accent,
        ),
        '${fmt.fmtQty(e.qty)} ${e.assetSymbol} · ${fmt.fmtUsd(e.valueUsd)}',
        fmt.fmtActivityTime(e.ts),
        (fmt.fmtUsd(e.valueUsd), null),
      ),
    };

    final (title, icon, color) = t.$1;
    final (amount, amountColor) = t.$4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(t.$2, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.$3, style: AppText.micro),
            ]),
          ),
          Text(amount,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: amountColor ?? AppColors.text)),
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
          child: const Text('Clear', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  return res ?? false;
}
