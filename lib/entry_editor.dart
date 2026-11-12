import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'category_page.dart';
import 'models.dart';

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
  String? _amountError;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _isIncome = e?.isIncome ?? false;
    _date = e?.date ?? widget.date;
    _amountCtrl = TextEditingController(text: e == null ? '' : '${e.amount}');
    _memoCtrl = TextEditingController(text: e?.memo ?? '');
    _categoryId = e?.categoryId ?? s.categoriesOf(_isIncome).first.id;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
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

  void _save() {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = '金額を入力してください');
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
    Navigator.pop(context);
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
              widget.initial == null ? '項目を追加' : '項目を編集',
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
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '金額',
                prefixText: '¥ ',
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
                    ActionChip(
                      label: Text(m),
                      onPressed: () => setState(() {
                        _memoCtrl.text = m;
                        _memoCtrl.selection =
                            TextSelection.collapsed(offset: m.length);
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}