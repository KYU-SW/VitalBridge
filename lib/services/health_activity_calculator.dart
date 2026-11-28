import 'package:health/health.dart';

// 날짜별 운동 세션 요약
class DailyWorkoutSummary {
  final DateTime date;
  final String source;
  final int sessionMinutes;

  const DailyWorkoutSummary({
    required this.date,
    required this.source,
    required this.sessionMinutes,
  });
}

// 날짜별 안정 시 심박수 요약
class DailyRestingHeartSummary {
  final DateTime date;
  final String source;
  final double restingHeartRate;

  const DailyRestingHeartSummary({
    required this.date,
    required this.source,
    required this.restingHeartRate,
  });
}

class HealthActivityCalculator {
  // 날짜 키 생성
  static DateTime _day(DateTime date) {
    final local = date.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  // 데이터 출처 구분
  static String _source(HealthDataPoint point) {
    if (point.sourceId.isNotEmpty) {
      return point.sourceId;
    }

    return point.sourceName;
  }

  // 1. 운동 세션 계산
  //
  // 한 날짜에 끝난 운동 세션의 시간 합계
  // 같은 출처에서 겹치는 구간은 한 번만 계산
  //
  // 주의: 운동 세션 시간은
  // 중강도 또는 고강도 운동 시간과 다름
  static List<DailyWorkoutSummary> calculateWorkouts(
    List<HealthDataPoint> records,
  ) {
    final groups = <String, List<HealthDataPoint>>{};

    for (final point in records) {
      if (point.type != HealthDataType.WORKOUT) {
        continue;
      }

      if (!point.dateFrom.isBefore(point.dateTo)) {
        continue;
      }

      final source = _source(point);

      if (source.isEmpty) continue;

      // 운동이 끝난 날짜를 기준으로 묶음
      final date = _day(point.dateTo);

      final key = '${date.toIso8601String()}|$source';

      groups.putIfAbsent(key, () => <HealthDataPoint>[]).add(point);
    }

    final results = <DailyWorkoutSummary>[];

    for (final entry in groups.entries) {
      final points = entry.value
        ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      if (points.isEmpty) continue;

      var start = points.first.dateFrom;
      var end = points.first.dateTo;
      var totalSeconds = 0;

      for (var i = 1; i < points.length; i++) {
        final point = points[i];

        if (!point.dateFrom.isAfter(end)) {
          // 겹치는 운동 구간
          if (point.dateTo.isAfter(end)) {
            end = point.dateTo;
          }
        } else {
          totalSeconds += end.difference(start).inSeconds;

          start = point.dateFrom;
          end = point.dateTo;
        }
      }

      totalSeconds += end.difference(start).inSeconds;

      final minutes = (totalSeconds / 60).round();

      // 24시간 초과 기록은 검토 대상으로 제외
      if (minutes <= 0 || minutes > 1440) {
        continue;
      }

      final first = points.first;

      results.add(
        DailyWorkoutSummary(
          date: _day(first.dateTo),
          source: _source(first),
          sessionMinutes: minutes,
        ),
      );
    }

    results.sort((a, b) => a.date.compareTo(b.date));

    return results;
  }

  // 2. 안정 시 심박수 계산
  //
  // RESTING_HEART_RATE 유형만 사용
  // 일반 HEART_RATE 기록과 혼합하지 않음
  static List<DailyRestingHeartSummary> calculateRestingHeartRate(
    List<HealthDataPoint> records,
  ) {
    final groups = <String, List<HealthDataPoint>>{};

    for (final point in records) {
      if (point.type != HealthDataType.RESTING_HEART_RATE) {
        continue;
      }

      if (point.value is! NumericHealthValue) {
        continue;
      }

      final value = (point.value as NumericHealthValue).numericValue.toDouble();

      if (!value.isFinite || value <= 0) {
        continue;
      }

      final source = _source(point);

      if (source.isEmpty) continue;

      final date = _day(point.dateTo);

      final key = '${date.toIso8601String()}|$source';

      groups.putIfAbsent(key, () => <HealthDataPoint>[]).add(point);
    }

    final results = <DailyRestingHeartSummary>[];

    for (final entry in groups.entries) {
      final points = entry.value;

      if (points.isEmpty) continue;

      final values = points.map((point) {
        return (point.value as NumericHealthValue).numericValue.toDouble();
      }).toList();

      final total = values.fold<double>(0, (sum, value) => sum + value);

      final average = total / values.length;
      final first = points.first;

      results.add(
        DailyRestingHeartSummary(
          date: _day(first.dateTo),
          source: _source(first),
          restingHeartRate: average,
        ),
      );
    }

    results.sort((a, b) => a.date.compareTo(b.date));

    return results;
  }
}
