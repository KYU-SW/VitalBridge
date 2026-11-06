import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets/common.dart';
import 'screens/upload_screen.dart';
import 'screens/result_screen.dart';
import 'screens/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: '건강검진 도우미',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: kPri, useMaterial3: true),
    darkTheme: ThemeData(
      colorSchemeSeed: kPri,
      useMaterial3: true,
      brightness: Brightness.dark,
    ),
    home: const HomeScreen(),
  );
}

// ───────── 홈 ─────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget menu(BuildContext c, String icon, String t, String s, Widget to) =>
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            radius: 26,
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(c, to),
        ),
      );

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('건강검진 도우미')),
    body: ListenableBuilder(
      listenable: app,
      builder: (c, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('안녕하세요 👋', style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('건강검진 결과를 쉽게 확인하고 비교해 보세요.'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('성별 (일부 항목 기준이 달라요)')),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('남')),
                  ButtonSegment(value: false, label: Text('여')),
                ],
                selected: {app.male},
                onSelectionChanged: (s) => app.setMale(s.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          menu(c, '📄', '건강검진 결과 추가', '결과지를 촬영하거나 사진을 올려요', const AddScreen()),
          menu(c, '📋', '내 건강검진 결과', '저장된 검사 결과를 확인해요', const ResultScreen()),
          menu(c, '📈', '연도별 비교', '검진 결과의 변화를 그래프로 봐요', const CompareScreen()),
          const SizedBox(height: 16),
          const Text(kDisc, style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
