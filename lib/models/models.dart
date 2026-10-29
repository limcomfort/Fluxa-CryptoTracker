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
        ChartRange.h1 => '1Ч',
        ChartRange.d1 => '24Ч',
        ChartRange.w1 => '7Д',
        ChartRange.m1 => '30Д',
        ChartRange.y1 => '1Г',
      };

  int get apiDays => switch (this) {
        ChartRange.h1 => 1,
        ChartRange.d1 => 1,
        ChartRange.w1 => 7,
        ChartRange.m1 => 30,
        ChartRange.y1 => 365,
      };
}

/// Kind of an analytical signal shown on the Signals tab.
class SignalKind {
  static const String up = 'up'; // bullish market signal
  static const String down = 'down'; // bearish market signal
  static const String watch = 'watch'; // watchlist / portfolio event
  static const String info = 'info'; // neutral market info
}

/// An auto-generated analytical event (market move, regime shift,
/// watchlist/portfolio change) persisted locally.
class SignalEntry {
  const SignalEntry({
    required this.id,
    required this.ts,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.assetId,
    this.assetSymbol,
  });

  final String id;
  final DateTime ts;
  final String kind; // up | down | watch | info
  final String title; // short event headline, e.g. "BTC +4.2% · momentum"
  final String subtitle; // human context line
  final String? assetId; // asset the signal is about, if any
  final String? assetSymbol;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.millisecondsSinceEpoch,
        'kind': kind,
        'title': title,
        'subtitle': subtitle,
        'assetId': assetId,
        'assetSymbol': assetSymbol,
      };

  static SignalEntry fromJson(Map<String, dynamic> j) => SignalEntry(
        id: j['id'] as String,
        ts: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        kind: j['kind'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        assetId: j['assetId'] as String?,
        assetSymbol: j['assetSymbol'] as String?,
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
