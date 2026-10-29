# Fluxa — crypto & financial market tracker (Flutter)

**Fluxa** — from *flux*: the flow of prices, candles and conversions that never
stand still. The app keeps that flow alive with a 60-second auto-refresh
"pulse" of live market data and offline fallback so the picture never goes dark.

Dark UI with an amber accent, four tabs (**Markets · Watchlist · Portfolio · Activity**),
a converter screen and a search screen. Live prices come from the
[CoinGecko public API](https://www.coingecko.com/en/api); when the network is
away the app shows the last saved prices with illustrative illustrative-series
fallback (same behaviour as the mockups: *"Unable to refresh prices · Showing
the last saved prices"*).

## Features

- **Markets** — asset list with mini-trend sparklines, `All / Favorites /
  Gainers / Losers` filters, global market cap & 24h volume strip, pull-to-refresh,
  skeleton loading state, offline banner with retry, empty-favorites state.
- **Asset detail** — big live price with flashing updates, 24h change, range
  selector (`1H 1D 1W 1M 1Y`), **Line** (fl_chart) and **Candles** (custom
  painter over the same axis geometry, the way fl_chart's own gallery renders
  candlesticks) modes, dashed current-price line + amber price badge,
  market statistics grid, About sheet.
- **Watchlist** — starred assets pinned with live prices.
- **Portfolio** — total value, P&L vs cost basis, allocation donut (fl_chart
  PieChart), holdings with per-position P&L; **Buy / Sell / Convert** flow via
  the trade sheet with a searchable asset picker.
- **Activity** — trade history grouped by day (Today / Yesterday / date),
  filters for purchases / sales / swaps.
- **Converter** — two-way live conversion between any assets, swap button,
  rate card, and a one-tap real trade.
- Favorites, holdings and activity persist locally via `shared_preferences`.

## Data sources

| Mode | Source |
|------|--------|
| Live | CoinGecko public REST API (`/coins/markets`, `/ohlc`, `/market_chart`) |
| Offline | Deterministic illustrative dataset + seeded random-walk series |

## Architecture

```
lib/
├─ main.dart            — providers, MaterialApp, brand
├─ core/                — design tokens (theme.dart), formatters, brand
├─ models/              — Asset, Candle, Holding, ActivityEntry, ChartRange
├─ data/
│  ├─ market_api.dart          — CoinGecko client (http)
│  ├─ market_repository.dart   — live→offline fallback, range loader
│  └─ illustrative.dart        — deterministic seed + series generators
├─ state/market_store.dart     — ChangeNotifier: markets, favorites,
│                                holdings, activity, auto-refresh pulse
├─ widgets/common.dart         — CoinBadge, Sparkline, MarketRow, chips,
│                                banners, skeletons, empty states
└─ screens/
   ├─ markets/  (list, filters, detail screen + charts)
   ├─ watchlist/
   ├─ portfolio/ (donut, holdings, trade sheet)
   ├─ activity/
   ├─ converter/ (+ converter entry-point)
   └─ search/
```

State is `provider` + `ChangeNotifier`. The detail screen lives *inside* the
root shell, so the bottom navigation stays visible like in the mockups.

## Run

```bash
flutter pub get
flutter run                # pick a device/emulator
flutter run -d web-server  # or try it in a browser
```

## Tech

Flutter · Dart · fl_chart · provider · http · intl · shared_preferences
