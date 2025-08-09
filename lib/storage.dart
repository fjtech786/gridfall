
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Storage {
  static Future<void> saveScore(ScoreEntry e) async {
    final p = await SharedPreferences.getInstance();
    final k = 'scores_${e.mode.name}';
    final list = p.getStringList(k) ?? [];
    list.add(jsonEncode(e.toJson()));
    await p.setStringList(k, list);
  }
  static Future<List<ScoreEntry>> loadScores(GameMode m) async {
    final p = await SharedPreferences.getInstance();
    final k = 'scores_${m.name}';
    final list = p.getStringList(k) ?? [];
    return list.map((s)=>ScoreEntry.fromJson(jsonDecode(s))).toList()
      ..sort((a,b)=>b.score.compareTo(a.score));
  }
}

class ScoreEntry {
  final GameMode mode; final int score; final int lines; final int timeMs; final DateTime when;
  ScoreEntry(this.mode,this.score,this.lines,this.timeMs,this.when);
  Map<String,dynamic> toJson()=>{'mode':mode.name,'score':score,'lines':lines,'timeMs':timeMs,'when':when.toIso8601String()};
  static ScoreEntry fromJson(Map<String,dynamic> j)=>ScoreEntry(
    GameMode.values.firstWhere((m)=>m.name==j['mode']), j['score'], j['lines'], j['timeMs'], DateTime.parse(j['when'])
  );
}
