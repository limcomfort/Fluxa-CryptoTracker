import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Thin CoinGecko public-API client (no key required).
class CoinGeckoClient {
  CoinGeckoClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://api.coingecko.com/api/v3';
  static const _headers = {'User-Agent': 'CryptoTracker/1.0'};

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw MarketApiException('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Top coins with 24h stats and a 7d sparkline.
  Future<List<Asset>> fetchMarkets({int perPage = 100}) async {
    final raw = await _get('/coins/markets', {
      'vs_currency': 'usd',
      'order': 'market_cap_desc',
      'per_page': '$perPage',
      'page': '1',
      'sparkline': 'true',
      'price_change_percentage': '24h',
    }) as List<dynamic>;

    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      final sparkRaw = (m['sparkline_in_7d']?['price'] as List<dynamic>? ?? const [])
          .map((v) => (v as num).toDouble())
          .toList();
      // Downsample ~168 points -> 48 for the mini chart.
      final spark = _downsample(sparkRaw, 48);
      final price = (m['current_price'] as num?)?.toDouble() ?? 0;
      final changePct = (m['price_change_percentage_24h'] as num?)?.toDouble() ?? 0;
      final changeAbs = (m['price_change_24h'] as num?)?.toDouble() ?? price * changePct / 100;
      return Asset(
        id: m['id'] as String,
        symbol: (m['symbol'] as String? ?? '').toUpperCase(),
        name: (m['name'] as String? ?? '').toString(),
        price: price,
        changePct24h: changePct,
        changeAbs24h: changeAbs,
        marketCap: (m['market_cap'] as num?)?.toDouble() ?? 0,
        volume24h: (m['total_volume'] as num?)?.toDouble() ?? 0,
        high24h: (m['high_24h'] as num?)?.toDouble() ?? price,
        low24h: (m['low_24h'] as num?)?.toDouble() ?? price,
        spark: spark,
        rank: (m['market_cap_rank'] as num?)?.toInt() ?? 0,
        about: (m['categories'] as List?)?.isNotEmpty == true
            ? (m['categories'] as List).first.toString()
            : '${m['name']} (${(m['symbol'] as String?)?.toUpperCase()}) digital asset.',
        glyph: ((m['symbol'] as String? ?? '').toUpperCase()).length >= 2
            ? (m['symbol'] as String).toUpperCase().substring(0, 2)
            : (m['symbol'] as String? ?? '').toUpperCase(),
        seedColor: 0xFF2E3032,
        imageUrl: m['image'] as String?,
      );
    }).toList();
  }

  /// OHLC series for candlestick charts.
  Future<List<Candle>> fetchOhlc(String id, int days) async {
    final raw = await _get('/coins/$id/ohlc', {'vs_currency': 'usd', 'days': '$days'}) as List<dynamic>;
    return raw.map((e) {
      final r = e as List<dynamic>;
      return Candle(
        t: DateTime.fromMillisecondsSinceEpoch((r[0] as num).toInt()),
        o: (r[1] as num).toDouble(),
        h: (r[2] as num).toDouble(),
        l: (r[3] as num).toDouble(),
        c: (r[4] as num).toDouble(),
      );
    }).toList();
  }

  /// Price line for flat charts.
  Future<List<TimePoint>> fetchLine(String id, int days) async {
    final raw = await _get('/coins/$id/market_chart', {'vs_currency': 'usd', 'days': '$days'})
        as Map<String, dynamic>;
    final prices = raw['prices'] as List<dynamic>;
    return prices.map((e) {
      final r = e as List<dynamic>;
      return TimePoint(
        DateTime.fromMillisecondsSinceEpoch((r[0] as num).toInt()),
        (r[1] as num).toDouble(),
      );
    }).toList();
  }

  static List<double> _downsample(List<double> src, int target) {
    if (src.length <= target) return src;
    final out = <double>[];
    final step = src.length / target;
    for (var i = 0; i < target; i++) {
      out.add(src[(i * step).floor().clamp(0, src.length - 1)]);
    }
    out.add(src.last);
    return out;
  }
}

class MarketApiException implements Exception {
  MarketApiException(this.message);
  final String message;
  @override
  String toString() => 'MarketApiException: $message';
}
