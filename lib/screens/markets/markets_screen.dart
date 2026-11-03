import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';
import '../converter/converter_screen.dart' show openConverter;
import '../search/search_screen.dart';

enum MarketFilter { all, favorites, topVolume }

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  MarketFilter filter = MarketFilter.all;

  List<Asset> _visible(MarketStore store) {
    switch (filter) {
      case MarketFilter.all:
        return store.assets;
      case MarketFilter.favorites:
        return store.favoriteAssets;
      case MarketFilter.topVolume:
        // Most traded assets of the day, descending by 24h turnover.
        final byVolume = [...store.assets]
          ..sort((a, b) => b.volume24h.compareTo(a.volume24h));
        return byVolume.take(25).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final list = _visible(store);
    final totals = store.marketTotals;
    final loading = store.status == MarketStatus.loading;

    final footer = switch (store.status) {
      MarketStatus.loading => const InfoFooter('Загружаем котировки...'),
      MarketStatus.offline => const InfoFooter('Демонстрационные данные рынка · USD'),
      MarketStatus.ready => const InfoFooter('Живые данные рынка · CoinGecko · USD'),
    };

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
                  title: 'Рынки',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Конвертер',
                        icon: const Icon(Icons.swap_horiz, size: 24),
                        onPressed: () => openConverter(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 24),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      for (final f in MarketFilter.values) ...[
                        if (f != MarketFilter.all) const SizedBox(width: 8),
                        FilterChip2(
                          label: switch (f) {
                            MarketFilter.all => 'Все',
                            MarketFilter.favorites => 'Избранное',
                            MarketFilter.topVolume => 'Топ по объёму',
                          },
                          selected: filter == f,
                          onTap: () => setState(() => filter = f),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Капитализация', style: AppText.caption),
                          const SizedBox(height: 3),
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(fmt.fmtCompactUsd(totals.cap),
                                  style: const TextStyle(
                                      fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
                              const SizedBox(width: 6),
                              ChangeText(totals.capChange),
                            ],
                          ),
                        ]),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Объём 24ч', style: AppText.caption),
                          const SizedBox(height: 3),
                          Text(fmt.fmtCompactUsd(totals.volume),
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text('Актив', style: AppText.micro)),
                      Expanded(flex: 4, child: Text('Тренд 24ч', style: AppText.micro)),
                      Expanded(
                        flex: 5,
                        child: Text('Цена / 24ч', textAlign: TextAlign.right, style: AppText.micro),
                      ),
                    ],
                  ),
                ),
              ),
              if (!loading && store.status == MarketStatus.offline)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: OfflineBanner(
                      onRetry: () => context.read<MarketStore>().refresh(),
                    ),
                  ),
                ),
              if (loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(children: [for (var i = 0; i < 9; i++) const SkeletonRow()]),
                  ),
                )
              else if (filter == MarketFilter.favorites && list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.star_border,
                    title: 'В избранном пусто',
                    subtitle: 'Нажмите звёздочку у актива, чтобы закрепить его цену и движение за день в одном месте.',
                    ctaLabel: 'Смотреть все',
                    onCta: () => setState(() => filter = MarketFilter.all),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final a in list) ...[
                          MarketRow(
                            a,
                            onTap: () => context.read<UiState>().openDetail(a.id),
                          ),
                          if (a != list.last) const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                sliver: SliverToBoxAdapter(child: footer),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
            ],
          ),
        ),
      ),
    );
  }
}
