import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models.dart';

class ChartsPage extends StatefulWidget {
  final AppState state;
  final DateTime initialMonth;
  const ChartsPage({super.key, required this.state, required this.initialMonth});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  late DateTime _month;
  bool _isIncome = false;

  AppState get s => widget.state;
  Color get _barColor => _isIncome ? Colors.green : Colors.red;
  String get _typeLabel => _isIncome ? '収入' : '支出';

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  void _move(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  String _compact(int v) {
    if (v >= 10000) {
      return '${(v / 10000).toStringAsFixed(v % 10000 == 0 ? 0 : 1)}万';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController + TabBar + TabBarView でタブ切り替えを作る
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('グラフ'),
          bottom: const TabBar(tabs: [
            Tab(text: 'カテゴリ別'),
            Tab(text: '日別'),
            Tab(text: '月別'),
          ]),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _move(-1),
                    ),
                    Text(
                      '${_month.year}年${_month.month}月',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _move(1),
                    ),
                  ],
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('支出')),
                    ButtonSegment(value: true, label: Text('収入')),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (v) => setState(() => _isIncome = v.first),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(children: [_pie(), _daily(), _monthly()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- カテゴリ別の円グラフ ----------
  Widget _pie() {
    final list = s.categoryTotals(_month, _isIncome);
    final total = list.fold(0, (sum, e) => sum + e.value);
    if (total == 0) return const Center(child: Text('この月のデータはありません'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 240,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (final e in list)
                  PieChartSectionData(
                    value: e.value.toDouble(),
                    color: Color(e.key.color),
                    radius: 70,
                    title: '${(e.value * 100 / total).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final e in list)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 8, backgroundColor: Color(e.key.color)),
            title: Text(e.key.name),
            trailing: Text(yen(e.value)),
          ),
        ListTile(
          dense: true,
          title: Text('$_typeLabel合計'),
          trailing: Text(
            yen(total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ---------- 日別の棒グラフ ----------
  Widget _daily() {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final sums = List<int>.filled(days + 1, 0); // 1日〜末日を添字1〜daysで使う
    for (final e in s.entriesOfMonth(_month)) {
      if (e.isIncome == _isIncome) sums[e.date.day] += e.amount;
    }
    if (sums.every((v) => v == 0)) {
      return const Center(child: Text('この月のデータはありません'));
    }
    return _bar(
      [
        for (var d = 1; d <= days; d++)
          BarChartGroupData(x: d, barRods: [
            BarChartRodData(
              toY: sums[d].toDouble(),
              color: _barColor,
              width: 6,
              borderRadius: BorderRadius.circular(2),
            ),
          ]),
      ],
      _titles((v) => '${v.toInt()}', bottomInterval: 5),
      '${_month.month}月の日別$_typeLabel',
    );
  }

  // ---------- 月別の棒グラフ(直近12か月) ----------
  Widget _monthly() {
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(_month.year, _month.month - i),
    ];
    final sums = [for (final m in months) s.total(m, _isIncome)];
    if (sums.every((v) => v == 0)) {
      return const Center(child: Text('データはありません'));
    }
    return _bar(
      [
        for (var i = 0; i < 12; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: sums[i].toDouble(),
              color: _barColor,
              width: 14,
              borderRadius: BorderRadius.circular(3),
            ),
          ]),
      ],
      _titles((v) {
        final i = v.toInt();
        return (i >= 0 && i < 12) ? '${months[i].month}月' : '';
      }, bottomInterval: 1),
      '${_month.year}年${_month.month}月までの12か月の$_typeLabel',
    );
  }

  // 棒グラフ共通部分
  Widget _bar(List<BarChartGroupData> groups, FlTitlesData titles, String caption) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(caption, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              barGroups: groups,
              titlesData: titles,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
      ],
    );
  }

  // 軸の目盛りの設定(上と右は非表示、左は金額、下は引数で指定)
  FlTitlesData _titles(String Function(double) bottom, {double? bottomInterval}) {
    final none = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return FlTitlesData(
      topTitles: none,
      rightTitles: none,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (v, meta) =>
              Text(_compact(v.toInt()), style: const TextStyle(fontSize: 10)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: bottomInterval,
          getTitlesWidget: (v, meta) =>
              Text(bottom(v), style: const TextStyle(fontSize: 10)),
        ),
      ),
    );
  }
}