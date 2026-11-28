import 'package:flutter/material.dart';

import '../services/daily_health_service.dart';
import '../services/goal_rules.dart';
import '../services/health_service.dart';
import '../services/lifestyle_goal_service.dart';
import '../services/lifestyle_history_service.dart';
import '../services/lifestyle_recommendation_service.dart';

enum PatternMetric { steps, sleep, exercise, heart }

class _GoalDraft {
  final int steps;
  final double sleepHours;
  final int exerciseWeekly;

  const _GoalDraft(this.steps, this.sleepHours, this.exerciseWeekly);
}

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  final HealthService _healthService = HealthService();
  final LifestyleGoalService _goalService = LifestyleGoalService();
  final DailyHealthService _dailyService = DailyHealthService();
  final LifestyleHistoryService _historyService = LifestyleHistoryService();
  final LifestyleRecommendationService _recommendationService =
      LifestyleRecommendationService();

  bool _connected = false;
  bool _loadingHealth = false;
  bool _checkingPermissions = false;
  String? _permissionMessage;
  bool _loadingGoals = true;
  bool _savingGoals = false;
  bool _loadingHistory = true;
  bool _loadingRecommendation = true;
  LifestyleRecommendation? _recommendation;
  String? _recommendationError;
  int? _steps;
  int? _goalSteps;
  int? _goalSleepMinutes;
  int? _goalExercise;
  String? _healthError;
  String? _syncMessage;
  String? _syncError;
  String? _goalError;
  String? _historyError;

  bool _monthly = false;
  PatternMetric _metric = PatternMetric.steps;
  List<DailyHealthRecord> _records = [];
  List<DailyHealthRecord> _todayRecords = [];
  bool _loadingRecent = true;
  String? _recentError;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadHistory();
    _loadTodayRecords();
    _loadRecommendation();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _loadingGoals = true;
      _goalError = null;
    });
    try {
      final goals = await _goalService.loadGoals();
      if (!mounted) return;
      setState(() {
        _goalSteps = goals?.steps;
        _goalSleepMinutes = goals?.sleepMinutes;
        _goalExercise = goals?.exerciseWeekly;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _goalError = '목표 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _loadingGoals = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      // 오늘은 진행 중인 하루이므로 그래프와 기간 평균에서 제외.
      final records = await _historyService.loadHistory(days: 30);
      if (!mounted) return;
      setState(() => _records = records);
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = '과거 기록 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // 오늘 저장된 기록만 별도 조회합니다. 주간/월간 그래프는 완료된 날짜만 사용.
  Future<void> _loadTodayRecords() async {
    if (!mounted) return;
    setState(() {
      _loadingRecent = true;
      _recentError = null;
    });
    try {
      final today = _today;
      final records = await _dailyService.loadRecords(start: today, end: today);
      if (!mounted) return;
      setState(() => _todayRecords = records);
    } catch (error) {
      if (!mounted) return;
      setState(() => _recentError = '오늘 저장 기록 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _refreshStoredRecords() async {
    await _loadHistory();
    if (!mounted) return;
    await _loadTodayRecords();
  }

  Future<void> _loadRecommendation() async {
    if (!mounted) return;
    setState(() {
      _loadingRecommendation = true;
      _recommendationError = null;
    });
    try {
      // 운동 강도 및 미측정일의 의미가 검증되지 않았으므로
      // 운동 자동 추천은 기본적으로 비활성화합니다.
      final result = await _recommendationService.calculateRecommendations();
      if (!mounted) return;
      setState(() => _recommendation = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _recommendationError = '추천 목표 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _loadingRecommendation = false);
    }
  }

  // 오늘 걸음 수를 읽은 경우에만 Supabase에 저장합니다.
  // 조회값이 0이면 미측정과 실제 0보를 구분할 수 없어 저장을 보류합니다.
  // 다른 건강 지표의 null 값은 기존 DB 값을 지우지 않습니다.
  Future<void> connectHealth() async {
    if (_loadingHealth) return;
    setState(() {
      _loadingHealth = true;
      _healthError = null;
      _syncError = null;
      _syncMessage = null;
    });

    try {
      await _healthService.initialize();
      final granted = await _healthService.requestStepsPermission();
      if (!granted) {
        throw StateError('걸음 수 읽기 권한이 허용되지 않았습니다.');
      }
      final steps = await _healthService.getTodaySteps();
      if (!mounted) return;

      setState(() {
        _connected = true;
        _steps = steps;
      });

      if (steps <= 0) {
        setState(() {
          _syncMessage =
              '오늘 조회된 걸음 수가 0보라 저장을 보류했습니다. '
              '미측정과 실제 0보는 추후 기기에서 확인합니다.';
        });
        return;
      }

      try {
        await _dailyService.saveRecord(
          DailyHealthRecord(
            date: DateTime.now(),
            steps: steps,
            source: 'health_connect',
          ),
        );
        if (!mounted) return;
        setState(() {
          _syncMessage = '오늘 걸음 수 $steps보를 Supabase에 저장했습니다.';
        });
        // 현재 그래프는 오늘을 제외하므로 오늘 기록은 그래프에 나타나지 않습니다.
        await _refreshStoredRecords();
        await _loadRecommendation();
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _syncError = '걸음 수는 읽었지만 Supabase 저장에 실패했습니다: $error';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _healthError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingHealth = false);
    }
  }

  // 항목별 Health Connect 권한 확인 (데이터 저장 없음).
  Future<void> _checkAdditionalPermissions() async {
    if (_checkingPermissions || _loadingHealth) return;
    setState(() {
      _checkingPermissions = true;
      _permissionMessage = null;
    });
    try {
      await _healthService.initialize();
      final permissions = await _healthService.requestExtendedPermissions();
      if (!mounted) return;
      String state(String key) => permissions[key] == true ? '허용' : '미허용/미지원';
      setState(() {
        _permissionMessage =
            '수면: ${state('sleep')} · '
            '운동: ${state('workout')} · '
            '안정 시 심박수: ${state('restingHeart')}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _permissionMessage = '권한 확인 실패: $error');
    } finally {
      if (mounted) setState(() => _checkingPermissions = false);
    }
  }

  Future<void> _editGoals({int? suggestedSteps, int? suggestedExercise}) async {
    if (_loadingGoals || _savingGoals) return;
    final formKey = GlobalKey<FormState>();
    int steps = suggestedSteps ?? _goalSteps ?? 8000;
    double sleepHours = (_goalSleepMinutes ?? 450) / 60.0;
    int exercise = suggestedExercise ?? _goalExercise ?? 150;

    final draft = await showDialog<_GoalDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('생활패턴 목표 설정'),
        content: SizedBox(
          width: 350,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: '$steps',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '하루 걸음 수',
                      suffixText: '보',
                      border: OutlineInputBorder(),
                    ),
                    validator: (text) {
                      final value = int.tryParse(text?.trim() ?? '');
                      return value == null || value < 1 || value > 100000
                          ? '1~100000 사이의 정수를 입력하세요.'
                          : null;
                    },
                    onSaved: (text) => steps = int.parse(text!.trim()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '$sleepHours',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '하루 수면 목표',
                      suffixText: '시간',
                      border: OutlineInputBorder(),
                    ),
                    validator: (text) {
                      final value = double.tryParse(text?.trim() ?? '');
                      return value == null ||
                              !value.isFinite ||
                              value < 0.5 ||
                              value > 24
                          ? '0.5~24시간 사이로 입력하세요.'
                          : null;
                    },
                    onSaved: (text) => sleepHours = double.parse(text!.trim()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '$exercise',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '주간 운동 목표',
                      suffixText: '분',
                      border: OutlineInputBorder(),
                    ),
                    validator: (text) {
                      final value = int.tryParse(text?.trim() ?? '');
                      return value == null || value < 1 || value > 10080
                          ? '1~10080 사이의 정수를 입력하세요.'
                          : null;
                    },
                    onSaved: (text) => exercise = int.parse(text!.trim()),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(
                dialogContext,
                _GoalDraft(steps, sleepHours, exercise),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted || draft == null) return;
    setState(() {
      _savingGoals = true;
      _goalError = null;
    });
    try {
      final sleepMinutes = (draft.sleepHours * 60).round();
      await _goalService.saveGoals(
        steps: draft.steps,
        sleepMinutes: sleepMinutes,
        exerciseWeekly: draft.exerciseWeekly,
      );
      if (!mounted) return;
      setState(() {
        _goalSteps = draft.steps;
        _goalSleepMinutes = sleepMinutes;
        _goalExercise = draft.exerciseWeekly;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('목표가 Supabase에 저장되었습니다.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _goalError = '목표 저장 실패: $error');
    } finally {
      if (mounted) setState(() => _savingGoals = false);
    }
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // 한 날짜에 출처별 기록이 여러 개 있으면 중복 합산하지 않음.
  // Health Connect를 우선하고, 해당 항목이 null이면 다른 출처를 확인.
  // 출처별 기기 중복 제거는 향후 동기화 단계에서 추가 검증이 필요함.
  double? _metricValue(DailyHealthRecord record, PatternMetric metric) {
    if (!record.valid) return null;
    switch (metric) {
      case PatternMetric.steps:
        return record.steps?.toDouble();
      case PatternMetric.sleep:
        return record.sleepMinutes == null ? null : record.sleepMinutes! / 60.0;
      case PatternMetric.exercise:
        final moderate = record.moderateMinutes;
        final vigorous = record.vigorousMinutes;
        if (moderate == null && vigorous == null) return null;
        // 두 강도 모두 존재해야 정확한 중강도 상당량을 계산할 수 있음.
        if (moderate == null || vigorous == null) return null;
        return (moderate + 2 * vigorous).toDouble();
      case PatternMetric.heart:
        return record.restingHeartRate;
    }
  }

  List<double?> _dailyValues(int days) {
    final end = _today.subtract(const Duration(days: 1));
    final start = end.subtract(Duration(days: days - 1));
    final byDate = <String, List<DailyHealthRecord>>{};
    for (final record in _records) {
      byDate.putIfAbsent(_dateKey(record.date), () => []).add(record);
    }
    return List<double?>.generate(days, (index) {
      final day = start.add(Duration(days: index));
      final candidates = [...?byDate[_dateKey(day)]];
      candidates.sort((a, b) {
        final aPriority = a.source == 'health_connect' ? 0 : 1;
        final bPriority = b.source == 'health_connect' ? 0 : 1;
        return aPriority.compareTo(bPriority);
      });
      for (final record in candidates) {
        final value = _metricValue(record, _metric);
        if (value != null && value.isFinite && value >= 0) return value;
      }
      return null;
    });
  }

  String get _metricName {
    switch (_metric) {
      case PatternMetric.steps:
        return '걸음 수';
      case PatternMetric.sleep:
        return '수면 시간';
      case PatternMetric.exercise:
        return '운동 시간';
      case PatternMetric.heart:
        return '안정 시 심박수';
    }
  }

  String get _metricUnit {
    switch (_metric) {
      case PatternMetric.steps:
        return '보/일';
      case PatternMetric.sleep:
        return '시간/일';
      case PatternMetric.exercise:
        return '분/일';
      case PatternMetric.heart:
        return 'bpm';
    }
  }

  String _displayNumber(double value) =>
      _metric == PatternMetric.sleep || _metric == PatternMetric.heart
      ? value.toStringAsFixed(1)
      : value.toStringAsFixed(0);

  Widget _sectionTitle(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      ?trailing,
    ],
  );

  // 달성률에는 출처 중복이 없는 유효한 날짜별 측정값만 사용.
  // 여러 출처가 값을 제공하면 신뢰할 대표 기록을 정하기 전까지 계산 보류.
  double? _singleSourceMetric(DateTime date, PatternMetric metric) {
    final candidates = _records
        .where(
          (record) =>
              _dateKey(record.date) == _dateKey(date) &&
              _metricValue(record, metric) != null,
        )
        .toList();
    if (candidates.length != 1) return null;
    final result = _metricValue(candidates.single, metric);
    return result != null && result.isFinite && result >= 0 ? result : null;
  }

  // 최근 완료된 7일의 운동량을 주당 분으로 환산.
  // 누락이 실제 운동 0분과 구분되며 강도 정보가 모두 있는 날만 유효.
  double? _weeklyExerciseEquivalent() {
    final today = _today;
    final values = <double>[];
    for (var daysAgo = 7; daysAgo >= 1; daysAgo--) {
      final date = today.subtract(Duration(days: daysAgo));
      final value = _singleSourceMetric(date, PatternMetric.exercise);
      if (value != null) values.add(value);
    }
    if (values.length < 5) return null;
    final sum = values.fold<double>(0, (total, value) => total + value);
    return 7 * sum / values.length;
  }

  Widget _connectionSection() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '건강 데이터 연결',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Health Connect에 저장된 건강 기록을 불러옵니다.'),
          const SizedBox(height: 12),
          Chip(label: Text(_connected ? '걸음 수 연결됨' : '연결 전')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingHealth ? null : connectHealth,
              icon: const Icon(Icons.link),
              label: Text(
                _loadingHealth
                    ? '연결 중...'
                    : _connected
                    ? '건강 데이터 새로고침'
                    : '건강 데이터 연결하기',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_checkingPermissions || _loadingHealth)
                  ? null
                  : _checkAdditionalPermissions,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                _checkingPermissions ? '권한 확인 중...' : '수면·운동·심박수 권한 확인',
              ),
            ),
          ),
          if (_permissionMessage != null) ...[
            const SizedBox(height: 8),
            Text(_permissionMessage!, style: const TextStyle(fontSize: 12)),
          ],
          if (_healthError != null) ...[
            const SizedBox(height: 12),
            Text(
              _healthError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_syncMessage != null) ...[
            const SizedBox(height: 12),
            Text(_syncMessage!, style: const TextStyle(color: Colors.green)),
          ],
          if (_syncError != null) ...[
            const SizedBox(height: 12),
            Text(
              _syncError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );

  // 같은 날짜에 한 지표를 제공하는 출처가 2개 이상이면 대표값 판단 보류.
  // 화면은 오늘 저장된 자료 우선, 없으면 최근 완료일 자료를 표시.
  ({double value, DailyHealthRecord record})? _latestSaved(
    PatternMetric metric,
  ) {
    final candidates = [..._todayRecords, ..._records].where((record) {
      final value = _metricValue(record, metric);
      return value != null && value.isFinite && value >= 0;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (candidates.isEmpty) return null;
    final newestDate = _dateKey(candidates.first.date);
    final sameDay = candidates
        .where((r) => _dateKey(r.date) == newestDate)
        .toList();
    if (sameDay.length != 1) return null;
    final selected = sameDay.single;
    return (value: _metricValue(selected, metric)!, record: selected);
  }

  Widget _savedMetricCard({
    required PatternMetric metric,
    required String title,
    required IconData icon,
  }) {
    final result = _latestSaved(metric);
    final isDemo =
        result?.record.source == 'vitalbridge_test' ||
        result?.record.device == 'DEMO_DATA';
    final value = result?.value;
    final valueText = value == null
        ? '--'
        : metric == PatternMetric.sleep || metric == PatternMetric.heart
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    final unit = switch (metric) {
      PatternMetric.steps => '보',
      PatternMetric.sleep => '시간',
      PatternMetric.exercise => '분 (중강도 상당)',
      PatternMetric.heart => 'bpm',
    };
    final detail = result == null
        ? '저장 기록 없음 / 중복 출처 확인 필요'
        : '${_dateKey(result.record.date)} · ${isDemo ? '테스트 데이터' : '저장 기록'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              valueText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDemo ? Colors.deepOrange : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todaySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle(
        '최근 생활패턴 기록',
        trailing: IconButton(
          tooltip: '저장된 기록 새로고침',
          onPressed: _loadingRecent || _loadingHistory
              ? null
              : _refreshStoredRecords,
          icon: const Icon(Icons.refresh),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Supabase에 저장된 가장 최근 기록을 표시합니다. '
        '오늘 기록이 없으면 이전 날짜를 보여주며, 날짜와 테스트 여부를 함께 표시합니다. '
        'Health Connect의 실시간 측정값과는 다를 수 있습니다.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      if (_loadingRecent || _loadingHistory)
        const Padding(
          padding: EdgeInsets.all(10),
          child: LinearProgressIndicator(),
        ),
      if (_recentError != null)
        Text(
          _recentError!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _savedMetricCard(
              metric: PatternMetric.steps,
              title: '걸음 수',
              icon: Icons.directions_walk,
            ),
          ),
          Expanded(
            child: _savedMetricCard(
              metric: PatternMetric.heart,
              title: '안정 시 심박수',
              icon: Icons.favorite,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: _savedMetricCard(
              metric: PatternMetric.sleep,
              title: '수면 시간',
              icon: Icons.bedtime,
            ),
          ),
          Expanded(
            child: _savedMetricCard(
              metric: PatternMetric.exercise,
              title: '운동 시간',
              icon: Icons.fitness_center,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _metricChoice(String title, PatternMetric metric) => ChoiceChip(
    label: Text(title),
    selected: _metric == metric,
    onSelected: (_) => setState(() => _metric = metric),
  );

  Widget _graphSection() {
    final days = _monthly ? 30 : 7;
    final values = _dailyValues(days);
    final valid = values.whereType<double>().toList();
    final minimumDays = LifestyleHistoryService.minimumValidDays(days);
    final enough = valid.length >= minimumDays;
    final average = enough
        ? LifestyleHistoryService.average(values, minimumValidDays: minimumDays)
        : null;
    final maximum = valid.isEmpty ? 0.0 : valid.reduce((a, b) => a > b ? a : b);
    final end = _today.subtract(const Duration(days: 1));
    final start = end.subtract(Duration(days: days - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          '생활패턴 변화 그래프',
          trailing: IconButton(
            tooltip: '과거 기록 다시 불러오기',
            onPressed: _loadingHistory ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('주간')),
            ButtonSegment(value: true, label: Text('월간')),
          ],
          selected: {_monthly},
          onSelectionChanged: (selection) =>
              setState(() => _monthly = selection.first),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _metricChoice('걸음 수', PatternMetric.steps),
            _metricChoice('수면', PatternMetric.sleep),
            _metricChoice('운동', PatternMetric.exercise),
            _metricChoice('심박수', PatternMetric.heart),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_metricName · 최근 $days일 (오늘 제외)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateKey(start)} ~ ${_dateKey(end)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_records.any((r) => r.source == 'vitalbridge_test'))
                  const Text(
                    '테스트 데이터 포함 · 실제 측정값이 아닐 수 있습니다.',
                    style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                  ),
                const SizedBox(height: 12),
                if (_loadingHistory)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_historyError != null) ...[
                  Text(
                    _historyError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: _loadHistory,
                    child: const Text('다시 시도'),
                  ),
                ] else ...[
                  if (valid.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('저장된 실제 기록이 없습니다.')),
                    )
                  else ...[
                    const Text(
                      '빈 칸은 측정 기록이 없는 날짜입니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 190,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(days, (index) {
                          final value = values[index];
                          final ratio = value == null || maximum <= 0
                              ? 0.0
                              : (value / maximum).clamp(0.0, 1.0);
                          final date = start.add(Duration(days: index));
                          final showLabel =
                              !_monthly || index % 5 == 0 || index == 29;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _monthly ? 1 : 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: value == null
                                          ? const SizedBox.shrink()
                                          : FractionallySizedBox(
                                              heightFactor: ratio,
                                              widthFactor: _monthly
                                                  ? 1.0
                                                  : 0.65,
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 16,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        showLabel ? '${date.day}' : '',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '유효 기록: ${valid.length}/$days일 · 평균 계산 최소 $minimumDays일',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    average == null
                        ? '기간 평균: 유효 기록 부족'
                        : '기간 평균: ${_displayNumber(average)} $_metricUnit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (valid.isNotEmpty)
                    Text('최고 측정값: ${_displayNumber(maximum)} $_metricUnit'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalProgress({
    required String title,
    required String target,
    required String currentText,
    required IconData icon,
    double? achievement,
  }) {
    final progress = ((achievement ?? 0) / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(target, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(currentText, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            achievement == null
                ? '달성률을 계산할 측정 기록이 없습니다.'
                : '달성률 ${achievement.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _goalSection() {
    final hasTestRecords =
        _records.any((r) => r.source == 'vitalbridge_test') ||
        _todayRecords.any((r) => r.source == 'vitalbridge_test');
    final stepsAchievement = GoalRules.achievementRate(_steps, _goalSteps);
    final sleepText = _goalSleepMinutes == null
        ? '미설정'
        : '${(_goalSleepMinutes! / 60).toStringAsFixed(1)}시간';
    final yesterday = _today.subtract(const Duration(days: 1));
    final sleepHours = _singleSourceMetric(yesterday, PatternMetric.sleep);
    final sleepAchievement = GoalRules.achievementRate(
      sleepHours == null ? null : sleepHours * 60,
      _goalSleepMinutes,
    );
    final exerciseWeekly = _weeklyExerciseEquivalent();
    final exerciseAchievement = GoalRules.achievementRate(
      exerciseWeekly,
      _goalExercise,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          '나의 생활패턴 목표',
          trailing: TextButton.icon(
            onPressed: _loadingGoals || _savingGoals ? null : _editGoals,
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              _savingGoals
                  ? '저장 중...'
                  : _goalSteps == null
                  ? '목표 설정'
                  : '목표 수정',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasTestRecords)
          const Text(
            '테스트 데이터가 포함되어 있습니다. 달성률은 실제 측정 결과가 아닐 수 있습니다.',
            style: TextStyle(color: Colors.deepOrange, fontSize: 12),
          ),
        if (_loadingGoals)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _goalProgress(
                    title: '하루 걸음 수',
                    target: _goalSteps == null ? '미설정' : '$_goalSteps보',
                    currentText: _steps == null ? '오늘 기록 없음' : '오늘 $_steps보',
                    achievement: stepsAchievement,
                    icon: Icons.directions_walk,
                  ),
                  const Divider(),
                  _goalProgress(
                    title: '하루 수면 시간',
                    target: sleepText,
                    currentText: sleepHours == null
                        ? '어제 종료된 유효 수면 기록 없음'
                        : '어제 종료된 수면: ${sleepHours.toStringAsFixed(1)}시간',
                    achievement: sleepAchievement,
                    icon: Icons.bedtime,
                  ),
                  const Divider(),
                  _goalProgress(
                    title: '주간 운동 시간',
                    target: _goalExercise == null ? '미설정' : '$_goalExercise분',
                    currentText: exerciseWeekly == null
                        ? '최근 7일 유효 운동 기록 부족 (최소 5일)'
                        : '최근 7일 중강도 상당 운동량: ${exerciseWeekly.toStringAsFixed(0)}분/주 (유효일 환산)',
                    achievement: exerciseAchievement,
                    icon: Icons.fitness_center,
                  ),
                ],
              ),
            ),
          ),
        if (_goalError != null) ...[
          const SizedBox(height: 8),
          Text(_goalError!, style: const TextStyle(color: Colors.red)),
          TextButton(
            onPressed: _loadingGoals ? null : _loadGoals,
            child: const Text('목표 다시 불러오기'),
          ),
        ],
        const SizedBox(height: 12),
        _recommendationSection(),
        const SizedBox(height: 8),
        const Text(
          '수면은 어제 기상한 기록, 운동은 최근 완료된 7일의 중강도 상당량을 사용합니다. '
          '기록이나 강도 정보가 부족하면 달성률을 표시하지 않습니다.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 6),
        const Text(
          '목표는 로그인한 계정의 Supabase 데이터베이스에 저장됩니다.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  // 실제 DB 기록으로 계산한 사용자별 목표 추천.
  // 화면에서 제안하는 값은 목표를 자동 변경하지 않습니다.
  Widget _recommendationSection() {
    final recommendation = _recommendation;
    final suggested = recommendation?.suggestedSteps;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '실제 기록 기반 목표 제안',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '추천 다시 계산',
                  onPressed: _loadingRecommendation
                      ? null
                      : _loadRecommendation,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '지난 완료 날짜의 실제 측정값으로 계산합니다. '
              '제품용 목표 제안이며 의료적 처방은 아닙니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_loadingRecommendation)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recommendationError != null) ...[
              Text(
                _recommendationError!,
                style: const TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: _loadRecommendation,
                child: const Text('다시 시도'),
              ),
            ] else if (recommendation == null)
              const Text('추천 결과를 불러오지 못했습니다.')
            else ...[
              Text(
                suggested == null
                    ? '걸음 수 추천: 데이터 부족 (${recommendation.validStepDays}/9일)'
                    : '걸음 수 제안: $suggested보/일 '
                          '(최근 9일 기록의 60백분위수)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (suggested != null)
                OutlinedButton.icon(
                  // 기록을 읽어 자동 저장하지 않고 사용자가 편집/확인하도록 함.
                  onPressed: _loadingGoals || _savingGoals
                      ? null
                      : () => _editGoals(suggestedSteps: suggested),
                  icon: const Icon(Icons.tune),
                  label: const Text('추천 걸음 수로 목표 설정하기'),
                ),
              const SizedBox(height: 8),
              Text(
                recommendation.sleepAdvice ??
                    '수면 안내: 데이터 부족 '
                        '(${recommendation.validSleepDays}/14일, 최소 10일 필요)',
              ),
              const SizedBox(height: 8),
              const Text(
                '운동 목표 추천: 강도별 운동 기록과 '
                '미측정일 처리 검증 전이므로 보류합니다.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('생활패턴 분석'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _connectionSection(),
        const SizedBox(height: 24),
        _todaySection(),
        const SizedBox(height: 24),
        _graphSection(),
        const SizedBox(height: 24),
        _goalSection(),
        const SizedBox(height: 24),
        _sectionTitle('생활패턴 분석 안내'),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '주간·월간 그래프는 Supabase의 저장 기록을 사용합니다. '
              '테스트 데이터가 포함되면 테스트 여부를 표시합니다. '
              '건강 기록 자동 수집은 Android 기기 연동 단계에서 구현합니다.',
            ),
          ),
        ),
      ],
    ),
  );
}

class HealthCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;

  const HealthCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(unit),
        ],
      ),
    ),
  );
}
