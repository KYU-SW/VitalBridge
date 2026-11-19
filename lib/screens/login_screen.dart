import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = Supabase.instance.client.auth;

  bool loading = false;
  bool hidden = true;

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> submit(bool signup) async {
    if (email.text.trim().isEmpty || password.text.length < 8) {
      message('이메일과 8자리 이상의 비밀번호를 입력하세요.');
      return;
    }

    setState(() => loading = true);

    try {
      if (signup) {
        final response = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );

        if (response.session == null) {
          message('인증 이메일을 확인해 주세요.');
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      message(e.message);
    } catch (_) {
      message('오류가 발생했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 70,
                    color: Color(0xFF009688),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'VitalBridge',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const Text('나의 건강을 연결하다'),
                  const SizedBox(height: 32),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => hidden = !hidden);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (loading)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => submit(false),
                        child: const Text('로그인'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => submit(true),
                      child: const Text('회원가입'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
