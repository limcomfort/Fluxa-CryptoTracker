import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/theme.dart';
import 'data/market_repository.dart';
import 'state/market_store.dart';
import 'screens/root_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Russian UI: date symbols for 'd MMM'-style patterns + a default fallback
  // locale for every DateFormat/NumberFormat created without an explicit one.
  initializeDateFormatting('ru');
  Intl.defaultLocale = 'ru';
  runApp(const FluxaApp());
}

class FluxaApp extends StatelessWidget {
  const FluxaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MarketRepository>(create: (_) => MarketRepository()),
        ChangeNotifierProvider<MarketStore>(
          create: (ctx) => MarketStore(ctx.read<MarketRepository>())..init(),
        ),
        ChangeNotifierProvider<UiState>(create: (_) => UiState()),
      ],
      child: MaterialApp(
        title: Brand.name,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootShell(),
      ),
    );
  }
}
