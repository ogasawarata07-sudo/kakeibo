import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'category_page.dart';
import 'models.dart';

// 金額入力用の整形:
// 数字と + - × ÷ だけを許可し、数字の部分に3桁カンマを付ける(1000 → 1,000)
class AmountFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'[0-9+\-*/×÷]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset < 0
        ? text.length
        : newValue.selection.baseOffset;

    // 許可された文字だけ残し、カーソルより前に何文字あったかを数える
    final raw = StringBuffer();
    var rawCursor = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_allowed.hasMatch(ch)) {
        raw.write(ch);
        if (i < cursor) rawCursor++;
      }
    }

    // 数字のかたまりごとに、先頭の余分な0を消してカンマを付ける
    final formatted = raw.toString().replaceAllMapped(RegExp(r'\d+'), (m) {
      final digits = m[0]!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      return digits.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (x) => ',',
      );
    });

    // カンマを除いた文字数が rawCursor になる位置へカーソルを戻す
    var count = 0;
    var pos = 0;
    while (pos < formatted.length && count < rawCursor) {
      if (formatted[pos] != ',') count++;
      pos++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

// 項目の追加・編集用の入力シート(画面下からせり上がる)
class EntryEditor extends StatefulWidget {
  final AppState state;
  final Entry? initial; // null なら新規追加、あれば編集
  final DateTime date; // 新規追加時の日付

  const EntryEditor({
    super.key,
    required this.state,
    required this.initial,
    required this.date,
  });

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late bool _isIncome;
  late String _categoryId;
  late DateTime _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;
  final _amountFocus = FocusNode();
  String? _amountError;
  int _addedCount = 0; // 「続けて入力」で追加した件数

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _isIncome = e?.isIncome ?? false;
    _date = e?.date ?? widget.date;
    _amountCtrl = TextEditingController(text: e == null ? '' : commas(e.amount));
    _memoCtrl = TextEditingController(text: e?.memo ?? '');
    _categoryId = e?.categoryId ?? s.categoriesOf(_isIncome).first.id;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  // カーソル位置に + - × ÷ を挿入する(数字キーボードに記号がないスマホ用)
  void _insertOp(String op) {
    final t = _amountCtrl.text;
    final sel = _amountCtrl.selection;
    final start = sel.start < 0 ? t.length : sel.start;
    final end = sel.end < 0 ? t.length : sel.end;
    _amountCtrl.value = TextEditingValue(
      text: t.replaceRange(start, end, op),
      selection: TextSelection.collapsed(offset: start + op.length),
    );
    _amountFocus.requestFocus();
    setState(() => _amountError = null);
  }

  // keepOpen=true なら、保存したあとシートを閉じずに続けて入力できる
  void _save({bool keepOpen = false}) {
    final amount = evalAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = '金額を入力してください(例: 500+300)');
      return;
    }
    final cats = s.categoriesOf(_isIncome);
    final cid = cats.any((c) => c.id == _categoryId) ? _categoryId : cats.first.id;

    final entry = Entry(
      id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      amount: amount,
      memo: _memoCtrl.text.trim(),
      categoryId: cid,
      isIncome: _isIncome,
    );
    if (widget.initial == null) {
      s.addEntry(entry);
    } else {
      s.updateEntry(entry);
    }

    if (keepOpen && widget.initial == null) {
      // 金額とメモだけ空にして、種類・カテゴリ・日付はそのまま続ける
      setState(() {
        _addedCount++;
        _amountError = null;
        _amountCtrl.clear();
        _memoCtrl.clear();
      });
      _amountFocus.requestFocus();
      return;
    }
    Navigator.pop(context);
  }

  // 編集中の項目を削除する(5秒間は「元に戻す」できる)
  void _delete() {
    final e = widget.initial!;
    final messenger = ScaffoldMessenger.of(context);
    s.removeEntry(e.id);
    Navigator.pop(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('削除しました'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () => s.restoreEntry(e),
        ),
      ));
  }

  // メモ候補を選んだとき:同じメモの前回の項目から、カテゴリと金額を自動入力
  void _pickMemo(String m) {
    final last = s.lastEntryWithMemo(m, _isIncome);
    setState(() {
      _memoCtrl.text = m;
      _memoCtrl.selection = TextSelection.collapsed(offset: m.length);
      if (last != null) {
        if (s.categoriesOf(_isIncome).any((c) => c.id == last.categoryId)) {
          _categoryId = last.categoryId;
        }
        // すでに金額を入れているときは上書きしない
        if (_amountCtrl.text.trim().isEmpty) {
          _amountCtrl.text = commas(last.amount);
          _amountError = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = s.categoriesOf(_isIncome);
    final q = _memoCtrl.text.trim();
    // 入力中の文字を含む候補だけに絞る
    final suggestions = s
        .memoSuggestions(_isIncome)
        .where((m) => q.isEmpty || (m.contains(q) && m != q))
        .toList();

    // 計算式が入っているときは、結果をフィールドの下に表示する
    final hasOp = RegExp(r'[+\-×÷*/]').hasMatch(_amountCtrl.text);
    final calc = evalAmount(_amountCtrl.text);
    final String? helper =
        hasOp ? (calc != null ? '= ${yen(calc)}' : '計算式を確認してください') : null;

    final isNew = widget.initial == null;

    return Padding(
      // キーボードが出ても入力欄が隠れないように下に余白を足す
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNew ? '項目を追加' : '項目を編集',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('収入')),
              ],
              selected: {_isIncome},
              onSelectionChanged: (v) => setState(() {
                _isIncome = v.first;
                _categoryId = s.categoriesOf(_isIncome).first.id;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountFormatter()],
              onChanged: (_) => setState(() => _amountError = null),
              decoration: InputDecoration(
                labelText: '金額(計算もできます)',
                prefixText: '¥ ',
                helperText: helper,
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final op in const ['+', '-', '×', '÷'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => _insertOp(op),
                      child: Text(op, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('カテゴリ'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    avatar: CircleAvatar(radius: 6, backgroundColor: Color(c.color)),
                    label: Text(c.name),
                    selected: c.id == _categoryId,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('追加'),
                  onPressed: () async {
                    final c = await showAddCategoryDialog(
                      context,
                      s,
                      fixedIsIncome: _isIncome,
                    );
                    if (c != null && mounted) setState(() => _categoryId = c.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoCtrl,
              onChanged: (_) => setState(() {}), // 候補の絞り込み更新用
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in suggestions)
                    ActionChip(label: Text(m), onPressed: () => _pickMemo(m)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${_date.year}/${_date.month}/${_date.day}'),
              ),
            ),
            if (_addedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$_addedCount件 追加しました。続けて入力できます',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isNew)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('削除'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                if (isNew) ...[
                  OutlinedButton(
                    onPressed: () => _save(keepOpen: true),
                    child: const Text('続けて入力'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}