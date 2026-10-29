import 'package:flutter/material.dart';

/// Project brand. "Fluxa" — from *flux*: the flow of prices, candles and
/// conversions that never stand still. The 60-second auto-refresh in
/// [MarketStore] is the "pulse" that keeps the flow alive.
class Brand {
  Brand._();

  static const name = 'Fluxa';
  static const tagline = 'Идите в потоке рынка';
  static const version = '1.0.0';
  static const copyright = '© 2026 Fluxa';

  static void showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: name,
      applicationVersion: version,
      applicationIcon: const _BrandMark(),
      applicationLegalese: '$copyright\n\n$tagline.\n\n'
          'Данные рынка: публичный API CoinGecko. Если API недоступен, '
          'приложение держит последние сохранённые цены и переходит на '
          'демонстрационные данные. Портфель, избранное и сигналы '
          'хранятся локально на этом устройстве.',
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF17181C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26272C)),
      ),
      child: const Icon(Icons.waterfall_chart, color: Color(0xFFF6B60D), size: 26),
    );
  }
}
