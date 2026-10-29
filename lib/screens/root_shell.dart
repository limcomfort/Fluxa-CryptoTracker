import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/market_store.dart';
import 'activity/activity_screen.dart';
import 'markets/asset_detail_screen.dart';
import 'markets/markets_screen.dart';
import 'portfolio/portfolio_screen.dart';
import 'watchlist/watchlist_screen.dart';
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _pages = [
    MarketsScreen(),
    WatchlistScreen(),
    PortfolioScreen(),
    ActivityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiState>();
    final detail = ui.detailAssetId != null;

    return PopScope(
      canPop: !detail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && detail) ui.closeDetail();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: detail
                ? AssetDetailScreen(
                    key: ValueKey('detail-${ui.detailAssetId}'),
                    assetId: ui.detailAssetId!,
                  )
                : IndexedStack(
                    key: const ValueKey('tabs'),
                    index: ui.tab,
                    children: _pages,
                  ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: ui.tab,
            onTap: ui.setTab,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.candlestick_chart_outlined),
                activeIcon: Icon(Icons.candlestick_chart),
                label: 'Markets',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.star_border),
                activeIcon: Icon(Icons.star),
                label: 'Watchlist',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Portfolio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule),
                label: 'Activity',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
