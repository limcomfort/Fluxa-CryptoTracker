import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Deterministic PRNG helpers so the illustrative dataset is stable.
int fnvHash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0x7FFFFFFF;
  }
  return h;
}

class _Rng {
  _Rng(int seed) : _s = (seed | 1) & 0x7FFFFFFF;
  int _s;
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0x7FFFFFFF;
    return _s / 0x7FFFFFFF;
  }

  double range(double a, double b) => a + (b - a) * next();
}

class _SeedCoin {
  const _SeedCoin(this.id, this.symbol, this.name, this.price, this.change, this.mcapT, this.volB,
      this.glyph, this.color, this.about);
  final String id;
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double mcapT; // market cap, trillions
  final double volB; // 24h volume, billions
  final String glyph;
  final int color;
  final String about;
}

const _seedCoins = <_SeedCoin>[
  _SeedCoin('bitcoin', 'BTC', 'Bitcoin', 67432.80, 2.34, 1.33, 28.46, '₿', 0xFFF7931A,
      'Децентрализованная цифровая валюта.'),
  _SeedCoin('ethereum', 'ETH', 'Ethereum', 3521.46, 1.87, 0.42, 12.93, 'Ξ', 0xFF627EEA,
      'Программируемая платформа смарт-контрактов.'),
  _SeedCoin('solana', 'SOL', 'Solana', 172.38, 5.62, 0.09, 3.12, 'Ω', 0xFF9846D6,
      'Высокопроизводительный блокчейн для децентрализованных приложений.'),
  _SeedCoin('binancecoin', 'BNB', 'BNB', 604.21, -0.48, 0.088, 1.64, '◆', 0xFFF3BA2F,
      'Утилитарный токен экосистемы BNB Chain.'),
  _SeedCoin('ripple', 'XRP', 'XRP', 0.5284, -1.23, 0.030, 1.48, '✕', 0xFF23A5D6,
      'Цифровой актив для платежей и рассчётов.'),
  _SeedCoin('cardano', 'ADA', 'Cardano', 0.4621, 0.96, 0.016, 0.61, '₳', 0xFF0068B5,
      'Исследовательский блокчейн с доказательством доли.'),
  _SeedCoin('avalanche-2', 'AVAX', 'Avalanche', 36.84, 3.14, 0.014, 0.42, '▲', 0xFFE84142,
      'Масштабируемая платформа для децентрализованных приложений.'),
  _SeedCoin('dogecoin', 'DOGE', 'Dogecoin', 0.1524, -2.11, 0.022, 0.88, 'Ð', 0xFFF2C32A,
      'Первоначальный мемкоин с преданным сообществом.'),
  _SeedCoin('tron', 'TRX', 'TRON', 0.2467, 1.42, 0.021, 0.52, 'T', 0xFFE8273C,
      'Децентрализованный блокчейн для обмена контентом.'),
  _SeedCoin('polkadot', 'DOT', 'Polkadot', 6.87, -0.77, 0.010, 0.22, '●', 0xFFE6007A,
      'Мультичейн-протокол для кроссчейн-переводов.'),
  _SeedCoin('chainlink', 'LINK', 'Chainlink', 14.62, 2.05, 0.009, 0.31, '⬡', 0xFF2A5ADA,
      'Децентрализованная сеть оракулов.'),
  _SeedCoin('polygon', 'POL', 'Polygon', 0.4872, 4.36, 0.005, 0.18, '⬢', 0xFF8247E5,
      'Layer-2 фреймворк масштабирования Ethereum.'),
];

Asset _seedToAsset(_SeedCoin c, _Rng rng) {
  final spark = _sparkFor(c, rng);
  final abs = c.price * c.change / 100;
  return Asset(
    id: c.id,
    symbol: c.symbol,
    name: c.name,
    price: c.price,
    changePct24h: c.change,
    changeAbs24h: abs,
    marketCap: c.mcapT * 1e12,
    volume24h: c.volB * 1e9,
    high24h: c.price * (1 + c.change.abs() / 400 + rng.range(0.002, 0.010)),
    low24h: c.price / (1 + c.change.abs() / 400 + rng.range(0.002, 0.010)),
    spark: spark,
    rank: _seedCoins.indexOf(c) + 1,
    about: c.about,
    glyph: c.glyph,
    seedColor: c.color,
  );
}

/// Random-walk sparkline that always ends at the current price and starts at
/// price / (1 + change24h), so the picture and the numbers stay consistent.
List<double> _sparkFor(_SeedCoin c, _Rng rng) {
  const n = 40;
  final end = c.price;
  final start = end / (1 + c.change / 100);
  final pts = List<double>.filled(n, 0);
  pts[n - 1] = end;
  pts[0] = start;
  for (var i = 1; i < n - 1; i++) {
    final t = i / (n - 1);
    final base = start + (end - start) * t;
    final noise = end * 0.008;
    final wave = math.sin(t * math.pi * 4 + (fnvHash(c.id) % 7)) * noise * 0.4;
    pts[i] = base + wave + noise * rng.range(-1, 1) * (1 - t * 0.5);
  }
  pts[n - 1] = end;
  pts[0] = start;
  return pts;
}

/// Full illustrative dataset, deterministic per coin id.
List<Asset> illustrativeAssets() {
  final rng = _Rng(20240920);
  return _seedCoins.map((c) => _seedToAsset(c, rng)).toList();
}

Asset? illustrativeById(String id) {
  final i = _seedCoins.indexWhere((c) => c.id == id);
  if (i < 0) return null;
  final rng = _Rng(fnvHash(_seedCoins[i].id) ~/ 211);
  return _seedToAsset(_seedCoins[i], rng);
}

/// Synthetic OHLC candles for offline mode, ending near [endPrice].
List<Candle> illustrativeCandles(String id, int n, {required double endPrice, required Duration step}) {
  final rng = _Rng(fnvHash('$id-candles-$n') ~/ 97);
  final now = DateTime.now().toUtc();
  var px = endPrice * rng.range(0.8, 1.2);
  final raw = <Candle>[];
  for (var i = 0; i < n; i++) {
    final vol = px * rng.range(0.005, 0.022);
    final o = px;
    final c2 = o + rng.range(-vol, vol);
    final h = math.max(o, c2) + rng.range(0, vol * 0.6);
    final l = math.min(o, c2) - rng.range(0, vol * 0.6);
    raw.add(Candle(t: now.subtract(step * (n - i)), o: o, h: h, l: l, c: c2));
    px = c2;
  }
  final k = endPrice / raw.last.c;
  return raw.map((x) => Candle(t: x.t, o: x.o * k, h: x.h * k, l: x.l * k, c: x.c * k)).toList();
}

/// Synthetic line series for offline mode, ending exactly at [endPrice].
List<TimePoint> illustrativeLine(String id, int n, {required double endPrice, required Duration step}) {
  final rng = _Rng(fnvHash('$id-line-$n') ~/ 89);
  final pts = <TimePoint>[];
  final now = DateTime.now().toUtc();
  var px = endPrice * rng.range(0.78, 1.22);
  for (var i = 0; i <= n; i++) {
    pts.add(TimePoint(now.subtract(step * (n - i)), px));
    px += endPrice * rng.range(-0.008, 0.0085);
  }
  final last = pts.last.p;
  final k = endPrice / (last == 0 ? 1 : last);
  return pts.map((p) => TimePoint(p.t, p.p * k)).toList();
}

/// Darker variant of the brand color used for the logo circle background.
Color brandColorOf(Asset a) {
  final hsl = HSLColor.fromColor(Color(a.seedColor));
  return hsl
      .withLightness((hsl.lightness * 0.55).clamp(0.10, 0.32))
      .withSaturation(hsl.saturation.clamp(0.25, 0.75))
      .toColor();
}
