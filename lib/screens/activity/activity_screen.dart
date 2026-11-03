import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Signals tab — the analytical event feed of the app.
///
/// Auto-generated market observations (momentum, regime shifts, 24h
/// extremes) plus watchlist / portfolio events. No trades whatsoever.
///
/// Structure:
///   ● Pulse summary: bullish / bearish signal counts + tracked assets
///   ● Filters: All · Bullish · Bearish · Tracking
///   ● Entries grouped by day (Today / Yesterday / date)
///   ● Header menu: clear feed, about
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum _SigFilter { all, ups, downs, tracking }

class _ActivityScreenState extends State<ActivityScreen> {
  _SigFilter _filter = _SigFilter.all;

  bool _matches(SignalEntry e) => switch (_filter) {
        _SigFilter.all => true,
        _SigFilter.ups => e.kind == SignalKind.up,
        _SigFilter.downs => e.kind == SignalKind.down,
        _SigFilter.tracking => e.kind == SignalKind.watch || e.kind == SignalKind.info,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final entries = store.signals.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Сигналы',
                actions: _SignalsMenu(hasEntries: entries.isNotEmpty),
              ),
            ),
            if (store.signals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const EmptyState(
                      icon: Icons.auto_graph,
                      title: 'Сигналов пока нет',
                      subtitle: 'Импульсы рынка, смена режима и события избранного '
                          'приходят сюда автоматически при обновлении данных.',
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('${Brand.name} генерирует сигналы локально на этом устройстве.', style: AppText.micro),
                    ),
                  ]),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _PulseSummary(store: store)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                  child: Row(
                    children: [
                      for (final f in _SigFilter.values) ...[
                        if (f != _SigFilter.all) const SizedBox(width: 8),
                        FilterChip2(
                          label: switch (f) {
                            _SigFilter.all => 'Все',
                            _SigFilter.ups => 'Рост',
                            _SigFilter.downs => 'Падение',
                            _SigFilter.tracking => 'Отслеживание',
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
                      _SigFilter.ups => Icons.trending_up,
                      _SigFilter.downs => Icons.trending_down,
                      _ => Icons.notifications_active_outlined,
                    },
                    title: 'Здесь пока пусто',
                    subtitle: 'Сигналов этого типа ещё нет — появятся при обновлении рынка.',
                  ),
                )
              else
                _buildGroupedList(context, entries),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: InfoFooter('Автоматические аналитические сигналы · хранятся на устройстве'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, List<SignalEntry> entries) {
    final now = DateTime.now();
    final groups = <String, List<SignalEntry>>{};
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
                key == fmt.dayGroupLabel(now, now) ? 'Сегодня' : key,
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
                    _SignalRow(e: groups[key]![i]),
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

// ---------------- pulse summary ----------------

class _PulseSummary extends StatelessWidget {
  const _PulseSummary({required this.store});
  final MarketStore store;

  @override
  Widget build(BuildContext context) {
    var ups = 0, downs = 0;
    for (final e in store.signals) {
      switch (e.kind) {
        case SignalKind.up:
          ups++;
        case SignalKind.down:
          downs++;
        default:
          break;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _PulseCard(
            icon: Icons.north_east_rounded,
            color: AppColors.green,
            label: 'Рост',
            value: '$ups',
          ),
          const SizedBox(width: 10),
          _PulseCard(
            icon: Icons.south_east_rounded,
            color: AppColors.red,
            label: 'Падение',
            value: '$downs',
          ),
          const SizedBox(width: 10),
          _PulseCard(
            icon: Icons.visibility_outlined,
            color: AppColors.accent,
            label: 'Отслеживание',
            value: '${store.holdings.length}',
          ),
        ],
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.icon, required this.color, required this.label, required this.value});
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

class _SignalsMenu extends StatelessWidget {
  const _SignalsMenu({required this.hasEntries});
  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          child: const Text('Очистить ленту'),
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Очистить ленту сигналов?',
              text: 'Все сгенерированные сигналы и события будут удалены безвозвратно.',
            );
            if (confirmed && context.mounted) {
              await context.read<MarketStore>().clearSignals();
            }
          },
        ),
        MenuItemButton(
          child: const Text('О приложении Fluxa'),
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

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.e});
  final SignalEntry e;

  @override
  Widget build(BuildContext context) {
    final (icon: icon, color: color) = switch (e.kind) {
      SignalKind.up => (icon: Icons.trending_up, color: AppColors.green),
      SignalKind.down => (icon: Icons.trending_down, color: AppColors.red),
      SignalKind.watch => (icon: Icons.visibility_outlined, color: AppColors.accent),
      _ => (icon: Icons.info_outline_rounded, color: AppColors.textDim),
    };

    final store = context.watch<MarketStore>();
    final asset = e.assetId == null ? null : store.assetById(e.assetId);

    final row = Padding(
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
              Text(e.title, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(e.subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${fmt.fmtActivityTime(e.ts)} · авто-сигнал', style: AppText.micro),
            ]),
          ),
          if (asset != null) ...[CoinBadge(asset, size: 26), const SizedBox(width: 4)],
        ],
      ),
    );

    if (asset == null) return row;
    return InkWell(
      onTap: () => context.read<UiState>().openDetail(asset.id),
      child: row,
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
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Очистить', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  return res ?? false;
}
