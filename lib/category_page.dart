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
          appBar: AppBar(title: const Text('カテゴリ')),
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
                  ...state.categoriesOf(false).map((c) => _tile(c)),
                  _header(context, '収入カテゴリ'),
                  ...state.categoriesOf(true).map((c) => _tile(c)),
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

  Widget _tile(Category c) => ListTile(
        leading: CircleAvatar(radius: 10, backgroundColor: Color(c.color)),
        title: Text(c.name),
        trailing: c.builtin
            ? const Text('標準', style: TextStyle(color: Colors.grey))
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '削除',
                onPressed: () => state.removeCategory(c.id),
              ),
      );
}