import 'package:health/health.dart';

class DailySleepSummary {
  final DateTime date;
  final String source;
  final int sleepMinutes;

  const DailySleepSummary({
    required this.date,
    required this.source,
    required this.sleepMinutes,
  });
}

class HealthSleepCalculator {
  static const Set<HealthDataType> _asleepTypes = {
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  };

  // 임시 제품 규칙: 두 수면 기록 사이의 공백이 2시간을 초과하면
  // 서로 다른 수면 세션으로 취급합니다. 임상적 기준이 아닙니다.
  static const Duration _sessionGap = Duration(hours: 2);

  static List<DailySleepSummary> calculate(List<HealthDataPoint> records) {
    final bySource = <String, List<HealthDataPoint>>{};

    for (final point in records) {
      if (!_asleepTypes.contains(point.type)) continue;
      if (!point.dateFrom.isBefore(point.dateTo)) continue;

      final source = point.sourceId.isNotEmpty
          ? point.sourceId
          : point.sourceName;
      if (source.isEmpty) continue;

      bySource.putIfAbsent(source, () => <HealthDataPoint>[]).add(point);
    }

    final results = <DailySleepSummary>[];

    for (final entry in bySource.entries) {
      final intervals =
          entry.value.map((p) => (start: p.dateFrom, end: p.dateTo)).toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      if (intervals.isEmpty) continue;

      // 날짜별 합계. 서로 다른 수면 세션이 같은 날 끝나면 합산합니다.
      final dailySeconds = <DateTime, int>{};
      var sessionEnd = intervals.first.end;
      var coveredEnd = intervals.first.end;
      var totalSeconds = intervals.first.end
          .difference(intervals.first.start)
          .inSeconds;

      void finishSession() {
        final wakeTime = sessionEnd.toLocal();
        final date = DateTime(wakeTime.year, wakeTime.month, wakeTime.day);
        dailySeconds.update(
          date,
          (old) => old + totalSeconds,
          ifAbsent: () => totalSeconds,
        );
      }

      for (var i = 1; i < intervals.length; i++) {
        final current = intervals[i];
        final gap = current.start.difference(sessionEnd);

        if (gap > _sessionGap) {
          // 지난 세션을 단 한 번만 확정합니다.
          finishSession();
          sessionEnd = current.end;
          coveredEnd = current.end;
          totalSeconds = current.end.difference(current.start).inSeconds;
          continue;
        }

        // 같은 세션: 앞서 계산한 범위와 겹치면 겹친 시간을 제외합니다.
        if (current.start.isAfter(coveredEnd)) {
          totalSeconds += current.end.difference(current.start).inSeconds;
        } else if (current.end.isAfter(coveredEnd)) {
          totalSeconds += current.end.difference(coveredEnd).inSeconds;
        }

        if (current.end.isAfter(coveredEnd)) {
          coveredEnd = current.end;
        }
        if (current.end.isAfter(sessionEnd)) {
          sessionEnd = current.end;
        }
      }

      finishSession();

      for (final day in dailySeconds.entries) {
        final minutes = (day.value / 60).round();
        if (minutes <= 0 || minutes > 1440) continue;

        results.add(
          DailySleepSummary(
            date: day.key,
            source: entry.key,
            sleepMinutes: minutes,
          ),
        );
      }
    }

    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }
}
