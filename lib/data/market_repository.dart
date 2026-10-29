import '../models/models.dart';
import 'illustrative.dart';
import 'market_api.dart';

enum DataSource { live, illustrative, loading }

/// Chart series for a given asset+range, either from the network or from the
/// deterministic offline generator.
class RangeSeries {
  const RangeSeries({this.candles = const [], this.points = const [], required this.source});
  final List<Candle> candles;
  final List<TimePoint> points;
  final DataSource source;
}

class MarketRepository {
  MarketRepository({CoinGeckoClient? client}) : _api = client ?? CoinGeckoClient();

  final CoinGeckoClient _api;

  Future<({List<Asset> assets, DataSource source})> loadMarkets() async {
    try {
      final assets = await _api.fetchMarkets(perPage: 50);
      if (assets.isEmpty) throw MarketApiException('empty response');
      return (assets: assets, source: DataSource.live);
    } catch (_) {
      return (assets: illustrativeAssets(), source: DataSource.illustrative);
    }
  }

  /// Candles + line points for the detail chart. 1H is sliced from daily data
  /// (CoinGecko does not provide finer OHLC on the free endpoint).
  Future<RangeSeries> loadRange(Asset asset, ChartRange range) async {
    final days = range.CoinGeckoDays;
    final wantHour = range == ChartRange.h1;
    try {
      final candles = await _api.fetchOhlc(asset.id, days);
      final points = await _api.fetchLine(asset.id, days);
      if (candles.isEmpty || points.isEmpty) throw MarketApiException('empty range');
      return RangeSeries(
        candles: wantHour ? _sliceCandlesLastHour(candles) : candles,
        points: wantHour ? _slicePointsLastHour(points) : points,
        source: DataSource.live,
      );
    } catch (_) {
      return _illustrativeRange(asset, range);
    }
  }

  RangeSeries _illustrativeRange(Asset asset, ChartRange range) {
    final (n, step) = switch (range) {
      ChartRange.h1 => (14, const Duration(minutes: 4)),
      ChartRange.d1 => (49, const Duration(minutes: 30)),
      ChartRange.w1 => (56, const Duration(hours: 3)),
      ChartRange.m1 => (60, const Duration(hours: 12)),
      ChartRange.y1 => (52, const Duration(days: 7)),
    };
    return RangeSeries(
      candles: illustrativeCandles(asset.id, n, endPrice: asset.price, step: step),
      points: illustrativeLine(asset.id, n * 2, endPrice: asset.price, step: step),
      source: DataSource.illustrative,
    );
  }

  static List<TimePoint> _slicePointsLastHour(List<TimePoint> pts) {
    if (pts.length < 2) return pts;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final sliced = pts.where((p) => p.t.isAfter(cutoff)).toList();
    return sliced.length >= 2 ? sliced : pts.skip(pts.length - 13).toList();
  }

  static List<Candle> _sliceCandlesLastHour(List<Candle> candles) {
    if (candles.length < 3) return candles;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final sliced = candles.where((c) => c.t.isAfter(cutoff)).toList();
    return sliced.length >= 3 ? sliced : candles.skip(candles.length - 12).toList();
  }
}
