import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Pushed search screen from the Markets app bar.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final list = store.assets
        .where((a) => _q.isEmpty || a.name.toLowerCase().contains(_q) || a.symbol.toLowerCase().contains(_q))
        .toList();
    final ui = context.read<UiState>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 16, color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Search name or symbol',
              hintStyle: const TextStyle(color: AppColors.textFaint),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textDim),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _q = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: list.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No results',
                  subtitle: "Nothing matches '$_q' in the top markets.",
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(top: 8),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 0),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return MarketRow(
                    a,
                    onTap: () {
                      ui.openDetail(a.id);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
      ),
    );
  }
}
