import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/common.dart';
import '../widgets/line_painter.dart';

// ───────── 연도별 비교 ─────────
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareState();
}

class _CompareState extends State<CompareScreen> {
  int a = math.max(0, app.checkups.length - 2), b = app.checkups.length - 1;
  bool barMode = true;
  String sel = '공복혈당';

  Widget pick(String label, int val, ValueChanged<int> on) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          DropdownButton<int>(
            isExpanded: true,
            value: val,
            items: [
              for (var i = 0; i < app.checkups.length; i++)
                DropdownMenuItem(value: i, child: Text(app.checkups[i].date)),
            ],
            onChanged: (x) => on(x!),
          ),
        ],
      ),
    ),
  );

  Widget bar(String l, double v, double mx, Color col) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(l, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mx == 0 ? 0 : v / mx,
              minHeight: 18,
              color: col,
              backgroundColor: col.withAlpha(30),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            f(v),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  List<Widget> barView() {
    final B = app.checkups[a], A = app.checkups[b];
    final out = <Widget>[
      Row(
        children: [
          pick('이전 검진', a, (x) => setState(() => a = x)),
          pick('이후 검진', b, (x) => setState(() => b = x)),
        ],
      ),
    ];
    for (final ar in A.r) {
      final prev = B.r.where((x) => x.n == ar.n);
      if (prev.isEmpty) continue;
      final br = prev.first;
      final df = double.parse((ar.v - br.v).toStringAsFixed(1));
      final mx = math.max(ar.v, br.v);
      out.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ar.n,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '변화: ${df > 0 ? '+' : ''}${f(df)} ${byName[ar.n]!.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kStat[stat(ar)],
                      ),
                    ),
                  ],
                ),
                bar(B.date, br.v, mx, const Color(0xFF80CBC4)),
                bar(A.date, ar.v, mx, kPri),
                const SizedBox(height: 6),
                StatusBadge(stat(ar)),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> lineView(BuildContext c) {
    final it = byName[sel]!;
    final cks = [
      for (final x in app.checkups)
        if (x.r.any((r) => r.n == sel)) x,
    ];
    final recs = [for (final x in cks) x.r.firstWhere((r) => r.n == sel)];
    final vals = [for (final r in recs) r.v];
    final df = double.parse((vals.last - vals.first).toStringAsFixed(1));
    return [
      Wrap(
        spacing: 6,
        children: [
          for (final i in items)
            ChoiceChip(
              label: Text(i.name),
              selected: i.name == sel,
              onSelected: (_) => setState(() => sel = i.name),
            ),
        ],
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${it.name} 추이 (${it.unit})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 210,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: LinePainter(
                    vals,
                    [for (final x in cks) x.date.substring(0, 4)],
                    recs.map(stat).toList(),
                    it.band(app.male),
                    Theme.of(c).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cks.first.date.substring(0, 4)} → ${cks.last.date.substring(0, 4)} 변화',
                    ),
                  ),
                  Text(
                    '${df > 0 ? '+' : ''}${f(df)} ${it.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              for (var i = 0; i < cks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(cks[i].date)),
                      Text(
                        f(vals[i]),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(stat(recs[i])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext c) {
    if (app.checkups.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('연도별 비교')),
        body: const Center(child: Text('비교하려면 검진 결과가 2개 이상 필요해요.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('연도별 비교')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('막대 비교')),
              ButtonSegment(value: false, label: Text('추이 그래프')),
            ],
            selected: {barMode},
            onSelectionChanged: (s) => setState(() => barMode = s.first),
          ),
          const SizedBox(height: 12),
          ...(barMode ? barView() : lineView(c)),
          const Text('※ 참고용 정보이며 의료 진단이 아닙니다.', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
