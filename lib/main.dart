import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'widgets/common.dart';
import 'screens/upload_screen.dart';
import 'screens/result_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qyedncouxpfqcbhgetsn.supabase.co',
    publishableKey: 'sb_publishable_1h5_Ia8JSA_csjdn4wWWWw_82iNI1C7',
  );

  //await app.load();
  runApp(const HealthApp());
}

final supabase = Supabase.instance.client;

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  State<HealthApp> createState() => _HealthAppState();
}

class _HealthAppState extends State<HealthApp> {
  final auth = Supabase.instance.client.auth;

  late final authStream = auth.onAuthStateChange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Authentication stream error');
        }

        final uid = auth.currentSession?.user.id;

        return MaterialApp(
          key: ValueKey(uid),
          title: 'VitalBridge',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: kPri, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: kPri,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: uid == null ? const LoginScreen() : AccountHome(userId: uid),
        );
      },
    );
  }
}

class AccountHome extends StatefulWidget {
  final String userId;

  const AccountHome({super.key, required this.userId});

  @override
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  late Future<void> loading;

  @override
  void initState() {
    super.initState();
    loading = app.load(widget.userId);
  }

  @override
  void dispose() {
    app.clearSession(widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('데이터를 불러오지 못했습니다.'),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        loading = app.load(widget.userId);
                      });
                    },
                    child: const Text('다시 시도'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.auth.signOut();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그아웃 실패')),
                          );
                        }
                      }
                    },
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            ),
          );
        }

        return const HomeScreen();
      },
    );
  }
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
    appBar: AppBar(
      title: const Text('VitalBridge'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: '로그아웃',
          onPressed: () async {
            try {
              await Supabase.instance.client.auth.signOut();
            } catch (_) {
              if (c.mounted) {
                ScaffoldMessenger.of(c)
                    .showSnackBar(const SnackBar(content: Text('로그아웃 실패')));
              }
            }
          },
        ),
      ],
    ),

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

                onSelectionChanged: app.busy
                    ? null
                    : (s) async {
                        try {
                          await app.setMale(s.first);
                        } catch (_) {
                          if (c.mounted) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(content: Text('설정 저장에 실패했습니다.')),
                            );
                          }
                        }
                      },
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
