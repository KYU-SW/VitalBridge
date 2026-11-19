import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kPri = Color(0xFF009688);
const kStat = [Color(0xFF2E9E4F), Color(0xFFEF8A00), Color(0xFFE53935)];
const kLabel = ['정상', '⚠️ 주의', '🚨 위험'];
const kDisc = '※ 이 정보는 진단이 아닌 참고용입니다. 정확한 해석은 의료진과 상담하세요.';

// ───────── 검사 항목 정의 ─────────
typedef Judge = int Function(double v, bool male);
typedef Band = List<double?> Function(bool male);
Judge lt(double a, double b) =>
    (v, m) => v < a
    ? 0
    : v < b
    ? 1
    : 2;
Band fixed(double a, double? b) =>
    (m) => [a, b];

class Item {
  final String name, title, cat, unit, desc;
  final List<String> ref;
  final Judge judge;
  final Band band;
  Item(
    this.name,
    this.title,
    this.cat,
    this.unit,
    this.ref,
    this.desc,
    this.judge,
    this.band,
  );
}

final items = <Item>[
  Item(
    'BMI',
    'BMI(체질량지수)',
    '비만도',
    'kg/m²',
    ['18.5~22.9', '23.0~24.9', '25.0 이상'],
    '키 대비 체중 비율입니다. 체중관리가 필요한지 나타냅니다.',
    (v, m) => v < 18.5
        ? 1
        : v < 23
        ? 0
        : v < 25
        ? 1
        : 2,
    fixed(18.5, 22.9),
  ),
  Item(
    '수축기혈압',
    '수축기 혈압',
    '혈압',
    'mmHg',
    ['120 미만', '120~139', '140 이상'],
    '심장이 혈액을 보낼 때 혈관이 받는 압력입니다.',
    lt(120, 140),
    fixed(0, 119),
  ),
  Item(
    '이완기혈압',
    '이완기 혈압',
    '혈압',
    'mmHg',
    ['80 미만', '80~89', '90 이상'],
    '심장이 쉴 때 혈관에 남아 있는 압력입니다.',
    lt(80, 90),
    fixed(0, 79),
  ),
  Item(
    '공복혈당',
    '공복 혈당',
    '혈당',
    'mg/dL',
    ['100 미만', '100~125', '126 이상'],
    '8시간 이상 금식 후 측정한 혈액 속 설탕(당) 농도입니다.',
    lt(100, 126),
    fixed(0, 99),
  ),
  Item(
    '혈색소',
    '혈색소(헤모글로빈)',
    '혈액/빈혈',
    'g/dL',
    ['남 13~16.5 / 여 12~15.5', '남 12~12.9 / 여 10~11.9', '남 12 미만 / 여 10 미만'],
    '혈액 속에서 산소를 운반하는 성분입니다. 부족하면 빈혈이 옵니다.',
    (v, m) {
      final t = m ? [13.0, 16.5, 12.0] : [12.0, 15.5, 10.0];
      return v < t[2]
          ? 2
          : (v < t[0] || v > t[1])
          ? 1
          : 0;
    },
    (m) => m ? [13.0, 16.5] : [12.0, 15.5],
  ),
  Item(
    '총콜레스테롤',
    '총콜레스테롤',
    '지질',
    'mg/dL',
    ['200 미만', '200~239', '240 이상'],
    '혈액 속에 돌아다니는 전체 지방 물질의 양입니다.',
    lt(200, 240),
    fixed(0, 199),
  ),
  Item(
    '중성지방',
    '중성지방(Triglyceride)',
    '지질',
    'mg/dL',
    ['150 미만', '150~199', '200 이상'],
    '음식으로 섭취한 칼로리 중 쓰고 남은 것이 쌓인 지방 성분입니다.',
    lt(150, 200),
    fixed(0, 149),
  ),
  Item(
    'HDL',
    'HDL콜레스테롤',
    '지질',
    'mg/dL',
    ['60 이상', '40~59', '40 미만'],
    '혈관을 청소해주는 좋은 콜레스테롤입니다. (높을수록 좋음)',
    (v, m) => v >= 60
        ? 0
        : v >= 40
        ? 1
        : 2,
    fixed(60, null),
  ),
  Item(
    'LDL',
    'LDL콜레스테롤',
    '지질',
    'mg/dL',
    ['100 미만', '100~129', '130 이상'],
    '혈관 벽에 쌓여 혈관을 막는 나쁜 콜레스테롤입니다.',
    lt(100, 130),
    fixed(0, 99),
  ),
  Item(
    'AST',
    'AST(SGOT)',
    '간기능',
    'U/L',
    ['40 이하', '41~80', '81 이상'],
    '간세포가 손상되었을 때 혈액으로 흘러나오는 효소입니다.',
    lt(41, 81),
    fixed(0, 40),
  ),
  Item(
    'ALT',
    'ALT(SGPT)',
    '간기능',
    'U/L',
    ['35 이하', '36~80', '81 이상'],
    '주로 간에 존재하며, 간 피로나 지방간 상태를 잘 반영합니다.',
    lt(36, 81),
    fixed(0, 35),
  ),
  Item(
    '감마GTP',
    '감마지티피(γ-GTP)',
    '간기능',
    'U/L',
    ['남 11~63 / 여 8~35', '약간 상승 (정상 상한 초과)', '현저히 상승 (정상 상한의 2배 초과)'],
    '음주나 음주 외 간 질환, 쓸개 길 이상을 확인할 때 봅니다.',
    (v, m) {
      final x = m ? 63 : 35;
      return v <= x
          ? 0
          : v <= 2 * x
          ? 1
          : 2;
    },
    (m) => m ? [11.0, 63.0] : [8.0, 35.0],
  ),
  Item(
    '크레아티닌',
    '혈청 크레아티닌',
    '신장(콩팥)',
    'mg/dL',
    ['1.5 이하', '1.6~2.0', '2.1 이상'],
    '근육이 활동하고 남은 노폐물로, 콩팥이 잘 걸러내는지 봅니다.',
    lt(1.6, 2.1),
    fixed(0, 1.5),
  ),
];
final byName = {for (final i in items) i.name: i};
const alias = {
  'BMI': '비만 체중 키 체질량',
  '공복혈당': '당뇨 혈당 sugar glucose',
  '혈색소': '빈혈 헤모글로빈 hemoglobin',
  'HDL': '좋은콜레스테롤',
  'LDL': '나쁜콜레스테롤',
  '중성지방': 'tg 트리글리세라이드',
  'AST': '간수치 간 sgot',
  'ALT': '간수치 간 sgpt',
  '감마GTP': '간수치 간 ggt 지티피',
  '크레아티닌': '콩팥 신장 cr',
  '수축기혈압': '고혈압 최고혈압',
  '이완기혈압': '최저혈압',
};

// ───────── 데이터 / 상태 ─────────
class Rec {
  final String n;
  final double v;
  Rec(this.n, this.v);
  Map<String, dynamic> toJson() => {'n': n, 'v': v};
  factory Rec.fromJson(Map<String, dynamic> j) =>
      Rec(j['n'], (j['v'] as num).toDouble());
}

class Checkup {
  final String id, date, hospital;
  final List<Rec> r;
  Checkup(this.id, this.date, this.hospital, this.r);
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'hospital': hospital,
    'r': r.map((x) => x.toJson()).toList(),
  };
  factory Checkup.fromJson(Map<String, dynamic> j) => Checkup(
    j['id'],
    j['date'],
    j['hospital'],
    (j['r'] as List).map((x) => Rec.fromJson(x)).toList(),
  );
}

List<Rec> mk(List<double> a) => [
  for (var i = 0; i < items.length; i++) Rec(items[i].name, a[i]),
];
String f(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
int stat(Rec r) => byName[r.n]!.judge(r.v, app.male);

class AppState extends ChangeNotifier {
  final _db = Supabase.instance.client;

  bool male = true;
  bool busy = false;

  final List<Checkup> checkups = [];

  String? _owner;
  int _version = 0;
  bool _ready = false;

  bool _active(String uid, int version) =>
      _owner == uid && _version == version && _db.auth.currentUser?.id == uid;

  void clearSession(String uid) {
    if (_owner != uid) return;

    _version++;
    _owner = null;
    _ready = false;
    busy = false;
    male = true;
    checkups.clear();
  }

  String _requireUser() {
    final uid = _db.auth.currentUser?.id;

    if (uid == null || uid != _owner || !_ready) {
      throw StateError('로그인이 필요합니다.');
    }

    if (busy) {
      throw StateError('다른 작업이 진행 중입니다.');
    }

    return uid;
  }

  // 로그인한 사용자의 데이터 불러오기
  Future<void> load(String uid) async {
    if (_db.auth.currentUser?.id != uid) {
      throw StateError('로그인이 필요합니다.');
    }

    final version = ++_version;
    _owner = uid;
    _ready = false;
    busy = false;
    male = true;
    checkups.clear();

    final profile = await _db
        .from('profiles')
        .select('male')
        .eq('user_id', uid)
        .maybeSingle();

    final rows = await _db
        .from('health_checkups')
        .select('id, date, hospital, r')
        .eq('user_id', uid)
        .order('date', ascending: true);

    if (!_active(uid, version)) {
      throw StateError('로그인 상태가 변경되었습니다.');
    }

    final records = rows
        .map((row) => Checkup.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    male = (profile?['male'] as bool?) ?? true;

    checkups
      ..clear()
      ..addAll(records);

    _ready = true;
  }

  // 사용자 성별 설정 저장
  Future<void> setMale(bool v) async {
    final uid = _requireUser();
    final version = _version;

    busy = true;
    notifyListeners();

    try {
      await _db.from('profiles').upsert({'user_id': uid, 'male': v});

      if (!_active(uid, version)) {
        throw StateError('로그인 상태가 변경되었습니다.');
      }

      male = v;
    } finally {
      if (_active(uid, version)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  // 건강검진 결과 저장
  Future<void> add(Checkup c) async {
    final uid = _requireUser();
    final version = _version;

    busy = true;
    notifyListeners();

    try {
      await _db.from('health_checkups').insert({'user_id': uid, ...c.toJson()});

      if (!_active(uid, version)) {
        throw StateError('로그인 상태가 변경되었습니다.');
      }

      checkups.add(c);
      checkups.sort((a, b) => a.date.compareTo(b.date));
    } finally {
      if (_active(uid, version)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  // 건강검진 결과 삭제
  Future<void> remove(String id) async {
    final uid = _requireUser();
    final version = _version;

    busy = true;
    notifyListeners();

    try {
      final deleted = await _db
          .from('health_checkups')
          .delete()
          .eq('id', id)
          .eq('user_id', uid)
          .select('id');

      if (!_active(uid, version)) {
        throw StateError('로그인 상태가 변경되었습니다.');
      }

      if (deleted.isEmpty) {
        throw StateError('삭제할 기록이 없습니다.');
      }

      checkups.removeWhere((c) => c.id == id);
    } finally {
      if (_active(uid, version)) {
        busy = false;
        notifyListeners();
      }
    }
  }
}

final app = AppState();
