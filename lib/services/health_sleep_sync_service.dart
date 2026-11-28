import 'daily_health_service.dart';
import 'health_service.dart';
import 'health_sleep_calculator.dart';

// 수면 동기화 결과
class SleepSyncResult {
  final int savedDays;
  final int skippedDays;
  final String message;

  const SleepSyncResult({
    required this.savedDays,
    required this.skippedDays,
    required this.message,
  });
}

class HealthSleepSyncService {
  final HealthService _healthService = HealthService();
  final DailyHealthService _dailyService = DailyHealthService();

  // 완료된 과거 날짜만 동기화
  Future<SleepSyncResult> syncRecentSleep({int days = 7}) async {
    if (days < 1 || days > 30) {
      throw ArgumentError('조회 기간은 1~30일이어야 합니다.');
    }

    // 1. Health Connect 연결
    await _healthService.initialize();

    // 2. 수면 기록 읽기 권한
    final granted = await _healthService.requestSleepPermission();

    if (!granted) {
      throw StateError('수면 기록 읽기 권한이 없습니다.');
    }

    // 3. 조회 기간 설정
    // 오늘은 완료되지 않았으므로 저장 대상에서 제외
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = today.subtract(Duration(days: days));

    // 마지막 완료 날짜의 수면 종료 정보를 포함하도록
    // 오늘 정오까지 조회
    final queryEnd = today.add(const Duration(hours: 12));

    // 4. 실제 수면 단계 기록 조회
    final records = await _healthService.getSleepRecords(
      start: start,
      end: queryEnd,
    );

    if (records.isEmpty) {
      return const SleepSyncResult(
        savedDays: 0,
        skippedDays: 0,
        message: 'Health Connect에 수면 단계 기록이 없습니다.',
      );
    }

    // 5. 수면 계산
    final summaries = HealthSleepCalculator.calculate(records);

    // 6. 날짜별 저장 후보 선택
    final byDate = <DateTime, List<DailySleepSummary>>{};

    for (final summary in summaries) {
      final day = DateTime(
        summary.date.year,
        summary.date.month,
        summary.date.day,
      );

      // 오늘과 미래 날짜 제외
      if (!day.isBefore(today)) continue;

      // 조회 기간보다 이전 날짜 제외
      if (day.isBefore(start)) continue;

      byDate.putIfAbsent(day, () => <DailySleepSummary>[]).add(summary);
    }

    var saved = 0;
    var skipped = 0;

    // 7. 일별 Supabase 저장
    for (final entry in byDate.entries) {
      final candidates = entry.value;

      // 서로 다른 출처가 같은 날짜에 존재하면
      // 어느 쪽을 대표 기록으로 사용할지 검증 전이므로
      // 임의로 합산하거나 선택하지 않음
      if (candidates.length != 1) {
        skipped++;
        continue;
      }

      final summary = candidates.single;

      if (summary.sleepMinutes <= 0 || summary.sleepMinutes > 1440) {
        skipped++;
        continue;
      }

      await _dailyService.saveRecord(
        DailyHealthRecord(
          date: summary.date,
          sleepMinutes: summary.sleepMinutes,
          source: 'health_connect',
          device: null,
        ),
      );

      saved++;
    }

    return SleepSyncResult(
      savedDays: saved,
      skippedDays: skipped,
      message:
          '수면 기록 $saved일 저장 완료, '
          '$skipped일 검토 필요',
    );
  }
}
