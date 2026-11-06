import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';

class LinePainter extends CustomPainter {
  final List<double> v;
  final List<String> xs;
  final List<int> ks;
  final List<double?> band;
  final Color txt;
  LinePainter(this.v, this.xs, this.ks, this.band, this.txt);

  void label(
    Canvas c,
    String s,
    Offset o, {
    double size = 10,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: txt,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy));
  }

  @override
  void paint(Canvas c, Size s) {
    const p = 30.0;
    final w = s.width, h = s.height, bot = h - 30, n = v.length;
    final lo =
        [...v, band[0]!, if (band[1] != null) band[1]!].reduce(math.min) * .9;
    final hi = [...v, if (band[1] != null) band[1]!].reduce(math.max) * 1.06;
    double X(int i) => n == 1 ? w / 2 : p + i * (w - 2 * p) / (n - 1);
    double Y(double x) => bot - (x - lo) / (hi - lo) * (bot - p);
    final top = Y(band[1] ?? hi), bt = Y(math.max(band[0]!, lo));
    c.drawRect(
      Rect.fromLTRB(p - 10, top, w - p + 10, math.max(bt, top)),
      Paint()..color = kStat[0].withAlpha(40),
    );
    final path = Path();
    for (var i = 0; i < n; i++) {
      i == 0 ? path.moveTo(X(i), Y(v[i])) : path.lineTo(X(i), Y(v[i]));
    }
    c.drawPath(
      path,
      Paint()
        ..color = kPri
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var i = 0; i < n; i++) {
      c.drawCircle(Offset(X(i), Y(v[i])), 5, Paint()..color = kStat[ks[i]]);
      label(c, f(v[i]), Offset(X(i), Y(v[i]) - 20), size: 11, bold: true);
      label(c, xs[i], Offset(X(i), h - 16));
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter o) => true;
}
