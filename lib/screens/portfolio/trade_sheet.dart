import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

enum TradeTab { buy, sell, convert }

extension TradeTabX on TradeTab {
  String get label => switch (this) { TradeTab.buy => 'Buy', TradeTab.sell => 'Sell', TradeTab.convert => 'Convert' };
}

/// Opens the mock-style trade bottom sheet over the current tab.
Future<void> showTradeSheet(
  BuildContext context, {
  TradeTab tab = TradeTab.buy,
  String? prefillAssetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TradeSheet(tab: tab, prefillAssetId: prefillAssetId),
  );
}

class TradeSheet extends StatefulWidget {
  const TradeSheet({super.key, this.tab = TradeTab.buy, this.prefillAssetId});
  final TradeTab tab;
  final String? prefillAssetId;

  @override
  State<TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<TradeSheet> {
  late TradeTab _tab = widget.tab;
  late String? _assetId = widget.prefillAssetId;
  String? _targetAssetId;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final asset = store.assetById(_assetId);
    final target = store.assetById(_targetAssetId);
    final String? assetId = _assetId;
    final held = assetId == null ? null : store.holdingOf(assetId);
    final value = asset == null ? 0.0 : _qty * asset.price;
    final converted = asset == null || target == null || target.price == 0 ? 0.0 : value / target.price;
    final errorText = <String>{
      if (_tab != TradeTab.buy && held == null) 'You do not hold this asset yet',
      if (_tab != TradeTab.buy && held != null && held.qty < _qty) 'Maximum: ${fmt.fmtQty(held.qty)} ${asset?.symbol ?? ''}',
    }.firstOrNull;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // tab segmented control
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              for (final t in TradeTab.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = t),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tab == t ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _tab == t ? FontWeight.w700 : FontWeight.w500,
                          color: _tab == t ? AppColors.accent : AppColors.textDim,
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // asset selector(s)
          if (_tab == TradeTab.convert) ...[
            _AssetPicker(
              label: 'From',
              value: asset,
              onTap: () => _pickAsset(excludeId: null),
            ),
            _RowBetween(
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.elevated,
                  foregroundColor: AppColors.accent,
                ),
                onPressed: _swap,
                icon: const Icon(Icons.import_export, size: 20),
              ),
            ),
            _AssetPicker(
              label: 'To',
              value: target,
              onTap: () => _pickTarget(asset?.id),
            ),
          ] else
            _AssetPicker(label: 'Asset', value: asset, onTap: () => _pickAsset(excludeId: null)),
          const SizedBox(height: 12),

          // qty input
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
            style: AppText.priceLg,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: asset == null ? '0.00' : '0.00 ${asset.symbol}',
              hintStyle: AppText.priceLg.copyWith(color: AppColors.textFaint),
              border: InputBorder.none,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_tab != TradeTab.buy && held != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('You hold', style: AppText.caption),
                const Spacer(),
                Text('${fmt.fmtQty(held.qty)} ${asset?.symbol ?? ''}', style: AppText.caption),
                const SizedBox(width: 8),
                FilterChip2(label: 'MAX', selected: false, onTap: () {
                  setState(() => _qtyCtrl.text = held.qty.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), ''));
                }),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // preview line
          _PreviewRow(
            asset: asset,
            target: target,
            qty: _qty,
            value: value,
            converted: converted,
            mode: _tab,
          ),

          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(errorText, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),

          CtaButton(
            switch (_tab) {
              TradeTab.buy => 'Confirm buy',
              TradeTab.sell => 'Confirm sell',
              TradeTab.convert => 'Confirm conversion',
            },
            filled: true,
            onTap: (_busy || asset == null || _qty <= 0 || errorText != null) ? null : _submit,
          ),
        ]),
      ),
    );
  }

  Future<void> _swap() async {
    setState(() {
      final t = _targetAssetId;
      _targetAssetId = _assetId;
      if (_tab == TradeTab.convert) {
        _assetId = t;
      } else {
        _tab = TradeTab.convert;
      }
    });
  }

  Future<void> _pickAsset({String? excludeId}) async {
    final store = context.read<MarketStore>();
    final picked = await _assetSearchDialog(context, store, excludeId: excludeId);
    if (picked != null) setState(() => _assetId = picked);
  }

  Future<void> _pickTarget(String? excludeId) async {
    final store = context.read<MarketStore>();
    final picked = await _assetSearchDialog(context, store, excludeId: excludeId);
    if (picked != null) setState(() => _targetAssetId = picked);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final store = context.read<MarketStore>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final asset = store.assetById(_assetId);
    final err = store.executeTrade(
      type: switch (_tab) { TradeTab.buy => TradeType.buy, TradeTab.sell => TradeType.sell, TradeTab.convert => TradeType.convert },
      assetId: _assetId!,
      qty: _qty,
      targetAssetId: _tab == TradeTab.convert ? _targetAssetId : null,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pop();
    final tail = switch (_tab) {
      TradeTab.buy => 'for ${fmt.fmtUsd(_qty * (asset?.price ?? 0))}',
      TradeTab.sell => 'for ${fmt.fmtUsd(_qty * (asset?.price ?? 0))}',
      TradeTab.convert => 'to ${store.assetById(_targetAssetId)?.symbol ?? ''}',
    };
    messenger.showSnackBar(SnackBar(content: Text('Traded ${fmt.fmtQty(_qty)} ${asset?.symbol ?? ''} $tail')));
  }
}

// ---------- helpers ----------

/// Searchable asset picker dialog used by the trade sheet and the converter.
Future<String?> _assetSearchDialog(
  BuildContext context,
  MarketStore store, {
  String? excludeId,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => _AssetSearchDialog(store: store, excludeId: excludeId),
  );
}

class _AssetSearchDialog extends StatefulWidget {
  const _AssetSearchDialog({required this.store, this.excludeId});
  final MarketStore store;
  final String? excludeId;

  @override
  State<_AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends State<_AssetSearchDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.store.assets.where((a) {
      if (a.id == widget.excludeId) return false;
      if (_q.isEmpty) return true;
      return a.name.toLowerCase().contains(_q) || a.symbol.toLowerCase().contains(_q);
    }).take(30).toList();

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search assets',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                return ListTile(
                  visualDensity: VisualDensity.compact,
                  leading: CoinBadge(a, size: 32),
                  title: Text(a.name, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.symbol, style: AppText.caption),
                  trailing: Text(fmt.fmtPricePlain(a.price), style: AppText.caption),
                  onTap: () => Navigator.of(context).pop(a.id),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({required this.label, required this.value, required this.onTap});
  final String label;
  final Asset? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          if (value != null) ...[
            CoinBadge(value!, size: 30),
            const SizedBox(width: 10),
          ] else
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.add_circle_outline, size: 30, color: AppColors.textFaint),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.micro),
              Text(value?.name ?? 'Select asset', style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
            ]),
          ),
          Text(value == null ? '' : fmt.fmtPricePlain(value!.price), style: AppText.caption),
          const Icon(Icons.expand_circle_down_outlined, size: 20, color: AppColors.textFaint),
        ]),
      ),
    );
  }
}

class _RowBetween extends StatelessWidget {
  const _RowBetween({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(width: 4),
          child,
          const SizedBox(width: 4),
        ],
      );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.asset,
    required this.target,
    required this.qty,
    required this.value,
    required this.converted,
    required this.mode,
  });

  final Asset? asset;
  final Asset? target;
  final double qty;
  final double value;
  final double converted;
  final TradeTab mode;

  @override
  Widget build(BuildContext context) {
    if (asset == null || qty <= 0) {
      return const SizedBox(
        height: 34,
        child: Center(child: Text('Enter an amount · price updates live', style: AppText.micro)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(TradeTab.buy == mode
            ? Icons.south_west
            : mode == TradeTab.sell
                ? Icons.north_east
                : Icons.swap_horiz,
            size: 18,
            color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              mode == TradeTab.convert
                  ? '${fmt.fmtQty(converted)} ${target?.symbol ?? '—'}'
                  : fmt.fmtUsd(value),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 2),
            Text(
              '@ ${fmt.fmtUsdPrice(asset!.price)} per ${asset!.symbol}',
              style: AppText.caption,
            ),
          ]),
        ),
      ]),
    );
  }
}
