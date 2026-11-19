import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/common.dart';

// ───────── 내 검진 결과 ─────────
class ResultScreen extends StatefulWidget {
  final String? selectId;
  const ResultScreen({super.key, this.selectId});
  @override
  State<ResultScreen> createState() => _ResultState();
}

class _ResultState extends State<ResultScreen> {
  String? sid;

  @override
  void initState() {
    super.initState();
    sid =
        widget.selectId ?? (app.checkups.isEmpty ? null : app.checkups.last.id);
  }

  Future<void> confirmDelete(Checkup ck) async {
    if (app.busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('검진 기록 삭제'),
        content: Text(
          '${ck.date} · ${ck.hospital}\n'
          '이 기록을 삭제할까요? 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) return;

    try {
      await app.remove(ck.id);

      if (!mounted) return;

      setState(() {
        sid = app.checkups.isEmpty ? null : app.checkups.last.id;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('검진 기록이 삭제되었습니다.')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext c) {
    if (app.checkups.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('내 건강검진 결과')),
        body: const Center(
          child: Text(
            '저장된 검진 기록이 없어요.\n홈에서 결과를 추가해 보세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final idx = app.checkups.indexWhere((x) => x.id == sid);
    final sel = idx < 0 ? app.checkups.length - 1 : idx;
    final ck = app.checkups[sel];
    final ks = ck.r.map(stat).toList();
    int cn(int k) => ks.where((x) => x == k).length;
    String last = '';
    final rows = <Widget>[];
    for (final r in ck.r) {
      final it = byName[r.n]!;
      if (it.cat != last) {
        last = it.cat;
        rows.add(catHeader(last));
      }
      rows.add(
        Card(
          child: ListTile(
            title: Text(
              r.n,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${f(r.v)} ${it.unit}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [StatusBadge(stat(r)), const Icon(Icons.chevron_right)],
            ),
            onTap: () => push(c, DetailScreen(r)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 건강검진 결과'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '이 기록 삭제',
            onPressed: () => confirmDelete(ck),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButton<int>(
            isExpanded: true,
            value: sel,
            items: [
              for (var i = 0; i < app.checkups.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${app.checkups[i].date} · ${app.checkups[i].hospital}',
                  ),
                ),
            ],
            onChanged: (x) => setState(() => sid = app.checkups[x!].id),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: Text('${ck.r.length}개 항목')),
                  for (final k in [0, 1, 2])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '${kLabel[k]} ${cn(k)}',
                        style: TextStyle(
                          color: kStat[k],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Rec r;
  const DetailScreen(this.r, {super.key});
  @override
  Widget build(BuildContext c) {
    final it = byName[r.n]!;
    final k = stat(r);
    return Scaffold(
      appBar: AppBar(title: Text(r.n)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('${it.cat} · ${it.title}'),
                  Text(
                    f(r.v),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: kStat[k],
                    ),
                  ),
                  Text(it.unit),
                  const SizedBox(height: 6),
                  StatusBadge(k),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '참고범위',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (var j = 0; j < 3; j++)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: j == k ? kStat[j].withAlpha(30) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 90, child: StatusBadge(j)),
                          Expanded(
                            child: Text(
                              it.ref[j] +
                                  (RegExp(r'\d').hasMatch(it.ref[j])
                                      ? ' ${it.unit}'
                                      : ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (it.name == '혈색소' || it.name == '감마GTP')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('현재 설정: ${app.male ? '남' : '여'}성 기준'),
                    ),
                  if (it.name == '감마GTP')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '※ 주의/위험의 구체적 수치는 기준표에 없어 정상 상한의 1~2배 / 2배 초과로 임의 설정했어요.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '검사 설명',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(it.desc, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ),
          const Text(kDisc, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
