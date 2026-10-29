import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Watchlist tab: starred assets with their live prices and daily moves.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final list = store.favoriteAssets;
    final ui = context.read<UiState>();

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
              const SliverToBoxAdapter(child: ScreenHeader(title: 'Watchlist')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '${list.length} starred ${list.length == 1 ? 'asset' : 'assets'} · updated every minute',
                    style: AppText.body,
                  ),
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.star_border,
                    title: 'Nothing on the watchlist',
                    subtitle: 'Tap the star on any asset to pin its live price here.',
                    ctaLabel: 'Explore markets',
                    onCta: () => ui.setTab(0),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
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
                            trailing: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 34),
                              icon: const Icon(Icons.star, color: AppColors.accent, size: 22),
                              onPressed: () => context.read<MarketStore>().toggleFavorite(a.id),
                            ),
                            onTap: () => ui.openDetail(a.id),
                          ),
                          if (a != list.last) const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: InfoFooter(
                    store.status == MarketStatus.offline
                        ? 'Illustrative market data · USD'
                        : 'Live market data · CoinGecko · USD',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
