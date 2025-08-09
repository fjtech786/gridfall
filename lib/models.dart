
import 'package:flutter/material.dart';
import 'theme.dart';

enum GameMode { classic, zen, timeAttack, marathon40, endless, daily }

class Tetromino {
  final List<List<int>> base;
  final Color color;
  int row, col, rot;
  Tetromino(this.base, this.color, {this.row = 0, this.col = 3, this.rot = 0});
  List<List<int>> get shape {
    var m = base;
    for (int i=0;i<rot%4;i++) {
      final r = m.length, c = m[0].length;
      final out = List.generate(c, (_)=>List.filled(r,0));
      for (int a=0;a<r;a++){ for(int b=0;b<c;b++){ out[b][r-1-a] = m[a][b]; } }
      m = out;
    }
    return m;
  }
  void rotateCW() => rot = (rot + 1) % 4;
  Iterable<(int,int)> cells() sync* {
    final s = shape;
    for (int r=0;r<s.length;r++) for(int c=0;c<s[0].length;c++) if (s[r][c]==1) yield (row+r, col+c);
  }
  Tetromino copy()=>Tetromino(base.map((x)=>[...x]).toList(), color,row:row,col:col,rot:rot);
  static final i=Tetromino([[1,1,1,1]],GFColors.cyan);
  static final o=Tetromino([[1,1],[1,1]],GFColors.amber);
  static final t=Tetromino([[1,1,1],[0,1,0]],GFColors.pink);
  static final s=Tetromino([[0,1,1],[1,1,0]],GFColors.lime);
  static final z=Tetromino([[1,1,0],[0,1,1]],GFColors.orange);
  static final j=Tetromino([[1,0,0],[1,1,1]],GFColors.blue);
  static final l=Tetromino([[0,0,1],[1,1,1]],GFColors.purple);
  static List<Tetromino> all()=>[i,o,t,s,z,j,l];
}
