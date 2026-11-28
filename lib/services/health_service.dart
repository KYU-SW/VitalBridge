import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();

  // 걸음 수
  static const List<HealthDataType> _stepTypes = [HealthDataType.STEPS];

  // 수면 단계
  // 단순 '침대에 누워 있던 시간'과 실제 수면을 구분
  static const List<HealthDataType> _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  // 운동 세션
  static const List<HealthDataType> _workoutTypes = [HealthDataType.WORKOUT];

  // 안정 시 심박수
  static const List<HealthDataType> _restingHeartTypes = [
    HealthDataType.RESTING_HEART_RATE,
  ];

  // 1. Health Connect 초기화
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Health Connect는 Android 기기에서만 '
        '사용할 수 있습니다.',
      );
    }

    await _health.configure();

    final available = await _health.isHealthConnectAvailable();

    if (!available) {
      throw StateError(
        'Health Connect를 사용할 수 없습니다. '
        '설치 및 업데이트 상태를 확인해 주세요.',
      );
    }
  }

  // 2. 내부 공통 권한 요청
  Future<bool> _requestReadPermissions(List<HealthDataType> types) async {
    return _health.requestAuthorization(
      types,
      permissions: List.filled(types.length, HealthDataAccess.READ),
    );
  }

  // 3. 기존 걸음 수 권한 요청
  Future<bool> requestStepsPermission() async {
    return _requestReadPermissions(_stepTypes);
  }

  // 4. 수면 기록 권한 요청
  Future<bool> requestSleepPermission() async {
    return _requestReadPermissions(_sleepTypes);
  }

  // 5. 운동 기록 권한 요청
  Future<bool> requestWorkoutPermission() async {
    return _requestReadPermissions(_workoutTypes);
  }

  // 6. 안정 시 심박수 권한 요청
  Future<bool> requestRestingHeartPermission() async {
    return _requestReadPermissions(_restingHeartTypes);
  }

  // 7. 추가 건강 데이터 권한 요청
  // 각 권한은 개별 확인 가능하도록 유지
  Future<Map<String, bool>> requestExtendedPermissions() async {
    final results = <String, bool>{};

    try {
      results['sleep'] = await requestSleepPermission();
    } catch (_) {
      results['sleep'] = false;
    }

    try {
      results['workout'] = await requestWorkoutPermission();
    } catch (_) {
      results['workout'] = false;
    }

    try {
      results['restingHeart'] = await requestRestingHeartPermission();
    } catch (_) {
      results['restingHeart'] = false;
    }

    return results;
  }

  // 8. 공통 날짜 구간 검사
  void _validateInterval(DateTime start, DateTime end) {
    if (!start.isBefore(end)) {
      throw ArgumentError('시작 시간은 종료 시간보다 빨라야 합니다.');
    }
  }

  // 9. 공통 건강 데이터 읽기
  Future<List<HealthDataPoint>> _readRecords({
    required List<HealthDataType> types,
    required DateTime start,
    required DateTime end,
  }) async {
    _validateInterval(start, end);

    final allowed = await _health.hasPermissions(
      types,
      permissions: List.filled(types.length, HealthDataAccess.READ),
    );

    if (allowed != true) {
      throw StateError('요청한 건강 데이터의 읽기 권한이 없습니다.');
    }

    final records = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: end,
    );

    return _health.removeDuplicates(records);
  }

  // 10. 원하는 기간의 걸음 수
  Future<int> getStepsInInterval(DateTime start, DateTime end) async {
    _validateInterval(start, end);

    final allowed = await _health.hasPermissions(
      _stepTypes,
      permissions: const [HealthDataAccess.READ],
    );

    if (allowed != true) {
      throw StateError('걸음 수 읽기 권한이 없습니다.');
    }

    return _health.getTotalStepsInInterval(
      start,
      end,
      includeManualEntry: false,
    );
  }

  // 11. 기존 오늘의 걸음 수
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    return getStepsInInterval(start, now);
  }

  // 12. 수면 기록 원본 조회
  // 실제 수면 단계를 합산하는 작업은 별도 처리
  Future<List<HealthDataPoint>> getSleepRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    return _readRecords(types: _sleepTypes, start: start, end: end);
  }

  // 13. 운동 세션 원본 조회
  // 운동 세션 시간 = 중강도 운동시간이 아님
  Future<List<HealthDataPoint>> getWorkoutRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    return _readRecords(types: _workoutTypes, start: start, end: end);
  }

  // 14. 안정 시 심박수 원본 조회
  // 일반 심박수와 혼동하지 않도록 구분
  Future<List<HealthDataPoint>> getRestingHeartRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    return _readRecords(types: _restingHeartTypes, start: start, end: end);
  }
}
