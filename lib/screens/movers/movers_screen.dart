import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Movers tab: the day's top-5 gainers and top-5 losers as tap-through
/// tiles. A quick "what's moving right now" view for one glance.
class MoversScreen extends StatelessWidget {
  const MoversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final gainers = store.gainers.take(5).toList();
    final losers = store.losers.take(5).toList();
    final loading = store.status == MarketStatus.loading;

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
              SliverToBoxAdapter(child: ScreenHeader(title: 'Лидеры')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Топ-5 движения за 24 часа · обновляется каждую минуту',
                    style: AppText.body,
                  ),
                ),
              ),
              if (loading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(children: [for (var i = 0; i < 5; i++) const SkeletonRow()]),
                  ),
                )
              else if (gainers.isEmpty && losers.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.trending_up,
                    title: 'Нет данных о движении',
                    subtitle: 'Подождём первое обновление рынка — и плитки появятся.',
                  ),
                )
              else ...[
                _sectionHeader(
                  Icons.trending_up,
                  AppColors.green,
                  'Растут быстрее всех',
                ),
                _grid(gainers),
                _sectionHeader(
                  Icons.trending_down,
                  AppColors.red,
                  'Падают глубже всех',
                ),
                _grid(losers),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: InfoFooter('Автоматический срез рынка · хлебные цифры — 24ч'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, Color color, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
      ),
    );
  }

  Widget _grid(List<Asset> list) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _MoverTile(asset: list[i]),
          childCount: list.length,
        ),
      ),
    );
  }
}

class _MoverTile extends StatelessWidget {
  const _MoverTile({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final color = asset.isUp ? AppColors.green : AppColors.red;

    return InkWell(
      onTap: () => context.read<UiState>().openDetail(asset.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CoinBadge(asset, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asset.symbol, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(asset.name, style: AppText.micro, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(asset.isUp ? Icons.north_east : Icons.south_east, size: 14, color: color),
          ]),
          const Spacer(),
          Text(
            fmt.fmtUsdPrice(asset.price),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 2),
          ChangeText(asset.changePct24h),
        ]),
      ),
    );
  }
}
