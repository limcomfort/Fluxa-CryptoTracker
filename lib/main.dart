import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/theme.dart';
import 'data/market_repository.dart';
import 'state/market_store.dart';
import 'screens/root_shell.dart';

void main() {
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
        home: const RootShell(),
      ),
    );
  }
}
