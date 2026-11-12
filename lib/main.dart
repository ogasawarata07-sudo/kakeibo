import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'category_page.dart';
import 'charts_page.dart';
import 'entry_editor.dart';
import 'models.dart';

// 起動時に保存データを読み込んでからアプリを開始する
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(KakeiboApp(state: state));
}

class KakeiboApp extends StatelessWidget {
  final AppState state;
  const KakeiboApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家計簿',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HomePage(state: state),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _month; // 表示中の月(1日の日付で持つ)
  late DateTime _selected; // 選択中の日

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  // 月の切り替え。DateTime(2026, 13) は自動的に 2027年1月 になる
  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final now = DateTime.now();
      final isThisMonth = now.year == _month.year && now.month == _month.month;
      _selected = isThisMonth ? DateTime(now.year, now.month, now.day) : _month;
    });
  }

  void _openEditor(Entry? entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryEditor(state: s, initial: entry, date: _selected),
    );
  }

  Future<void> _editBudget() async {
    final ctrl = TextEditingController(text: s.budget > 0 ? '${s.budget}' : '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('月の予算(支出)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '¥ ',
            hintText: '例: 100000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('予算なし')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) s.setBudget(result);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // バックアップ:データを文字列としてクリップボードにコピー / 貼り付けて復元
  Future<void> _openBackup() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップ'),
        content: const Text(
          'データを文字列としてコピーし、メモアプリなどに貼り付けて保存できます。'
          '復元するときは、その文字列を貼り付けてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restore();
            },
            child: const Text('貼り付けて復元'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: s.exportJson()));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _toast('コピーしました。メモアプリなどに貼り付けて保存してください');
            },
            child: const Text('データをコピー'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('データを復元'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('今あるデータはすべて上書きされます。'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'コピーしたデータを貼り付け',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('復元'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final ok = await s.importJson(text.trim());
    if (!mounted) return;
    _toast(ok ? '復元しました' : '復元に失敗しました。コピーしたデータが正しいか確認してください');
  }

  // ListenableBuilder: s(AppState)が notifyListeners() するたびに再構築される
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('家計簿'),
            actions: [
              IconButton(
                icon: const Icon(Icons.pie_chart_outline),
                tooltip: 'グラフ',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChartsPage(state: s, initialMonth: _month),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'カテゴリ',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CategoryPage(state: s)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.savings_outlined),
                tooltip: '予算',
                onPressed: _editBudget,
              ),
              IconButton(
                icon: const Icon(Icons.backup_outlined),
                tooltip: 'バックアップ',
                onPressed: _openBackup,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(null),
            icon: const Icon(Icons.add),
            label: Text('${_selected.month}/${_selected.day} に追加'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                children: [
                  _monthNav(),
                  _summary(),
                  _calendar(),
                  _dayPanel(),
                  const SizedBox(height: 88), // ボタンに隠れないよう余白
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- 月の切り替え ----------
  Widget _monthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moveMonth(-1)),
        Text(
          '${_month.year}年${_month.month}月',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _moveMonth(1)),
      ],
    );
  }

  // ---------- 月の集計 + 予算バー ----------
  Widget _summary() {
    final income = s.total(_month, true);
    final expense = s.total(_month, false);
    final diff = income - expense;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _stat('収入', income, Colors.green),
                _stat('支出', expense, Colors.red),
                _stat('収支', diff, diff >= 0 ? Colors.blue : Colors.red),
              ],
            ),
            const SizedBox(height: 4),
            Text('これまでの残高: ${yen(s.allBalance)}',
                style: const TextStyle(fontSize: 12)),
            const Divider(),
            _budgetBar(expense),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            FittedBox(
              child: Text(
                yen(value),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      );

  Widget _budgetBar(int expense) {
    if (s.budget <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _editBudget,
          icon: const Icon(Icons.savings_outlined),
          label: const Text('月の予算を設定'),
        ),
      );
    }
    final ratio = expense / s.budget;
    // 80%以上でオレンジ、100%以上で赤
    final color = ratio >= 1
        ? Colors.red
        : ratio >= 0.8
            ? Colors.orange
            : Colors.green;
    final remain = s.budget - expense;
    return InkWell(
      onTap: _editBudget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('予算 ${yen(s.budget)}(${(ratio * 100).round()}%)'),
              Text(
                remain >= 0 ? 'あと ${yen(remain)}' : '${yen(-remain)} 超過',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- カレンダー ----------
  Widget _calendar() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day; // 翌月0日=月末
    final leading = _month.weekday % 7; // 1日の前の空白数(日曜=0)
    final rows = ((leading + daysInMonth) / 7).ceil();
    const names = ['日', '月', '火', '水', '木', '金', '土'];

    // 日ごとの収入・支出の合計
    final inc = <int, int>{};
    final exp = <int, int>{};
    for (final e in s.entriesOfMonth(_month)) {
      final m = e.isIncome ? inc : exp;
      m[e.date.day] = (m[e.date.day] ?? 0) + e.amount;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      names[i],
                      style: TextStyle(
                        color: i == 0 ? Colors.red : (i == 6 ? Colors.blue : null),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _dayCell(r * 7 + c - leading + 1, daysInMonth, inc, exp)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, int daysInMonth, Map<int, int> inc, Map<int, int> exp) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 60);

    final date = DateTime(_month.year, _month.month, day);
    final now = DateTime.now();
    final isToday = date == DateTime(now.year, now.month, now.day);
    final isSelected = date == _selected;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selected = date),
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : null,
          border: Border.all(
            color: isToday ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: date.weekday == 7
                    ? Colors.red
                    : (date.weekday == 6 ? Colors.blue : null),
              ),
            ),
            if (inc[day] != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('+${inc[day]}',
                    style: const TextStyle(fontSize: 10, color: Colors.green)),
              ),
            if (exp[day] != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('-${exp[day]}',
                    style: const TextStyle(fontSize: 10, color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 選択した日の項目一覧 ----------
  Widget _dayPanel() {
    final list = s.entriesOfDay(_selected);
    const wd = ['月', '火', '水', '木', '金', '土', '日'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${_selected.month}月${_selected.day}日(${wd[_selected.weekday - 1]})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('この日の項目はありません', style: TextStyle(color: Colors.grey)),
            )
          else
            for (final e in list) _entryTile(e),
        ],
      ),
    );
  }

  // 左にスワイプで削除(Dismissible)→ SnackBarの「元に戻す」で復元
  Widget _entryTile(Entry e) {
    final cat = s.categoryOf(e.categoryId, e.isIncome);
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        s.removeEntry(e.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text('削除しました'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () => s.restoreEntry(e),
            ),
          ));
      },
      child: ListTile(
        leading: CircleAvatar(radius: 12, backgroundColor: Color(cat.color)),
        title: Text(e.memo.isEmpty ? cat.name : e.memo),
        subtitle: Text(cat.name),
        trailing: Text(
          '${e.isIncome ? '+' : '-'}${yen(e.amount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: e.isIncome ? Colors.green : Colors.red,
          ),
        ),
        onTap: () => _openEditor(e), // タップで編集
      ),
    );
  }
}