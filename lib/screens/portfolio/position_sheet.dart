import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Opens the tracked-position bottom sheet over the current tab.
/// Pass a [assetId] to edit an existing position, otherwise it starts
/// empty and the user picks an asset to track.
Future<void> showPositionSheet(BuildContext context, {String? assetId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PositionSheet(assetId: assetId),
  );
}

/// Manual bookkeeping sheet: pick an asset, quantity and average price.
/// Nothing is bought or sold anywhere — this only feeds the portfolio
/// analytics (value, P&L, allocation).
class PositionSheet extends StatefulWidget {
  const PositionSheet({super.key, this.assetId});

  final String? assetId;

  @override
  State<PositionSheet> createState() => _PositionSheetState();
}

class _PositionSheetState extends State<PositionSheet> {
  late String? _assetId = widget.assetId;
  final _qtyCtrl = TextEditingController();
  final _avgCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<MarketStore>();
    final held = _assetId == null ? null : store.holdingOf(_assetId!);
    _qtyCtrl.addListener(_recompute);
    _avgCtrl.addListener(_recompute);
    if (held != null) {
      _qtyCtrl.text = _trimQty(held.qty);
      _avgCtrl.text = _trimQty(held.avgCost);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _avgCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  double? get _avg => double.tryParse(_avgCtrl.text.replaceAll(',', '.'));

  void _recompute() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final asset = store.assetById(_assetId);
    final held = _assetId == null ? null : store.holdingOf(_assetId!);
    final marketValue = _qty * (asset?.price ?? 0);
    final avgVal = _avg;
    final double? editedCost;
    if (avgVal != null) {
      editedCost = _qty * avgVal;
    } else if (held != null) {
      editedCost = held.costBasis;
    } else {
      editedCost = null;
    }
    final errorText = <String?>{
      if (_assetId == null) 'Выберите актив для отслеживания',
      if (_assetId != null && _qty <= 0) 'Введите количество больше нуля',
      if (_avg != null && _avg! <= 0) 'Средняя цена должна быть положительной',
    }.firstOrNull;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.insights, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(held == null ? 'Отследить позицию' : 'Редактировать позицию', style: AppText.title),
            const Spacer(),
            if (held != null)
              TextButton(
                onPressed: _busy ? null : _remove,
                child: const Text('Удалить', style: TextStyle(color: AppColors.red, fontSize: 13)),
              ),
          ]),
          const SizedBox(height: 4),
          const Text('Только аналитика — сделки не совершаются. '
              'Количество и средняя цена задают расчёт P&L.',
              style: AppText.micro),
          const SizedBox(height: 14),

          _AssetPicker(label: 'Актив', value: asset, onTap: _busy ? null : () => _pickAsset()),
          const SizedBox(height: 12),

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
          const SizedBox(height: 10),
          TextField(
            controller: _avgCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
            style: AppText.priceLg,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: asset == null ? 'Средняя цена' : 'Средняя цена · USD',
              hintStyle: AppText.priceLg.copyWith(color: AppColors.textFaint),
              border: InputBorder.none,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 14),

          _PreviewRow(asset: asset, qty: _qty, avg: _avg, marketValue: marketValue, costBasis: editedCost),

          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(errorText, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),

          CtaButton(
            held == null ? 'Отследить позицию' : 'Сохранить позицию',
            filled: true,
            onTap: (_busy || errorText != null) ? null : _submit,
          ),
        ]),
      ),
    );
  }

  Future<void> _pickAsset() async {
    final picked = await _assetSearchDialog(context, context.read<MarketStore>());
    if (!mounted) return;
    if (picked != null) {
      final a = context.read<MarketStore>().assetById(picked);
      setState(() {
        _assetId = picked;
        _qtyCtrl.clear();
        _avgCtrl.clear();
        if (a != null) {
          _qtyCtrl.text = '1';
          _avgCtrl.text = _trimQty(a.price);
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final store = context.read<MarketStore>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final asset = store.assetById(_assetId);
    final err = store.upsertPosition(assetId: _assetId!, qty: _qty, avgCost: _avg);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(asset == null
          ? 'Позиция сохранена'
          : 'Отслеживаем ${fmt.fmtQty(_qty)} ${asset.symbol} для аналитики'),
    ));
  }

  Future<void> _remove() async {
    final nav = Navigator.of(context);
    await context.read<MarketStore>().removePosition(_assetId!);
    if (nav.canPop()) nav.pop();
  }

  static String _trimQty(double v) => fmt.qtyPlain(v);
}

// ---------- helpers ----------

/// Searchable asset picker dialog (same look as the converter's).
Future<String?> _assetSearchDialog(BuildContext context, MarketStore store) {
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => _AssetSearchDialog(store: store),
  );
}

class _AssetSearchDialog extends StatefulWidget {
  const _AssetSearchDialog({required this.store});
  final MarketStore store;

  @override
  State<_AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends State<_AssetSearchDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.store.assets.where((a) {
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
                hintText: 'Поиск активов',
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
  final VoidCallback? onTap;

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
              Text(value?.name ?? 'Выбрать актив', style: const TextStyle(
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.asset,
    required this.qty,
    required this.avg,
    required this.marketValue,
    required this.costBasis,
  });

  final Asset? asset;
  final double qty;
  final double? avg;
  final double marketValue;
  final double? costBasis;

  @override
  Widget build(BuildContext context) {
    if (asset == null || qty <= 0 || costBasis == null) {
      return const SizedBox(
        height: 34,
        child: Center(child: Text('Стоимость и P&L появятся по мере ввода', style: AppText.micro)),
      );
    }
    final pnl = marketValue - costBasis!;
    final pnlPct = costBasis! > 0 ? pnl / costBasis! * 100 : 0.0;
    final color = pnl >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.insights, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmt.fmtUsd(marketValue),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 2),
            Text('текущая стоимость · вложено ${fmt.fmtUsd(costBasis!)}', style: AppText.caption),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.fmtSignedUsd(pnl),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(fmt.fmtSignedPct(pnlPct),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      ]),
    );
  }
}
