import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/illustrative.dart';
import '../data/market_repository.dart';
import '../models/models.dart';
import 'formatters.dart' as fmt;

/// Root-side UI state: selected bottom tab.
class UiState extends ChangeNotifier {
  int tab = 0;
  void setTab(int t) {
    if (t == tab) return;
    tab = t;
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
  final List<ActivityEntry> _activity = [];

  UnmodifiableListViewX get assets => UnmodifiableListViewX(_order.map(_assets.get).whereType());

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
  List<ActivityEntry> get activity => List.unmodifiable(_activity);

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
    _activity.addAll((prefs.getStringList('activity') ?? const [])
        .map((s) => ActivityEntry.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    _activity.sort((a, b) => b.ts.compareTo(a.ts));
    await refresh();
  }

  Future<void> refresh() async {
    final r = await _repo.loadMarkets();
    final oldIds = Set<String>.from(_assets.keys);
    for (final a in r.assets) {
      final old = _assets[a.id];
      _assets[a.id] = old == null ? a : a.copyWith(price: a.price, spark: a.spark);
      // keep holdings in sync: merge missing assets into the map fallback
      if (old != null && a.spark.length < 2 && old.spark.length > 2) {
        _assets[a.id] = a.copyWith(spark: old.spark);
      }
    }
    for (final id in oldIds) {
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
    notifyListeners();
    await _persist();
  }

  // ---------- Favorites ----------
  Future<void> toggleFavorite(String id) async {
    if (!_favorites.remove(id)) _favorites.add(id);
    notifyListeners();
    await _persist();
  }

  // ---------- Trading ----------
  /// Returns null on success or a user-facing error string.
  String? executeTrade({
    required String type,
    required String assetId,
    required double qty,
    String? targetAssetId,
  }) {
    final asset = _assets[assetId];
    if (asset == null) return 'Asset is unavailable';
    if (qty <= 0 || qty.isNaN || qty.isInfinite) return 'Enter a positive amount';
    final now = DateTime.now();
    final idx = _holdings.indexWhere((h) => h.assetId == assetId);
    final held = idx >= 0 ? _holdings[idx] : null;

    switch (type) {
      case TradeType.buy:
        final value = qty * asset.price;
        _insertActivity(ActivityEntry(
          id: _entryId(),
          ts: now,
          type: TradeType.buy,
          assetId: assetId,
          assetSymbol: asset.symbol,
          qty: qty,
          priceUsd: asset.price,
          valueUsd: value,
        ));
        if (held == null) {
          _holdings.add(Holding(assetId: assetId, qty: qty, costBasis: value));
        } else {
          _holdings[idx] = held.adjusted(qty, value);
        }
      case TradeType.sell:
        if (held == null || held.qty + 1e-12 < qty) {
          return 'You hold ${fmt.fmtQty(held?.qty ?? 0)} ${asset.symbol}';
        }
        final portionQty = qty / (held.qty == 0 ? 1 : held.qty);
        final cost = held.costBasis * portionQty;
        _insertActivity(ActivityEntry(
          id: _entryId(),
          ts: now,
          type: TradeType.sell,
          assetId: assetId,
          assetSymbol: asset.symbol,
          qty: qty,
          priceUsd: asset.price,
          valueUsd: qty * asset.price,
        ));
        final next = held.adjusted(-qty, -cost);
        if (next.qty <= 1e-10) {
          _holdings.removeAt(idx);
        } else {
          _holdings[idx] = next;
        }
      case TradeType.convert:
        final target = _assets[targetAssetId];
        if (target == null) return 'Select the destination asset';
        if (targetAssetId == assetId) return 'Choose two different assets';
        if (held == null || held.qty + 1e-12 < qty) {
          return 'You hold ${fmt.fmtQty(held?.qty ?? 0)} ${asset.symbol}';
        }
        final targetQty = qty * asset.price / target.price;
        final cost = held.costBasis * (qty / (held.qty == 0 ? 1 : held.qty));
        _insertActivity(ActivityEntry(
          id: _entryId(),
          ts: now,
          type: TradeType.convert,
          assetId: assetId,
          assetSymbol: asset.symbol,
          qty: qty,
          priceUsd: asset.price,
          valueUsd: qty * asset.price,
          counterAssetId: target.id,
          counterSymbol: target.symbol,
          counterQty: targetQty,
        ));
        final next = held.adjusted(-qty, -cost);
        if (next.qty <= 1e-10) {
          _holdings.removeAt(idx);
        } else {
          _holdings[idx] = next;
        }
        final tIdx = _holdings.indexWhere((h) => h.assetId == target.id);
        if (tIdx >= 0) {
          _holdings[tIdx] = _holdings[tIdx].adjusted(targetQty, qty * asset.price);
        } else {
          _holdings.add(Holding(assetId: target.id, qty: targetQty, costBasis: qty * asset.price));
        }
      default:
        return 'Unknown operation';
    }
    notifyListeners();
    _persist();
    return null;
  }

  void _insertActivity(ActivityEntry e) => _activity.insert(0, e);

  static String _entryId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) + (99 + DateTime.now().millisecond).toRadixString(36);

  // ---------- Persistence ----------
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favorites.toList());
    await prefs.setStringList('holdings', _holdings.map((h) => jsonEncode(h.toJson())).toList());
    await prefs.setStringList('activity', _activity.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }
}

/// Small convenience wrapper over an unmodifiable snapshot.
class UnmodifiableListViewX extends Iterable<Asset> {
  UnmodifiableListViewX(this._iter);
  final Iterable<Asset?> _iter;
  @override
  Iterator<Asset> get iterator => _iter.whereType<Asset>().iterator;
}

extension MapGetX<K, V> on Map<K, V> {
  V? get(K? key) => key == null ? null : this[key];
}
