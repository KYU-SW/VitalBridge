import 'daily_health_service.dart';

class LifestyleHistoryService {
  final DailyHealthService _dailyService = DailyHealthService();

  // 날짜별 기록 불러오기
  Future<List<DailyHealthRecord>> loadHistory({
    required int days,
    bool includeToday = false,
  }) async {
    if (days <= 0) {
      throw ArgumentError('조회 기간은 1일 이상이어야 합니다.');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final end = includeToday ? today : today.subtract(const Duration(days: 1));

    final start = end.subtract(Duration(days: days - 1));

    return _dailyService.loadRecords(start: start, end: end);
  }

  // 유효한 기록의 평균값
  // 데이터가 부족하면 null
  static double? average(List<num?> values, {required int minimumValidDays}) {
    final valid = values
        .whereType<num>()
        .where((value) => value.isFinite && value >= 0)
        .toList();

    if (valid.length < minimumValidDays) return null;

    final total = valid.fold<double>(0, (sum, value) => sum + value.toDouble());

    return total / valid.length;
  }

  // 주간 또는 월간 분석에 필요한 최소 유효일
  static int minimumValidDays(int days) {
    switch (days) {
      case 7:
        return 5;
      case 14:
        return 10;
      case 30:
        return 21;
      default:
        throw ArgumentError('지원하지 않는 분석 기간입니다.');
    }
  }

  // 최근 평균과 이전 평균 비교
  static double? changePercent({
    required double? recent,
    required double? previous,
  }) {
    if (recent == null ||
        previous == null ||
        !recent.isFinite ||
        !previous.isFinite ||
        previous <= 0) {
      return null;
    }

    return (recent - previous) / previous * 100;
  }

  // 연구 명세서의 제품용 변화 판단 기준
  // 질병 위험이나 의학적 악화 판정이 아님
  static String stepsTrend(double? changePercent) {
    if (changePercent == null) {
      return '비교할 기록이 부족합니다.';
    }

    if (changePercent >= 15) {
      return '걸음 수 증가 추세가 관찰됩니다.';
    }

    if (changePercent <= -15) {
      return '걸음 수 감소 추세가 관찰됩니다.';
    }

    return '걸음 수에 큰 변화가 관찰되지 않았습니다.';
  }
}
