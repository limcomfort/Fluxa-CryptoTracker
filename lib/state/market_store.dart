import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart' as fmt;
import '../data/illustrative.dart';
import '../data/market_repository.dart';
import '../models/models.dart';

/// Root-side UI state: selected bottom tab + in-shell detail navigation
/// (the detail screen is shown as a layer above the tabs while the bottom
/// navigation bar stays visible, exactly like the mockups).
class UiState extends ChangeNotifier {
  int tab = 0;
  String? detailAssetId;
  bool converterOpen = false;

  void setTab(int t) {
    if (t == tab && detailAssetId == null) return;
    detailAssetId = null;
    tab = t;
    notifyListeners();
  }

  void openDetail(String assetId) {
    detailAssetId = assetId;
    tab = 0; // the mock detail lives under the Markets tab icon
    notifyListeners();
  }

  void closeDetail() {
    if (detailAssetId == null) return;
    detailAssetId = null;
    notifyListeners();
  }
}

enum MarketStatus { loading, ready, offline }

/// Holds everything the app needs: assets, favorites, portfolio and activity.
class MarketStore extends ChangeNotifier {
  MarketStore(this._repo) {
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  final MarketRepository _repo;
  late Timer _ticker;

  MarketStatus status = MarketStatus.loading;
  DataSource source = DataSource.loading;
  DateTime? lastRefresh;
  int generation = 0; // bumps after each refresh, chart screens listen to it

  final Map<String, Asset> _assets = {};
  List<String> _order = [];

  final Set<String> _favorites = {};
  final List<Holding> _holdings = [];
  final List<SignalEntry> _signals = [];

  /// Copies of the values observed during the previous refresh — used to
  /// detect short-term momentum spikes and regime shifts.
  final Map<String, double> _prevPrices = {};
  double? _prevMarketChange;
  final Map<String, DateTime> _recentSignals = {}; // 'asset|kind' -> last emitted

  List<Asset> get assets =>
      [for (final id in _order) if (_assets.containsKey(id)) _assets[id]!];

  Asset? assetById(String? id) => id == null ? null : _assets[id];

  bool isFavorite(String id) => _favorites.contains(id);
  List<Asset> get favoriteAssets => assets.where((a) => _favorites.contains(a.id)).toList();
  List<Asset> get gainers =>
      assets.where((a) => a.changePct24h > 0).toList()..sort((a, b) => b.changePct24h.compareTo(a.changePct24h));
  List<Asset> get losers =>
      assets.where((a) => a.changePct24h <= 0).toList()..sort((a, b) => a.changePct24h.compareTo(b.changePct24h));

  // ---------- Market totals for the summary strip ----------
  ({double cap, double volume, double capChange}) get marketTotals {
    var cap = 0.0, vol = 0.0, capWeightedChange = 0.0;
    for (final a in assets) {
      cap += a.marketCap;
      vol += a.volume24h;
      capWeightedChange += a.marketCap > 0 ? a.changePct24h * a.marketCap : 0;
    }
    return (
      cap: cap,
      volume: vol,
      capChange: cap > 0 ? capWeightedChange / cap : 0,
    );
  }

  List<Holding> get holdings => List.unmodifiable(_holdings);
  List<SignalEntry> get signals => List.unmodifiable(_signals);

  double get portfolioValue {
    var v = 0.0;
    for (final h in _holdings) {
      v += h.qty * (assetById(h.assetId)?.price ?? 0);
    }
    return v;
  }

  ({double pnl, double pnlPct}) get portfolioPnl {
    var cost = 0.0, value = 0.0;
    for (final h in _holdings) {
      cost += h.costBasis;
      value += h.qty * (assetById(h.assetId)?.price ?? h.avgCost);
    }
    final pnl = value - cost;
    return (pnl: pnl, pnlPct: cost > 0 ? pnl / cost * 100 : 0);
  }

  Holding? holdingOf(String assetId) {
    for (final h in _holdings) {
      if (h.assetId == assetId) return h;
    }
    return null;
  }

  // ---------- Lifecycle ----------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites.addAll((prefs.getStringList('favorites') ?? const []).cast<String>());
    _holdings.addAll((prefs.getStringList('holdings') ?? const [])
        .map((s) => Holding.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    _signals.addAll((prefs.getStringList('signals') ?? const [])
        .map((s) => SignalEntry.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    _signals.sort((a, b) => b.ts.compareTo(a.ts));
    await refresh();
  }

  Future<void> refresh() async {
    final r = await _repo.loadMarkets();
    final prevAssets = Map<String, Asset>.from(_assets);
    final prevMarketChange = _weightedChange(prevAssets);
    for (final a in r.assets) {
      final old = _assets[a.id];
      _assets[a.id] = old == null ? a : a.copyWith(price: a.price, spark: a.spark);
      // keep holdings in sync: merge missing assets into the map fallback
      if (old != null && a.spark.length < 2 && old.spark.length > 2) {
        _assets[a.id] = a.copyWith(spark: old.spark);
      }
    }
    for (final id in prevAssets.keys) {
      if (!_assets.keys.contains(id)) {
        final fallback = illustrativeById(id);
        if (fallback != null) {
          _assets[id] = fallback.copyWith(price: _assets[id]?.price ?? fallback.price);
        }
      }
    }
    _order = r.assets.map((a) => a.id).toList();
    for (final h in _holdings) {
      if (!_assets.containsKey(h.assetId)) {
        final f = illustrativeById(h.assetId);
        if (f != null) {
          _assets[h.assetId] = f.copyWith(price: f.price);
          _order.add(h.assetId);
        }
      }
    }
    source = r.source;
    status = r.source == DataSource.live ? MarketStatus.ready : MarketStatus.offline;
    lastRefresh = DateTime.now();
    generation++;
    _detectSignals(prevAssets, prevMarketChange);
    notifyListeners();
    await _persist();
  }

  static double? _weightedChange(Map<String, Asset> assets) {
    var cap = 0.0, weighted = 0.0;
    for (final a in assets.values) {
      cap += a.marketCap;
      weighted += a.marketCap > 0 ? a.changePct24h * a.marketCap : 0;
    }
    return cap > 0 ? weighted / cap : null;
  }

  // ---------- Favorites ----------
  Future<void> toggleFavorite(String id) async {
    final added = _favorites.add(id);
    final symbol = _assets[id]?.symbol;
    if (symbol != null) {
      _insertSignal(SignalEntry(
        id: _entryId(),
        ts: DateTime.now(),
        kind: SignalKind.watch,
        assetId: id,
        assetSymbol: symbol,
        title: added ? '$symbol добавлен в избранное' : '$symbol убран из избранного',
        subtitle: added
            ? 'Событие избранного · сигналы следят за отмеченными активами'
            : 'Событие избранного · останется в истории ленты',
      ));
    }
    notifyListeners();
    await _persist();
  }

  // ---------- Signals engine ----------
  /// Generates analytical signals after every market refresh:
  /// momentum spikes, regime shifts, 24h extremes for tracked/favorite
  /// assets. Nothing here is a trading operation — it only observes.
  void _detectSignals(Map<String, Asset> prevAssets, double? prevMarketChange) {
    final now = DateTime.now();
    void push(SignalEntry e, {String? rateKey, Duration rateWindow = const Duration(minutes: 45)}) {
      final key = rateKey ?? '${e.assetId}|${e.kind}';
      if (rateKey != null) {
        final last = _recentSignals[key];
        if (last != null && now.subtract(rateWindow).isBefore(last)) return;
      }
      if (_recentSignals[key] != null) return;
      _recentSignals[key] = now;
      _insertSignal(e);
    }

    // Market regime shift: breadth-weighted cap change crossing ±2%.
    final capChange = marketTotals.capChange;
    if (_prevMarketChange != null) {
      bool crossed(double x, double y) =>
          (x < -2 && y >= -2) || (x >= -2 && y < -2) || (x <= 2 && y > 2) || (x > 2 && y <= 2);
      if (crossed(_prevMarketChange!, capChange)) {
        final bullish = capChange >= 0;
        final kind = bullish ? SignalKind.up : SignalKind.down;
        if (!_recentSignals.containsKey('market|$kind')) {
          _recentSignals['market|$kind'] = now;
          _insertSignal(SignalEntry(
            id: _entryId(),
            ts: now,
            kind: kind,
            title: bullish
                ? 'Рынок риск-он · ${fmt.fmtSignedPct(capChange)}'
                : 'Рынок в защите · ${fmt.fmtSignedPct(capChange)}',
            subtitle: _marketRegimeText(capChange, bullish),
          ));
        }
      }
    }
    _prevMarketChange = capChange;

    // Per-asset signals for tracked (held or favorited) assets.
    for (final h in _holdings) {
      _assetSignal(_assets[h.assetId], prevAssets[h.assetId], now, push);
    }
    for (final f in _favorites) {
      _assetSignal(_assets[f], prevAssets[f], now, push);
    }
  }

  String _marketRegimeText(double capChange, bool bullish) => bullish
      ? 'Широта рынка смотрит вверх — взвешенный по капитализации ход за 24ч: ${fmt.fmtSignedPct(capChange)}.'
      : 'Рынок переходит в защиту — взвешенный по капитализации ход за 24ч: ${fmt.fmtSignedPct(capChange)}.';

  void _assetSignal(Asset? a, Asset? prev, DateTime now, void Function(SignalEntry e) push) {
    if (a == null) return;

    // 24h extremes worth reporting to an analyst.
    if (a.changePct24h >= 3 && a.price >= a.high24h * 0.9995) {
      push(SignalEntry(
        id: _entryId(),
        ts: now,
        kind: SignalKind.up,
        assetId: a.id,
        assetSymbol: a.symbol,
        title: '${a.symbol} тестирует максимум 24ч',
        subtitle: '${fmt.fmtSignedPct(a.changePct24h)} за 24ч · давит на верх диапазона',
      ));
    }
    if (a.changePct24h <= -3 && a.price <= a.low24h * 1.0005) {
      push(SignalEntry(
        id: _entryId(),
        ts: now,
        kind: SignalKind.down,
        assetId: a.id,
        assetSymbol: a.symbol,
        title: '${a.symbol} тестирует минимум 24ч',
        subtitle: '${fmt.fmtSignedPct(a.changePct24h)} за 24ч · давит на низ диапазона',
      ));
    }

    // Momentum spikes vs the previous refresh minute.
    final prevPrice = prev?.price ?? _prevPrices[a.id];
    _prevPrices[a.id] = a.price;
    if (prevPrice == null || prevPrice <= 0) return;
    final dpct = (a.price - prevPrice) / prevPrice * 100;
    if (dpct >= 1.5) {
      push(SignalEntry(
        id: _entryId(),
        ts: now,
        kind: SignalKind.up,
        assetId: a.id,
        assetSymbol: a.symbol,
        title: '${a.symbol}: импульс вверх · ${fmt.fmtSignedPct(dpct)}',
        subtitle: 'Изменение ${fmt.fmtSignedPct(dpct)} между обновлениями данных',
      ));
    } else if (dpct <= -1.5) {
      push(SignalEntry(
        id: _entryId(),
        ts: now,
        kind: SignalKind.down,
        assetId: a.id,
        assetSymbol: a.symbol,
        title: '${a.symbol}: импульс вниз · ${fmt.fmtSignedPct(dpct)}',
        subtitle: 'Изменение ${fmt.fmtSignedPct(dpct)} между обновлениями данных',
      ));
    }
  }

  void _insertSignal(SignalEntry e) {
    _signals.insert(0, e);
    if (_signals.length > 120) _signals.removeRange(120, _signals.length);
  }

  // ---------- Positions (manual, analytics-only book) ----------
  /// Adds or updates a tracked position. Pure bookkeeping for the
  /// analytical views — no orders are placed anywhere.
  /// Returns null on success or a user-facing error string.
  String? upsertPosition({
    required String assetId,
    required double qty,
    required double? avgCost,
  }) {
    final asset = _assets[assetId];
    if (asset == null) return 'Актив недоступен';
    if (qty <= 0 || qty.isNaN || qty.isInfinite) return 'Введите количество больше нуля';
    if (avgCost != null && (avgCost < 0 || avgCost.isNaN || avgCost.isInfinite)) {
      return 'Средняя цена должна быть неотрицательной';
    }
    final idx = _holdings.indexWhere((h) => h.assetId == assetId);
    final existing = idx >= 0 ? _holdings[idx] : null;
    final avgP = avgCost ?? existing?.avgCost ?? asset.price;
    final cost = avgP * qty;
    if (existing != null) {
      _holdings[idx] = Holding(assetId: assetId, qty: qty, costBasis: cost);
    } else {
      _holdings.insert(0, Holding(assetId: assetId, qty: qty, costBasis: cost));
    }
    _insertSignal(SignalEntry(
      id: _entryId(),
      ts: DateTime.now(),
      kind: SignalKind.watch,
      assetId: assetId,
      assetSymbol: asset.symbol,
      title: existing == null
          ? 'Отслеживаем ${fmt.fmtQty(qty)} ${asset.symbol}'
          : 'Обновлена позиция ${asset.symbol}',
      subtitle: 'Кол-во ${fmt.fmtQty(qty)} · средняя ${fmt.fmtPricePlain(avgP)}',
    ));
    notifyListeners();
    _persist();
    return null;
  }

  /// Removes a tracked position.
  Future<void> removePosition(String assetId) async {
    final idx = _holdings.indexWhere((h) => h.assetId == assetId);
    if (idx < 0) return;
    final asset = _assets[assetId];
    _holdings.removeAt(idx);
    _insertSignal(SignalEntry(
      id: _entryId(),
      ts: DateTime.now(),
      kind: SignalKind.watch,
      assetId: assetId,
      assetSymbol: asset?.symbol,
      title: 'Перестали отслеживать ${asset?.symbol ?? assetId}',
      subtitle: 'Удалено из портфельной аналитики',
    ));
    notifyListeners();
    await _persist();
  }

  /// Wipes positions — pure erasure (demo data tool).
  Future<void> clearPortfolio() async {
    _holdings.clear();
    notifyListeners();
    await _persist();
  }

  /// Wipes the signal feed only.
  Future<void> clearSignals() async {
    _signals.clear();
    notifyListeners();
    await _persist();
  }

  /// Deterministic demo dataset: five tracked positions and a matching
  /// showcase signal feed.
  Future<void> seedDemoData() async {
    final now = DateTime.now();
    String stamp() => now.millisecondsSinceEpoch.toRadixString(36);
    DateTime ago(Duration d) => now.subtract(d);

    SignalEntry sig(String kind, String title, String subtitle, String assetId, String symbol, DateTime ts) =>
        SignalEntry(
          id: 'demo-$assetId-${stamp()}-${ts.millisecondsSinceEpoch.toRadixString(36)}',
          ts: ts,
          kind: kind,
          title: title,
          subtitle: subtitle,
          assetId: assetId,
          assetSymbol: symbol,
        );

    _signals
      ..clear()
      ..addAll([
        sig(SignalKind.up, 'BTC: импульс вверх', 'Сильный рост за 24ч — восходящий тренд сохраняется', 'bitcoin', 'BTC', ago(const Duration(minutes: 38))),
        sig(SignalKind.down, 'Рынок в защите', 'Капитализация снижается — крупные монеты давят на рынок', 'ethereum', 'ETH', ago(const Duration(hours: 4))),
        sig(SignalKind.up, 'ETH тестирует максимум 24ч', 'Удерживает верх диапазона при растущем объёме', 'ethereum', 'ETH', ago(const Duration(hours: 9))),
        sig(SignalKind.watch, 'Отслеживаем 0.0521 BTC', 'Кол-во 0.0521 · средняя 55,729.42', 'bitcoin', 'BTC', ago(const Duration(hours: 26))),
        sig(SignalKind.watch, 'Отслеживаем 1.204 ETH', 'Кол-во 1.204 · средняя 2,988.10', 'ethereum', 'ETH', ago(const Duration(hours: 27))),
        sig(SignalKind.info, 'Пульс данных', 'Авто-обновление рынка каждую минуту', 'bitcoin', 'BTC', ago(const Duration(hours: 30))),
      ]);

    // Cost basis 21% below the reference entry prices so positions
    // show a plausible analytic P&L.
    double basisOf(double qty, double price) => qty * price / 1.21;
    _holdings
      ..clear()
      ..addAll([
        Holding(assetId: 'bitcoin', qty: 0.0521, costBasis: basisOf(0.0521, 67432.80)),
        Holding(assetId: 'ethereum', qty: 1.204, costBasis: basisOf(1.204, 3615.60)),
        Holding(assetId: 'binancecoin', qty: 1.87, costBasis: basisOf(1.87, 921.10)),
        Holding(assetId: 'avalanche-2', qty: 42, costBasis: basisOf(42, 40.44)),
        Holding(assetId: 'cardano', qty: 3500, costBasis: basisOf(3500, 0.4621)),
      ]);

    notifyListeners();
    await _persist();
  }

  static String _entryId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) + (99 + DateTime.now().millisecond).toRadixString(36);

  // ---------- Persistence ----------
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites.toList());
    await prefs.setStringList('holdings', _holdings.map((h) => jsonEncode(h.toJson())).toList());
    await prefs.setStringList('signals', _signals.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }
}
