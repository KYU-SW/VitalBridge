import 'package:supabase_flutter/supabase_flutter.dart';

// 사용자 생활패턴 목표 데이터
class LifestyleGoals {
  final int? steps;
  final int? sleepMinutes;
  final int? exerciseWeekly;

  const LifestyleGoals({this.steps, this.sleepMinutes, this.exerciseWeekly});
}

// Supabase 목표 저장 및 불러오기
class LifestyleGoalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 현재 로그인한 사용자 ID
  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    return user.id;
  }

  // 1. 사용자 목표 저장 및 수정
  Future<void> saveGoals({
    required int steps,
    required int sleepMinutes,
    required int exerciseWeekly,
  }) async {
    if (steps < 1 || steps > 100000) {
      throw ArgumentError('걸음 수 목표가 올바르지 않습니다.');
    }

    if (sleepMinutes < 30 || sleepMinutes > 1440) {
      throw ArgumentError('수면 목표가 올바르지 않습니다.');
    }

    if (exerciseWeekly < 1 || exerciseWeekly > 10080) {
      throw ArgumentError('운동 목표가 올바르지 않습니다.');
    }

    await _supabase.from('lifestyle_goals').upsert({
      'user_id': _userId,
      'goal_steps': steps,
      'goal_sleep_minutes': sleepMinutes,
      'goal_exercise_weekly': exerciseWeekly,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  // 2. 로그인한 사용자의 목표 불러오기
  Future<LifestyleGoals?> loadGoals() async {
    final result = await _supabase
        .from('lifestyle_goals')
        .select('goal_steps, goal_sleep_minutes, goal_exercise_weekly')
        .eq('user_id', _userId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return LifestyleGoals(
      steps: result['goal_steps'] as int?,
      sleepMinutes: result['goal_sleep_minutes'] as int?,
      exerciseWeekly: result['goal_exercise_weekly'] as int?,
    );
  }
}
