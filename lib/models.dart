// データの「形」を定義するファイル(Javaのモデルクラスに相当)

// 追加したカテゴリに順番に割り当てる色(ARGBの整数)
const categoryPalette = <int>[
  0xFFEF5350,
  0xFFFF7043,
  0xFFFFCA28,
  0xFF66BB6A,
  0xFF26A69A,
  0xFF42A5F5,
  0xFF5C6BC0,
  0xFFAB47BC,
  0xFFEC407A,
  0xFF8D6E63,
];

// 1234567 → ¥1,234,567 / -500 → -¥500
String yen(int n) {
  final s = n.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
  return '${n < 0 ? '-' : ''}¥$s';
}

// ------------------------------------------------------------
// カテゴリ(食費、給料など)
// ------------------------------------------------------------
class Category {
  final String id;
  final String name;
  final bool isIncome; // true=収入用 / false=支出用
  final int color;
  final bool builtin; // true=最初から用意されたもの(削除不可)

  const Category({
    required this.id,
    required this.name,
    required this.isIncome,
    required this.color,
    this.builtin = false,
  });

  // 保存用:オブジェクト → Map(JSON)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isIncome': isIncome,
        'color': color,
        'builtin': builtin,
      };

  // 読み込み用:Map(JSON) → オブジェクト
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        isIncome: j['isIncome'] as bool,
        color: j['color'] as int,
        builtin: (j['builtin'] as bool?) ?? false,
      );
}

// ------------------------------------------------------------
// 1件の収入または支出
// ------------------------------------------------------------
class Entry {
  final String id;
  final DateTime date; // 時刻は使わない(年月日のみ)
  final int amount; // 常に正の数。収入か支出かは isIncome で区別
  final String memo;
  final String categoryId;
  final bool isIncome;

  const Entry({
    required this.id,
    required this.date,
    required this.amount,
    required this.memo,
    required this.categoryId,
    required this.isIncome,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'memo': memo,
        'categoryId': categoryId,
        'isIncome': isIncome,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: j['amount'] as int,
        memo: j['memo'] as String,
        categoryId: j['categoryId'] as String,
        isIncome: j['isIncome'] as bool,
      );
}

// 最初から用意しておくカテゴリ
List<Category> defaultCategories() => const [
      Category(id: 'e_food', name: '食費', isIncome: false, color: 0xFFEF5350, builtin: true),
      Category(id: 'e_daily', name: '日用品', isIncome: false, color: 0xFFFF7043, builtin: true),
      Category(id: 'e_transport', name: '交通費', isIncome: false, color: 0xFF42A5F5, builtin: true),
      Category(id: 'e_house', name: '住居・光熱費', isIncome: false, color: 0xFF5C6BC0, builtin: true),
      Category(id: 'e_fun', name: '娯楽', isIncome: false, color: 0xFFAB47BC, builtin: true),
      Category(id: 'e_medical', name: '医療', isIncome: false, color: 0xFF26A69A, builtin: true),
      Category(id: 'e_other', name: 'その他', isIncome: false, color: 0xFF8D6E63, builtin: true),
      Category(id: 'i_salary', name: '給料', isIncome: true, color: 0xFF66BB6A, builtin: true),
      Category(id: 'i_bonus', name: '賞与', isIncome: true, color: 0xFFFFCA28, builtin: true),
      Category(id: 'i_other', name: 'その他収入', isIncome: true, color: 0xFF26A69A, builtin: true),
    ];