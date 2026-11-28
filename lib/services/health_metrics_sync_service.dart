import 'daily_health_service.dart';
import 'health_activity_calculator.dart';
import 'health_service.dart';
import 'health_sleep_sync_service.dart';

// 각 건강 데이터의 처리 결과
class HealthMetricsSyncResult {
  final int savedSleepDays;
  final int skippedSleepDays;
  final int savedHeartDays;
  final int skippedHeartDays;
  final int workoutDays;
  final List<String> messages;

  const HealthMetricsSyncResult({
    required this.savedSleepDays,
    required this.skippedSleepDays,
    required this.savedHeartDays,
    required this.skippedHeartDays,
    required this.workoutDays,
    required this.messages,
  });

  bool get hasErrors => messages.any((message) => message.contains('실패'));
}

class HealthMetricsSyncService {
  final HealthService _healthService = HealthService();
  final HealthSleepSyncService _sleepService = HealthSleepSyncService();
  final DailyHealthService _dailyService = DailyHealthService();

  // 완료된 과거 날짜를 조회
  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  // 1. 안정 시 심박수 동기화
  Future<({int saved, int skipped})> _syncRestingHeart({
    required int days,
  }) async {
    final granted = await _healthService.requestRestingHeartPermission();

    if (!granted) {
      throw StateError('안정 시 심박수 읽기 권한이 없습니다.');
    }

    final today = _today();
    final start = today.subtract(Duration(days: days));

    final records = await _healthService.getRestingHeartRecords(
      start: start,
      end: today,
    );

    final summaries = HealthActivityCalculator.calculateRestingHeartRate(
      records,
    );

    // 같은 날짜에 출처가 여러 개 있으면
    // 임의로 평균을 합산하거나 대표값을 선택하지 않음
    final byDate = <DateTime, List<DailyRestingHeartSummary>>{};

    for (final summary in summaries) {
      final day = _dateOnly(summary.date);

      if (day.isBefore(start) || !day.isBefore(today)) {
        continue;
      }

      byDate.putIfAbsent(day, () => <DailyRestingHeartSummary>[]).add(summary);
    }

    var saved = 0;
    var skipped = 0;

    for (final entry in byDate.entries) {
      final candidates = entry.value;

      if (candidates.length != 1) {
        skipped++;
        continue;
      }

      final summary = candidates.single;

      if (!summary.restingHeartRate.isFinite || summary.restingHeartRate <= 0) {
        skipped++;
        continue;
      }

      await _dailyService.saveRecord(
        DailyHealthRecord(
          date: entry.key,
          restingHeartRate: summary.restingHeartRate,
          source: 'health_connect',
        ),
      );

      saved++;
    }

    return (saved: saved, skipped: skipped);
  }

  // 2. 운동 세션 조회 및 계산
  // 아직 중강도·고강도 운동량으로 저장하지 않음
  Future<int> _reviewWorkouts({required int days}) async {
    final granted = await _healthService.requestWorkoutPermission();

    if (!granted) {
      throw StateError('운동 기록 읽기 권한이 없습니다.');
    }

    final today = _today();
    final start = today.subtract(Duration(days: days));

    final records = await _healthService.getWorkoutRecords(
      start: start,
      end: today,
    );

    final summaries = HealthActivityCalculator.calculateWorkouts(records);

    // 실제 운동 기록이 확인된 날짜 수
    final recordedDates = <DateTime>{};

    for (final summary in summaries) {
      final day = _dateOnly(summary.date);

      if (!day.isBefore(start) && day.isBefore(today)) {
        recordedDates.add(day);
      }
    }

    return recordedDates.length;
  }

  // 3. 통합 실행
  //
  // 주의:
  // 수면 계산은 아직 실제 기기 검증 전.
  // 사용자가 명시적으로 실행할 때만 호출하도록 설계.
  Future<HealthMetricsSyncResult> syncRecent({int days = 7}) async {
    if (days < 1 || days > 30) {
      throw ArgumentError('조회 기간은 1~30일이어야 합니다.');
    }

    await _healthService.initialize();

    var savedSleep = 0;
    var skippedSleep = 0;
    var savedHeart = 0;
    var skippedHeart = 0;
    var workoutDays = 0;

    final messages = <String>[];

    // 수면
    try {
      final result = await _sleepService.syncRecentSleep(days: days);

      savedSleep = result.savedDays;
      skippedSleep = result.skippedDays;

      messages.add(
        '수면: $savedSleep일 저장, '
        '$skippedSleep일 건너뜀',
      );
    } catch (e) {
      messages.add('수면 동기화 실패: $e');
    }

    // 안정 시 심박수
    try {
      final result = await _syncRestingHeart(days: days);

      savedHeart = result.saved;
      skippedHeart = result.skipped;

      messages.add(
        '안정 시 심박수: $savedHeart일 저장, '
        '$skippedHeart일 건너뜀',
      );
    } catch (e) {
      messages.add('심박수 동기화 실패: $e');
    }

    // 운동
    try {
      workoutDays = await _reviewWorkouts(days: days);

      messages.add(
        '운동 세션: $workoutDays일 기록 확인 '
        '(DB 저장 보류)',
      );
    } catch (e) {
      messages.add('운동 기록 조회 실패: $e');
    }

    return HealthMetricsSyncResult(
      savedSleepDays: savedSleep,
      skippedSleepDays: skippedSleep,
      savedHeartDays: savedHeart,
      skippedHeartDays: skippedHeart,
      workoutDays: workoutDays,
      messages: messages,
    );
  }
}
