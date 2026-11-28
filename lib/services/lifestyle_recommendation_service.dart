import 'daily_health_service.dart';
import 'goal_rules.dart';

// 실제 기록 기반 생활패턴 목표 추천 결과
class LifestyleRecommendation {
  final int? suggestedSteps;
  final int? suggestedExerciseWeekly;
  final String? sleepAdvice;

  final int validStepDays;
  final int validSleepDays;
  final int validExerciseDays;

  const LifestyleRecommendation({
    required this.suggestedSteps,
    required this.suggestedExerciseWeekly,
    required this.sleepAdvice,
    required this.validStepDays,
    required this.validSleepDays,
    required this.validExerciseDays,
  });

  bool get hasStepRecommendation => suggestedSteps != null;

  bool get hasExerciseRecommendation => suggestedExerciseWeekly != null;

  bool get hasSleepAdvice => sleepAdvice != null;
}

class LifestyleRecommendationService {
  final DailyHealthService _dailyService = DailyHealthService();

  // 날짜만 비교하기 위한 키
  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // 실제 Supabase 기록으로 목표 계산
  Future<LifestyleRecommendation> calculateRecommendations({
    // 운동 데이터의 강도 및 미측정일 처리 방식이
    // 검증되기 전까지 자동 추천은 비활성화
    bool exerciseDataVerified = false,
  }) async {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final yesterday = today.subtract(const Duration(days: 1));

    final start = today.subtract(const Duration(days: 14));

    // 1. 최근 완료된 14일의 실제 DB 기록 조회
    final records = await _dailyService.loadRecords(
      start: start,
      end: yesterday,
    );

    // 2. 날짜별 기록 분류
    final recordsByDate = <String, List<DailyHealthRecord>>{};

    for (final record in records) {
      if (!record.valid) continue;

      final key = _dateKey(record.date);

      recordsByDate.putIfAbsent(key, () => <DailyHealthRecord>[]).add(record);
    }

    final steps = <int?>[];
    final sleep = <int?>[];
    final exercise = <int?>[];

    // 3. 오래된 날짜부터 최근 날짜까지 처리
    for (var offset = 14; offset >= 1; offset--) {
      final date = today.subtract(Duration(days: offset));

      final candidates = recordsByDate[_dateKey(date)] ?? [];

      // 출처가 여러 개면 중복 합산 위험이 있으므로
      // 대표 출처 선택 전까지 보류
      if (candidates.length != 1) {
        steps.add(null);
        sleep.add(null);
        exercise.add(null);
        continue;
      }

      final record = candidates.single;

      // 걸음 수
      steps.add(record.steps);

      // 실제 수면시간 (분)
      sleep.add(record.sleepMinutes);

      // 중강도 상당 운동 시간
      // 중강도 1분 + 고강도 2분 상당
      // 단, 두 강도 값이 모두 확인되어야 계산
      if (exerciseDataVerified &&
          record.moderateMinutes != null &&
          record.vigorousMinutes != null) {
        final total = record.moderateMinutes! + 2 * record.vigorousMinutes!;

        exercise.add(total);
      } else {
        exercise.add(null);
      }
    }

    // 4. 걸음 수 추천
    // 최근 9일이 전부 유효해야 계산
    final last9Steps = steps.sublist(5);

    final suggestedSteps = GoalRules.recommendSteps(last9Steps);

    // 5. 수면 분석
    // 최근 14일, 최소 유효 기록 10일
    final sleepAdvice = GoalRules.sleepSuggestion(sleep);

    // 6. 운동 목표 추천
    // 강도별 데이터 검증 이후에만 활성화
    final suggestedExercise = GoalRules.recommendExercise(exercise);

    return LifestyleRecommendation(
      suggestedSteps: suggestedSteps,
      suggestedExerciseWeekly: suggestedExercise,
      sleepAdvice: sleepAdvice,
      validStepDays: last9Steps.whereType<int>().length,
      validSleepDays: sleep
          .whereType<int>()
          .where((value) => value >= 0)
          .length,
      validExerciseDays: exercise
          .whereType<int>()
          .where((value) => value >= 0)
          .length,
    );
  }
}
