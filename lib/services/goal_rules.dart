class GoalRules {
  // 1. 걸음 수 목표 추천
  // 최근 완료된 9일의 유효한 걸음 수 기록 사용
  // 60백분위수: 오름차순 6번째 값
  static int? recommendSteps(List<int?> last9Days) {
    if (last9Days.length != 9) return null;

    if (last9Days.any((value) => value == null || value < 0)) {
      return null;
    }

    final sorted = last9Days.cast<int>()..sort();

    return sorted[5];
  }

  // 2. 주간 운동 시간 계산
  // 최근 14일, 최소 유효 기록 10일
  // 단위: 분/주
  // 각 날짜의 운동시간은 중강도 상당량 기준
  static double? weeklyExerciseMinutes(List<int?> last14Days) {
    if (last14Days.length != 14) return null;

    final valid = last14Days
        .whereType<int>()
        .where((value) => value >= 0)
        .toList();

    if (valid.length < 10) return null;

    final total = valid.fold<int>(0, (sum, value) => sum + value);

    return total * 7 / valid.length;
  }

  // 3. 운동 목표 추천
  // 현재 주간 운동량에서 10~15분 증가 제안
  // 기본 제안: 15분 증가
  static int? recommendExercise(List<int?> last14Days, {int increase = 15}) {
    if (increase < 10 || increase > 15) {
      return null;
    }

    final current = weeklyExerciseMinutes(last14Days);

    if (current == null) return null;

    return current.ceil() + increase;
  }

  // 4. 평균 수면 시간 계산
  // 최근 14일, 최소 유효 기록 10일
  // 단위: 분/일
  static double? averageSleepMinutes(List<int?> last14Days) {
    if (last14Days.length != 14) return null;

    final valid = last14Days
        .whereType<int>()
        .where((value) => value >= 0 && value <= 1440)
        .toList();

    if (valid.length < 10) return null;

    final total = valid.fold<int>(0, (sum, value) => sum + value);

    return total / valid.length;
  }

  // 5. 수면 목표 제안
  // 평균 수면시간이 420분(7시간) 미만인 경우
  // 수면 기회를 15~30분 확대하도록 안내
  static String? sleepSuggestion(List<int?> last14Days) {
    final average = averageSleepMinutes(last14Days);

    if (average == null) return null;

    if (average < 420) {
      return '최근 평균 수면시간이 7시간 미만입니다. '
          '수면 기회를 15~30분 늘리는 것을 고려해 보세요.';
    }

    return '현재 수면시간과 취침 및 기상 시간의 '
        '규칙성을 함께 관리해 보세요.';
  }

  // 6. 목표 달성률 계산
  // 실제값 / 목표값 × 100
  static double? achievementRate(num? actual, num? target) {
    if (actual == null ||
        target == null ||
        actual < 0 ||
        target <= 0 ||
        !actual.isFinite ||
        !target.isFinite) {
      return null;
    }

    return actual / target * 100;
  }
}
