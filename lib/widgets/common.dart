import 'package:flutter/material.dart';

import '../data.dart';

void push(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

class StatusBadge extends StatelessWidget {
  final int k;
  const StatusBadge(this.k, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: kStat[k].withAlpha(40),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      kLabel[k],
      style: TextStyle(
        color: kStat[k],
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

Widget catHeader(String t) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 6),
  child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
);
