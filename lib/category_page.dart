import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';

// カテゴリ追加ダイアログ(カテゴリ画面と入力画面の両方から使う)
// fixedIsIncome を渡すと収入/支出の選択を出さずに固定する。
Future<Category?> showAddCategoryDialog(
  BuildContext context,
  AppState state, {
  bool? fixedIsIncome,
}) {
  final ctrl = TextEditingController();
  bool isIncome = fixedIsIncome ?? false;

  return showDialog<Category>(
    context: context,
    // StatefulBuilder = ダイアログの中だけで setState を使うための部品
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('カテゴリを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fixedIsIncome == null) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('支出')),
                  ButtonSegment(value: true, label: Text('収入')),
                ],
                selected: {isIncome},
                onSelectionChanged: (v) => setLocal(() => isIncome = v.first),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'カテゴリ名',
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
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, state.addCategory(name, isIncome));
            },
            child: const Text('追加'),
          ),
        ],
      ),
    ),
  );
}

class CategoryPage extends StatelessWidget {
  final AppState state;
  const CategoryPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('カテゴリ'),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: '標準カテゴリを復元',
                onPressed: () {
                  final n = state.restoreDefaults();
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                      content: Text(
                        n > 0 ? '標準カテゴリを$n件 復元しました' : '復元するカテゴリはありません',
                      ),
                    ));
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddCategoryDialog(context, state),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _header(context, '支出カテゴリ'),
                  ...state.categoriesOf(false).map((c) => _tile(context, c)),
                  _header(context, '収入カテゴリ'),
                  ...state.categoriesOf(true).map((c) => _tile(context, c)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _tile(BuildContext context, Category c) => ListTile(
        leading: CircleAvatar(radius: 10, backgroundColor: Color(c.color)),
        title: Text(c.name),
        subtitle: c.builtin ? const Text('標準') : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '削除',
          onPressed: () => _confirmDelete(context, c),
        ),
      );

  Future<void> _confirmDelete(BuildContext context, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${c.name}」を削除しますか?'),
        content: const Text('このカテゴリを使っていた項目は消えず、「未分類」と表示されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = state.removeCategory(c.id);
    if (!done) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('収入・支出それぞれ、カテゴリは最低1つ必要です'),
        ));
    }
  }
}