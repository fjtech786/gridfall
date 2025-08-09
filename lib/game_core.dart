import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

typedef ScoreCb = void Function(int score, int lines, int level, int timeMs);

class Cell {
  final int r, c;
  const Cell(this.r, this.c);
}

class GridFallGame extends FlameGame {
  static const cols = 10, rows = 20;

  final GameMode mode;
  final Random rng;
  final ScoreCb onScore;
  final VoidCallback onGameOver;

  final ValueNotifier<Tetromino?> nextPreview = ValueNotifier(null);
  final ValueNotifier<Tetromino?> holdPreview = ValueNotifier(null);

  List<List<Color?>> grid = List.generate(rows, (_) => List.filled(cols, null));
  Tetromino? cur;
  Tetromino? hold;
  bool canHold = true;
  final _bag = <Tetromino>[];

  int level = 1, score = 0, lines = 0;
  late Timer _tick;
  bool paused = false, gameOver = false;

  final DateTime start = DateTime.now();
  int timeLimitMs = 0; // for timeAttack
  int targetLines = 0; // for marathon40

  GridFallGame({
    required this.mode,
    required this.onScore,
    required this.onGameOver,
    int? seed,
  }) : rng = Random(seed);

  @override
  Future<void> onLoad() async {
    _initMode();
    _spawn();
    _startTimer();
    overlays.add('touch');
  }

  void _initMode() {
    if (mode == GameMode.timeAttack) timeLimitMs = 120000;
    if (mode == GameMode.marathon40) targetLines = 40;
  }

  void _startTimer() => _tick = Timer.periodic(_speed, (_) => _step());

  Duration get _speed {
    int base = 700 - (level - 1) * 50;
    if (mode == GameMode.zen) base = 900;
    if (mode == GameMode.endless) base = 650 - (lines ~/ 10) * 30;
    return Duration(milliseconds: base.clamp(120, 900));
  }

  void _resched() {
    _tick.cancel();
    _tick = Timer.periodic(_speed, (_) => _step());
  }

  void pause() {
    paused = true;
    _tick.cancel();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    _resched();
  }

  void _spawn() {
    cur = _next()..row = 0..col = 3..rot = 0;
    nextPreview.value = _peek();
  }

  Tetromino _next() {
    if (_bag.isEmpty) {
      final all = Tetromino.all().map((t) => t.copy()).toList();
      all.shuffle(rng);
      _bag.addAll(all);
    }
    return _bag.removeAt(0);
  }

  Tetromino? _peek() {
    if (_bag.isEmpty) {
      final all = Tetromino.all().map((t) => t.copy()).toList();
      all.shuffle(rng);
      _bag.addAll(all);
    }
    return _bag.first.copy();
  }

  bool _valid(Tetromino t) {
    for (final cell in _cellsOf(t)) {
      final r = cell.r, c = cell.c;
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (grid[r][c] != null) return false;
    }
    return true;
  }

  List<Cell> _cellsOf(Tetromino t) {
    final s = t.shape;
    final out = <Cell>[];
    for (int r = 0; r < s.length; r++) {
      for (int c = 0; c < s[0].length; c++) {
        if (s[r][c] == 1) out.add(Cell(t.row + r, t.col + c));
      }
    }
    return out;
  }

  void _merge() {
    for (final cell in _cellsOf(cur!)) {
      grid[cell.r][cell.c] = cur!.color;
    }
    canHold = true;
  }

  int _clear() {
    int cleared = 0;
    for (int r = rows - 1; r >= 0; r--) {
      if (grid[r].every((c) => c != null)) {
        grid.removeAt(r);
        grid.insert(0, List.filled(cols, null));
        cleared++;
        r++;
      }
    }
    if (cleared > 0) {
      lines += cleared;
      const table = {1: 100, 2: 300, 3: 500, 4: 800};
      score += table[cleared] ?? 0;
      level = 1 + (lines ~/ 10);
      _resched();
    }
    return cleared;
  }

  void _step() {
    if (paused || gameOver) return;

    if (mode == GameMode.timeAttack && _elapsed >= timeLimitMs) {
      _end();
      return;
    }

    if (!_try(1, 0)) {
      _merge();
      _clear();

      if (mode == GameMode.marathon40 && lines >= targetLines) {
        score += 1000;
        _end();
        return;
      }

      _spawn();
      if (!_valid(cur!)) {
        if (mode == GameMode.zen) {
          grid.removeAt(0);
          grid.insert(rows - 1, List.filled(cols, null));
        } else {
          _end();
          return;
        }
      }
    }

    onScore(score, lines, level, _elapsed);
  }

  int get _elapsed => DateTime.now().difference(start).inMilliseconds;

  bool _try(int dr, int dc) {
    final t = cur!.copy()..row += dr..col += dc;
    if (_valid(t)) {
      cur = t;
      return true;
    }
    return false;
  }

  void move(int dc) {
    if (!paused) _try(0, dc);
  }

  void softDrop() {
    if (!paused) {
      if (_try(1, 0)) {
        score += 1;
      } else {
        _step();
      }
      onScore(score, lines, level, _elapsed);
    }
  }

  void hardDrop() {
    if (paused) return;
    int d = 0;
    while (_try(1, 0)) d++;
    score += d * 2;
    _step();
  }

  void rotate() {
    if (paused) return;
    final t = cur!.copy()..rotateCW();
    for (final k in [0, -1, 1, -2, 2]) {
      final test = t.copy()..col += k;
      if (_valid(test)) {
        cur = test;
        return;
      }
    }
  }

  void holdPiece() {
    if (!canHold) return;
    final tmp = hold;
    hold = cur!..row = 0..col = 3..rot = 0;
    if (tmp == null) {
      cur = _next()..row = 0..col = 3;
    } else {
      cur = tmp..row = 0..col = 3;
    }
    canHold = false;
    holdPreview.value = hold;
  }

  void _end() {
    gameOver = true;
    _tick.cancel();
    onGameOver();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final size = canvasSize;
    if (size == null) return;

    final cell = size.x / cols;
    final paintGrid = Paint()..color = GFColors.grid;
    final paintBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = GFColors.border;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, paintGrid);
        canvas.drawRect(rect.deflate(0.5), paintBorder);
      }
    }

    // Frozen blocks
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final color = grid[r][c];
        if (color != null) _draw(canvas, cell, r, c, color);
      }
    }

    // Current + ghost
    if (cur != null) {
      var ghost = cur!.copy();
      // drop ghost until just before collision
      while (_valid(ghost.copy()..row++)) {
        ghost.row++;
      }
      final gp = Paint()..color = cur!.color.withOpacity(.18);
      for (final cellPos in _cellsOf(ghost)) {
        final rect = Rect.fromLTWH(cellPos.c * cell + 1, cellPos.r * cell + 1, cell - 2, cell - 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), gp);
      }
      for (final cellPos in _cellsOf(cur!)) {
        _draw(canvas, cell, cellPos.r, cellPos.c, cur!.color);
      }
    }
  }

  void _draw(Canvas canvas, double cell, int r, int c, Color color) {
    final rect = Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2);
    final paint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
    final hi = Paint()..color = Colors.white.withOpacity(.08);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .35), hi);
  }
}
