class Asset {
  const Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct24h,
    required this.changeAbs24h,
    required this.marketCap,
    required this.volume24h,
    required this.high24h,
    required this.low24h,
    required this.spark,
    required this.rank,
    required this.about,
    required this.glyph,
    required this.seedColor,
    this.imageUrl,
  });

  final String id; // slug, e.g. "bitcoin"
  final String symbol; // e.g. "BTC"
  final String name; // e.g. "Bitcoin"
  final double price;
  final double changePct24h;
  final double changeAbs24h;
  final double marketCap;
  final double volume24h;
  final double high24h;
  final double low24h;
  final List<double> spark; // ~24h trend used for list mini-charts
  final int rank;
  final String about;
  final String glyph; // currency sign or initials fallback
  final int seedColor; // base brand color for the logo circle
  final String? imageUrl; // remote logo from the API, when available

  bool get isUp => changePct24h >= 0;

  Asset copyWith({double? price, List<double>? spark}) => Asset(
        id: id,
        symbol: symbol,
        name: name,
        price: price ?? this.price,
        changePct24h: changePct24h,
        changeAbs24h: changeAbs24h,
        marketCap: marketCap,
        volume24h: volume24h,
        high24h: high24h,
        low24h: low24h,
        spark: spark ?? this.spark,
        rank: rank,
        about: about,
        glyph: glyph,
        seedColor: seedColor,
        imageUrl: imageUrl,
      );
}

class Candle {
  const Candle({required this.t, required this.o, required this.h, required this.l, required this.c});

  final DateTime t;
  final double o;
  final double h;
  final double l;
  final double c;

  bool get isUp => c >= o;
}

class TimePoint {
  const TimePoint(this.t, this.p);
  final DateTime t;
  final double p;
}

enum ChartRange { h1, d1, w1, m1, y1 }

extension ChartRangeX on ChartRange {
  String get label => switch (this) {
        ChartRange.h1 => '1H',
        ChartRange.d1 => '1D',
        ChartRange.w1 => '1W',
        ChartRange.m1 => '1M',
        ChartRange.y1 => '1Y',
      };

  int get CoinGeckoDays => switch (this) {
        ChartRange.h1 => 1,
        ChartRange.d1 => 1,
        ChartRange.w1 => 7,
        ChartRange.m1 => 30,
        ChartRange.y1 => 365,
      };
}

class TradeType {
  static const buy = 'buy';
  static const sell = 'sell';
  static const convert = 'convert';
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.ts,
    required this.type,
    required this.assetId,
    required this.assetSymbol,
    required this.qty,
    required this.priceUsd,
    required this.valueUsd,
    this.counterAssetId,
    this.counterSymbol,
    this.counterQty,
  });

  final String id;
  final DateTime ts;
  final String type; // buy | sell | convert
  final String assetId;
  final String assetSymbol;
  final double qty;
  final double priceUsd;
  final double valueUsd;
  final String? counterAssetId; // for converts
  final String? counterSymbol;
  final double? counterQty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.millisecondsSinceEpoch,
        'type': type,
        'assetId': assetId,
        'assetSymbol': assetSymbol,
        'qty': qty,
        'priceUsd': priceUsd,
        'valueUsd': valueUsd,
        'counterAssetId': counterAssetId,
        'counterSymbol': counterSymbol,
        'counterQty': counterQty,
      };

  static ActivityEntry fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: j['id'] as String,
        ts: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        type: j['type'] as String,
        assetId: j['assetId'] as String,
        assetSymbol: j['assetSymbol'] as String,
        qty: (j['qty'] as num).toDouble(),
        priceUsd: (j['priceUsd'] as num).toDouble(),
        valueUsd: (j['valueUsd'] as num).toDouble(),
        counterAssetId: j['counterAssetId'] as String?,
        counterSymbol: j['counterSymbol'] as String?,
        counterQty: (j['counterQty'] as num?)?.toDouble(),
      );
}

class Holding {
  const Holding({required this.assetId, required this.qty, required this.costBasis});

  final String assetId;
  final double qty;
  final double costBasis; // total USD invested for the current qty

  double get avgCost => qty > 0 ? costBasis / qty : 0;

  Holding adjusted(double qtyDelta, double costDelta) {
    final q = qty + qtyDelta;
    final c = costBasis + costDelta;
    return Holding(
      assetId: assetId,
      qty: q >= 1e-12 ? q : 0,
      costBasis: c >= 1e-10 ? c : 0,
    );
  }

  Map<String, dynamic> toJson() => {'assetId': assetId, 'qty': qty, 'costBasis': costBasis};

  static Holding fromJson(Map<String, dynamic> j) => Holding(
        assetId: j['assetId'] as String,
        qty: (j['qty'] as num).toDouble(),
        costBasis: (j['costBasis'] as num).toDouble(),
      );
}
