import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/market_store.dart';
import '../../widgets/common.dart';

/// Opening the converter: as a regular pushed route with the app's dark theme.
Future<void> openConverter(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConverterScreen(), fullscreenDialog: true),
    );

/// Converter screen: stream one asset into another at the same live prices
/// used across the whole app.
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  String? _fromId;
  String? _toId;
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sensible default pair: BTC -> ETH.
    final store = context.read<MarketStore>();
    _fromId = store.assets.isNotEmpty ? store.assets.first.id : null;
    _toId = store.assets.length > 1 ? store.assets[1].id : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeForward());
    _fromCtrl.addListener(_onEdited);
    _toCtrl.addListener(_onBackEdited);
  }

  bool _lockBack = false;
  bool _lockForward = false;

  void _onEdited() {
    if (_lockBack) {
      _lockBack = false;
      return;
    }
    _recomputeForward();
  }

  void _onBackEdited() {
    if (_lockForward) {
      _lockForward = false;
      return;
    }
    _recomputeBackward();
  }

  double get _fromAmt => double.tryParse(_fromCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _toAmt => double.tryParse(_toCtrl.text.replaceAll(',', '.')) ?? 0;

  Future<void> _recomputeForward() async {
    final store = context.read<MarketStore>();
    final a = store.assetById(_fromId);
    final b = store.assetById(_toId);
    if (a == null || b == null || b.price == 0 || _fromAmt <= 0) {
      _toCtrl.text = '';
      return;
    }
    _lockForward = true;
    _toCtrl.text = _trim(fmt.qtyPlain(_fromAmt * a.price / b.price));
  }

  Future<void> _recomputeBackward() async {
    final store = context.read<MarketStore>();
    final a = store.assetById(_fromId);
    final b = store.assetById(_toId);
    if (a == null || b == null || a.price == 0 || _toAmt <= 0) {
      _fromCtrl.text = '';
      return;
    }
    _lockBack = true;
    _fromCtrl.text = _trim(fmt.qtyPlain(_toAmt * b.price / a.price));
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MarketStore>();
    final a = store.assetById(_fromId);
    final b = store.assetById(_toId);
    final rate = a == null || b == null || b.price == 0 ? 0.0 : a.price / b.price;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Конвертер')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(children: [
            _ConvertCard(
              ctrl: _fromCtrl,
              asset: a,
              label: 'Конвертируете',
              accent: false,
              onPick: () => _pick(side: _Side.from),
            ),
            _SwapSeparator(onSwap: _swap),
            _ConvertCard(
              ctrl: _toCtrl,
              asset: b,
              label: 'Получаете',
              accent: true,
              onPick: () => _pick(side: _Side.to),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Row(children: [
                const Icon(Icons.stacked_line_chart, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      rate > 0
                          ? '1 ${a?.symbol} = ${fmt.qtyPlain(rate)} ${b?.symbol}'
                          : 'Выберите два актива',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rate > 0
                          ? '1 ${b?.symbol} = ${fmt.qtyPlain(1 / rate)} ${a?.symbol}'
                          : 'Цены обновляются каждую минуту',
                      style: AppText.caption,
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Чистый калькулятор курсов · сделки не совершаются '
                    'и позиции не меняются, когда вы смотрите пару.',
                    style: AppText.micro,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            InfoFooter(
              'Курсы из ${store.status == MarketStatus.offline ? 'демонстрационных' : 'живых'} данных рынка · USD',
              showAbout: false,
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _swap() async {
    final t = _fromId;
    final fromText = _fromCtrl.text;
    setState(() {
      _fromId = _toId;
      _toId = t;
      // Both fields go through controlled recompute
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = fromText;
    });
    _recomputeForward();
  }

  Future<void> _pick({required _Side side}) async {
    final store = context.read<MarketStore>();
    final exclude = side == _Side.from ? _toId : _fromId;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _AssetSearchDialog(store: store, excludeId: exclude),
    );
    if (picked == null) return;
    setState(() {
      if (side == _Side.from) {
        _fromId = picked;
      } else {
        _toId = picked;
      }
    });
    _recomputeForward();
  }
}

enum _Side { from, to }

String _trim(String s) {
  final i = s.indexOf('.');
  if (i < 0) return s;
  return s.length - i - 1 > 8 ? s.substring(0, i + 9) : s;
}

class _SwapSeparator extends StatelessWidget {
  const _SwapSeparator({required this.onSwap});
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: const Offset(0, -1),
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: AppColors.elevated,
            foregroundColor: AppColors.accent,
          ),
          onPressed: onSwap,
          icon: const Icon(Icons.import_export, size: 20),
          tooltip: 'Поменять местами',
        ),
      );
}

// CARD ==============================================================

class _ConvertCard extends StatelessWidget {
  const _ConvertCard({
    required this.ctrl,
    required this.asset,
    required this.label,
    required this.accent,
    required this.onPick,
  });

  final TextEditingController ctrl;
  final Asset? asset;
  final String label;
  final bool accent;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? AppColors.surface : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption),
          SizedBox(
            width: 170,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
              style: AppText.priceLg,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '0.00',
                hintStyle: AppText.priceLg.copyWith(color: AppColors.textFaint),
              ),
            ),
          ),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              if (asset != null) ...[
                CoinBadge(asset!, size: 24),
                const SizedBox(width: 7),
              ],
              Text(asset?.symbol ?? 'Выбрать', style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(width: 5),
              const Icon(Icons.expand_circle_down_outlined, size: 18, color: AppColors.textFaint),
            ]),
          ),
        ),
      ]),
    );
  }
}

// SEARCH DIALOG (shared look with trade sheet) ======================

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
