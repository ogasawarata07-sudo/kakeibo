import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// アプリ全体のデータを持つクラス。
// ChangeNotifier = Javaの Observable に近い仕組み。
// データを変更して notifyListeners() を呼ぶと、
// このオブジェクトを監視している画面(ListenableBuilder)が自動で再描画される。
class AppState extends ChangeNotifier {
  static const _storageKey = 'kakeibo_data_v1';

  final List<Entry> entries = [];
  final List<Category> categories = [];
  int budget = 0; // 月の予算(0なら未設定)

  // ---------------- 保存・読み込み ----------------

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    try {
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        entries.addAll((j['entries'] as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>)));
        categories.addAll((j['categories'] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>)));
        budget = (j['budget'] as int?) ?? 0;
      }
    } catch (_) {
      entries.clear();
      categories.clear();
    }
    if (categories.isEmpty) categories.addAll(defaultCategories());
    _ensureMinimum();
  }

  // 全データを1つの文字列(JSON)にする。保存とバックアップの両方で使う
  String exportJson() => jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'budget': budget,
      });

  // バックアップ文字列から復元する。成功したら true
  // 先に一時リストへ読み込んでから入れ替えるので、失敗しても今のデータは消えない
  Future<bool> importJson(String raw) async {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final newEntries = (j['entries'] as List)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCategories = (j['categories'] as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      entries
        ..clear()
        ..addAll(newEntries);
      categories
        ..clear()
        ..addAll(newCategories.isEmpty ? defaultCategories() : newCategories);
      budget = (j['budget'] as int?) ?? 0;
      _ensureMinimum();
      _sort();
      _changed();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, exportJson());
  }

  // 変更があったときは必ずこれを呼ぶ(画面更新 + 保存)
  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------------- 項目の操作 ----------------

  void _sort() => entries.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });

  void addEntry(Entry e) {
    entries.add(e);
    _sort();
    _changed();
  }

  void updateEntry(Entry e) {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) entries[i] = e;
    _sort();
    _changed();
  }

  void removeEntry(String id) {
    entries.removeWhere((e) => e.id == id);
    _changed();
  }

  // 「元に戻す」用(同じidのまま追加し直す)
  void restoreEntry(Entry e) => addEntry(e);

  // ---------------- カテゴリの操作 ----------------

  Category addCategory(String name, bool isIncome) {
    final c = Category(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      isIncome: isIncome,
      color: categoryPalette[categories.length % categoryPalette.length],
    );
    categories.add(c);
    _changed();
    return c;
  }

  // 削除できたら true。収入・支出それぞれ最後の1つは消せない(入力画面が成り立たなくなるため)
  bool removeCategory(String id) {
    final target = categories.where((c) => c.id == id).toList();
    if (target.isEmpty) return false;
    final isIncome = target.first.isIncome;
    if (categories.where((c) => c.isIncome == isIncome).length <= 1) {
      return false;
    }
    categories.removeWhere((c) => c.id == id);
    _changed();
    return true;
  }

  // 削除した標準カテゴリを元に戻す。戻した件数を返す
  int restoreDefaults() {
    var n = 0;
    for (final d in defaultCategories()) {
      if (!categories.any((c) => c.id == d.id)) {
        categories.add(d);
        n++;
      }
    }
    if (n > 0) _changed();
    return n;
  }

  // 収入・支出のカテゴリがそれぞれ最低1つあるようにする(読み込みデータが不完全なときの保険)
  void _ensureMinimum() {
    for (final d in defaultCategories()) {
      if ((d.id == 'e_other' || d.id == 'i_other') &&
          !categories.any((c) => c.isIncome == d.isIncome)) {
        categories.add(d);
      }
    }
  }

  // 同じメモの直近の項目(メモ候補を選んだとき、カテゴリと金額を自動入力するのに使う)
  Entry? lastEntryWithMemo(String memo, bool isIncome) {
    for (final e in entries) {
      if (e.memo == memo && e.isIncome == isIncome) return e;
    }
    return null;
  }

  List<Category> categoriesOf(bool isIncome) =>
      categories.where((c) => c.isIncome == isIncome).toList();

  // カテゴリが削除済みなどで見つからないときは「未分類」を返す
  Category categoryOf(String id, bool isIncome) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => Category(
        id: 'none',
        name: '未分類',
        isIncome: isIncome,
        color: 0xFF9E9E9E,
      ),
    );
  }

  void setBudget(int v) {
    budget = v;
    _changed();
  }

  // ---------------- 集計 ----------------

  List<Entry> entriesOfMonth(DateTime m) => entries
      .where((e) => e.date.year == m.year && e.date.month == m.month)
      .toList();

  List<Entry> entriesOfDay(DateTime d) => entries
      .where((e) =>
          e.date.year == d.year &&
          e.date.month == d.month &&
          e.date.day == d.day)
      .toList();

  int total(DateTime month, bool isIncome) => entriesOfMonth(month)
      .where((e) => e.isIncome == isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  // 全期間の残高(収入合計 - 支出合計)
  int get allBalance =>
      entries.fold(0, (sum, e) => sum + (e.isIncome ? e.amount : -e.amount));

  // 月のカテゴリ別合計(金額の多い順)
  List<MapEntry<Category, int>> categoryTotals(DateTime month, bool isIncome) {
    final map = <String, int>{};
    for (final e in entriesOfMonth(month)) {
      if (e.isIncome == isIncome) {
        map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
      }
    }
    final list = map.entries
        .map((kv) => MapEntry(categoryOf(kv.key, isIncome), kv.value))
        .toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // よく使うメモの候補(使用回数が多い順。足りなければ初期候補で補う)
  List<String> memoSuggestions(bool isIncome) {
    final counts = <String, int>{};
    for (final e in entries) {
      if (e.isIncome == isIncome && e.memo.isNotEmpty) {
        counts[e.memo] = (counts[e.memo] ?? 0) + 1;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final result = sorted.take(8).toList();
    final defaults = isIncome
        ? ['給料', 'ボーナス', 'お小遣い']
        : ['コンビニ', '電車', 'スーパー', 'ランチ', 'カフェ'];
    for (final d in defaults) {
      if (result.length >= 8) break;
      if (!result.contains(d)) result.add(d);
    }
    return result;
  }
}