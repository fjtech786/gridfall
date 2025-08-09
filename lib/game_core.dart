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

  // board grid
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
      canvas.drawRect(rect, paintGrid);
      canvas.drawRect(rect.deflate(0.5), paintBorder);
    }
  }

  // frozen blocks
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final color = grid[r][c];
      if (color != null) _draw(canvas, cell, r, c, color);
    }
  }

  // current + ghost
  if (cur != null) {
    // ---- compute ghost without using cascade ++ ----
    var ghost = cur!.copy();
    // move a probe downward while valid; keep last valid as ghost
    var probe = ghost.copy();
    probe.row += 1;
    while (_valid(probe)) {
      ghost = probe;
      probe = ghost.copy();
      probe.row += 1;
    }

    // draw ghost
    final gp = Paint()..color = cur!.color.withOpacity(.18);
    for (final cellPos in _cellsOf(ghost)) {
      final rect = Rect.fromLTWH(cellPos.c * cell + 1, cellPos.r * cell + 1, cell - 2, cell - 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), gp);
    }

    // draw current piece
    for (final cellPos in _cellsOf(cur!)) {
      _draw(canvas, cell, cellPos.r, cellPos.c, cur!.color);
    }
  }
}
