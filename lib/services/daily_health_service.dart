import 'package:supabase_flutter/supabase_flutter.dart';

// 하루 생활패턴 기록
class DailyHealthRecord {
  final DateTime date;
  final int? steps;
  final int? sleepMinutes;
  final int? moderateMinutes;
  final int? vigorousMinutes;
  final double? restingHeartRate;
  final double? spo2;
  final String source;
  final String? device;
  final bool valid;

  const DailyHealthRecord({
    required this.date,
    this.steps,
    this.sleepMinutes,
    this.moderateMinutes,
    this.vigorousMinutes,
    this.restingHeartRate,
    this.spo2,
    this.source = 'health_connect',
    this.device,
    this.valid = true,
  });

  // Supabase 조회 결과를 Dart 객체로 변환
  factory DailyHealthRecord.fromJson(Map<String, dynamic> json) {
    return DailyHealthRecord(
      date: DateTime.parse(json['record_date'] as String),
      steps: (json['steps_daily'] as num?)?.toInt(),
      sleepMinutes: (json['sleep_minutes'] as num?)?.toInt(),
      moderateMinutes: (json['moderate_min'] as num?)?.toInt(),
      vigorousMinutes: (json['vigorous_min'] as num?)?.toInt(),
      restingHeartRate: (json['rest_hr'] as num?)?.toDouble(),
      spo2: (json['spo2'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'health_connect',
      device: json['device'] as String?,
      valid: json['valid'] as bool? ?? true,
    );
  }
}

class DailyHealthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    return user.id;
  }

  // 날짜를 YYYY-MM-DD 형태로 변환
  String _dateText(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // 1. 하루 건강 데이터 저장
  // 동일 날짜와 출처에 기존 값이 있으면 수정
  Future<void> saveRecord(DailyHealthRecord record) async {
    final userId = _userId;

    if (record.source.trim().isEmpty) {
      throw ArgumentError('데이터 출처가 필요합니다.');
    }

    if (record.steps != null && record.steps! < 0) {
      throw ArgumentError('걸음 수는 0 이상이어야 합니다.');
    }

    for (final minutes in [
      record.sleepMinutes,
      record.moderateMinutes,
      record.vigorousMinutes,
    ]) {
      if (minutes != null && (minutes < 0 || minutes > 1440)) {
        throw ArgumentError('시간 데이터는 0~1440분이어야 합니다.');
      }
    }

    if (record.restingHeartRate != null &&
        (!record.restingHeartRate!.isFinite || record.restingHeartRate! <= 0)) {
      throw ArgumentError('심박수 값이 올바르지 않습니다.');
    }

    if (record.spo2 != null &&
        (!record.spo2!.isFinite || record.spo2! < 0 || record.spo2! > 100)) {
      throw ArgumentError('산소포화도 값이 올바르지 않습니다.');
    }

    final date = _dateText(record.date);

    // 기존 데이터가 있는지 확인
    final existing = await _supabase
        .from('daily_health_metrics')
        .select('id')
        .eq('user_id', userId)
        .eq('record_date', date)
        .eq('source', record.source)
        .maybeSingle();

    // null 값은 측정 데이터가 없다는 뜻이므로
    // 기존 유효 측정값을 덮어쓰지 않음
    final values = <String, dynamic>{
      if (record.steps != null) 'steps_daily': record.steps,
      if (record.sleepMinutes != null) 'sleep_minutes': record.sleepMinutes,
      if (record.moderateMinutes != null)
        'moderate_min': record.moderateMinutes,
      if (record.vigorousMinutes != null)
        'vigorous_min': record.vigorousMinutes,
      if (record.restingHeartRate != null) 'rest_hr': record.restingHeartRate,
      if (record.spo2 != null) 'spo2': record.spo2,
      if (record.device != null) 'device': record.device,
      'valid': record.valid,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      await _supabase.from('daily_health_metrics').insert({
        ...values,
        'user_id': userId,
        'record_date': date,
        'source': record.source,
      });
    } else {
      await _supabase
          .from('daily_health_metrics')
          .update(values)
          .eq('id', existing['id'])
          .eq('user_id', userId);
    }
  }

  // 2. 기간별 건강 데이터 불러오기
  Future<List<DailyHealthRecord>> loadRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    if (start.isAfter(end)) {
      throw ArgumentError('시작 날짜는 종료 날짜보다 늦을 수 없습니다.');
    }

    final result = await _supabase
        .from('daily_health_metrics')
        .select()
        .eq('user_id', _userId)
        .gte('record_date', _dateText(start))
        .lte('record_date', _dateText(end))
        .order('record_date', ascending: true);

    return result.map((json) => DailyHealthRecord.fromJson(json)).toList();
  }

  // 3. 오늘 기록 불러오기
  Future<List<DailyHealthRecord>> loadToday() {
    final today = DateTime.now();

    return loadRecords(start: today, end: today);
  }
}
