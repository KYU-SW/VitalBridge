import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

// ───────── 결과 추가 ─────────
class AddScreen extends StatelessWidget {
  const AddScreen({super.key});
  // TODO: image_picker + google_mlkit_text_recognition 으로 실제 OCR 연결.
  // 지금은 프로토타입과 같이 인식 결과 샘플값을 보여줍니다.
  static final ocrSample = mk([
    24.1,
    128,
    84,
    102,
    14.1,
    185,
    160,
    52,
    110,
    34,
    38,
    58,
    1.0,
  ]);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('건강검진 결과 추가')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Text('📃', style: TextStyle(fontSize: 90)),
          const SizedBox(height: 12),
          Text('건강검진 결과지를 준비해 주세요', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '글자가 잘 보이도록 밝은 곳에서 촬영하면\n인식이 더 정확해요.',
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () =>
                  push(c, EntryScreen(initial: ocrSample, search: false)),
              child: const Text('📷 결과지 촬영'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () =>
                  push(c, EntryScreen(initial: ocrSample, search: false)),
              child: const Text('🖼️ 갤러리에서 사진 선택'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () =>
                  push(c, EntryScreen(initial: const [], search: true)),
              child: const Text('✏️ 직접 입력하기'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ───────── 인식 결과 확인 / 직접 입력 (공용) ─────────
class EntryScreen extends StatefulWidget {
  final List<Rec> initial;
  final bool search;
  const EntryScreen({super.key, required this.initial, required this.search});
  @override
  State<EntryScreen> createState() => _EntryState();
}

class _EntryState extends State<EntryScreen> {
  final ctrls = <Item, TextEditingController>{};
  final sq = TextEditingController();
  final hosp = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    for (final r in widget.initial) {
      ctrls[byName[r.n]!] = TextEditingController(text: f(r.v));
    }
  }

  @override
  void dispose() {
    for (final t in ctrls.values) {
      t.dispose();
    }
    sq.dispose();
    hosp.dispose();
    super.dispose();
  }

  void toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> save() async {
    if (saving) return;

    if (ctrls.isEmpty) {
      toast('검사 항목을 1개 이상 추가해 주세요.');
      return;
    }

    final recs = <Rec>[];

    for (final it in items.where(ctrls.containsKey)) {
      final v = double.tryParse(ctrls[it]!.text);

      if (v == null || !v.isFinite) {
        toast('${it.name} 값을 올바른 숫자로 입력해 주세요.');
        return;
      }

      recs.add(Rec(it.name, v));
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final h = hosp.text.trim();

    setState(() => saving = true);

    try {
      await app.add(
        Checkup(
          id,
          date.toIso8601String().substring(0, 10),
          h.isEmpty ? '직접 입력' : h,
          recs,
        ),
      );

      if (!mounted) return;

      final nav = Navigator.of(context);

      nav.popUntil((r) => r.isFirst);

      nav.push(MaterialPageRoute(builder: (_) => ResultScreen(selectId: id)));
    } catch (_) {
      if (mounted) {
        toast('저장에 실패했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final q = sq.text.replaceAll(' ', '').toLowerCase();
    final sug = q.isEmpty
        ? <Item>[]
        : items
              .where(
                (i) =>
                    !ctrls.containsKey(i) &&
                    (i.name + i.title + i.cat + (alias[i.name] ?? ''))
                        .replaceAll(' ', '')
                        .toLowerCase()
                        .contains(q),
              )
              .take(6)
              .toList();
    String last = '';
    final rows = <Widget>[];
    for (final e in ctrls.entries) {
      final it = e.key;
      if (!widget.search && it.cat != last) {
        last = it.cat;
        rows.add(catHeader(last));
      }
      final v = double.tryParse(e.value.text);
      rows.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (v != null)
                        StatusBadge(it.judge(v, app.male))
                      else
                        const Text('값을 입력하세요', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: e.value,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    ' ${it.unit}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (widget.search)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => ctrls.remove(it)?.dispose()),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.search ? '직접 입력' : '인식 결과 확인')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.search
                ? '입력할 검사명을 검색해서 추가하세요.'
                : '인식된 값이 맞는지 확인하고, 틀린 값은 직접 수정해 주세요.',
          ),
          if (widget.search) ...[
            const SizedBox(height: 8),
            TextField(
              controller: sq,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '검사명 검색 (예: 혈당, LDL, 간, 빈혈)',
                border: OutlineInputBorder(),
              ),
            ),
            if (q.isNotEmpty && sug.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('검색 결과가 없어요.'),
              ),
            for (final i in sug)
              ListTile(
                title: Text(i.name),
                subtitle: Text(i.cat),
                trailing: const Text('＋ 추가'),
                onTap: () => setState(() {
                  ctrls[i] = TextEditingController();
                  sq.clear();
                }),
              ),
            catHeader('추가한 항목 (${ctrls.length})'),
            if (ctrls.isEmpty) const Text('아직 추가한 항목이 없어요.'),
          ],
          ...rows,
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('검진 날짜')),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: c,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => date = d);
                        },
                        child: Text(date.toIso8601String().substring(0, 10)),
                      ),
                    ],
                  ),
                  TextField(
                    controller: hosp,
                    decoration: const InputDecoration(
                      labelText: '병원 (선택)',
                      hintText: '예: 한국병원',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,

            child: FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '저장 중...' : '저장하기'),
            ),
          ),
        ],
      ),
    );
  }
}
