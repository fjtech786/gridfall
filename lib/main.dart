
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_core.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GridFallApp());
}

class GridFallApp extends StatelessWidget {
  const GridFallApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title:'GridFall', debugShowCheckedModeBanner:false, theme: buildTheme(), home: const HomePage());
  }
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  @override void initState(){ super.initState(); _maybeShowTutorial(); }
  Future<void> _maybeShowTutorial() async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool('seen_tutorial') ?? false;
    if (!seen && mounted) _showTutorial();
  }
  Future<void> _showTutorial() async {
    bool dontShow = true;
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .8, minChildSize: .6, maxChildSize: .95,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(color: GFColors.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
            const SizedBox(height:4),
            Center(child: Container(width:42, height:4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height:16),
            const Text('How to Play', style: TextStyle(fontSize:24,fontWeight: FontWeight.w800)),
            const SizedBox(height:12),
            _tip(Icons.swipe_left, 'Swipe left / right', 'Move the piece horizontally.'),
            _tip(Icons.rotate_right, 'Tap', 'Rotate the piece.'),
            _tip(Icons.keyboard_double_arrow_down, 'Swipe down', 'Soft drop (faster descent).'),
            _tip(Icons.flash_on, 'Double tap', 'Hard drop for instant lock & bonus.'),
            _tip(Icons.archive_outlined, 'Long press', 'Hold piece and swap later.'),
            const SizedBox(height:16),
            StatefulBuilder(builder:(c,setS)=> CheckboxListTile(
              value: dontShow, onChanged:(v)=>setS(()=>dontShow=v??true),
              title: const Text("Don't show again"), controlAffinity: ListTileControlAffinity.leading,
            )),
            const SizedBox(height:8),
            FilledButton(onPressed: () async {
              final p = await SharedPreferences.getInstance();
              if (dontShow) await p.setBool('seen_tutorial', true);
              if (ctx.mounted) Navigator.pop(ctx);
            }, child: const Text('Got it')),
          ]),
        ),
      ),
    );
  }
  Widget _tip(IconData icon, String title, String subtitle){
    return Container(margin: const EdgeInsets.symmetric(vertical:6), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GFColors.bg.withOpacity(.6), borderRadius: BorderRadius.circular(14)),
      child: Row(children:[
        Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(10), child: Icon(icon)),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:2),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ])),
      ]),
    );
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('GridFall')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GFColors.panel, borderRadius: BorderRadius.circular(20)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Text('Fall. Align. Clear.', style: TextStyle(fontSize:28,fontWeight: FontWeight.w800)),
            SizedBox(height:6),
            Text('Modern falling-blocks puzzle • multiple modes • buttery-smooth controls'),
          ]),
        ),
        const SizedBox(height:16),
        _modeTile(context, GameMode.classic, 'Classic', 'Clear lines; speed increases.'),
        _modeTile(context, GameMode.zen, 'Zen', 'Relaxed play, no game over.'),
        _modeTile(context, GameMode.timeAttack, 'Time Attack', '2 minutes. Score big.'),
        _modeTile(context, GameMode.marathon40, 'Marathon 40', 'Clear 40 lines fast.'),
        _modeTile(context, GameMode.endless, 'Endless', 'Ramps forever.'),
        _modeTile(context, GameMode.daily, 'Daily Challenge', 'Same seed for everyone today.'),
        const SizedBox(height:16),
        FilledButton.icon(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>const LeaderboardsPage())), icon: const Icon(Icons.leaderboard), label: const Text('Local Leaderboards')),
      ]),
    );
  }
  Widget _modeTile(BuildContext context, GameMode mode, String title, String subtitle){
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right),
        onTap: (){ int? seed; if(mode==GameMode.daily){ final n=DateTime.now().toUtc(); seed=int.parse('${n.year}${n.month.toString().padLeft(2,'0')}${n.day.toString().padLeft(2,'0')}'); }
          Navigator.push(context, MaterialPageRoute(builder:(_)=> GamePage(mode: mode, seed: seed))); },
      ),
    );
  }
}

class GamePage extends StatefulWidget { final GameMode mode; final int? seed; const GamePage({super.key, required this.mode, this.seed}); @override State<GamePage> createState()=>_GamePageState(); }
class _GamePageState extends State<GamePage> {
  late GridFallGame game; int score=0, lines=0, level=1, elapsed=0;
  @override void initState(){ super.initState(); game=GridFallGame(mode: widget.mode, onScore:(s,l,lv,t){ setState(()=>{score=s,lines=l,level=lv,elapsed=t}); }, onGameOver: _onGameOver, seed: widget.seed); }
  void _onGameOver() async {
    await Storage.saveScore(ScoreEntry(widget.mode, score, lines, elapsed, DateTime.now()));
    if(!mounted) return;
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Game Over'), content: Text('Score: $score\nLines: $lines\nLevel: $level'), actions: [
      TextButton(onPressed: (){ Navigator.pop(context); Navigator.pop(context); }, child: const Text('Exit')),
      FilledButton(onPressed: (){ Navigator.pop(context); setState(()=> game = GridFallGame(mode: widget.mode, onScore:(s,l,lv,t){ setState(()=>{score=s,lines=l,level=lv,elapsed=t}); }, onGameOver: _onGameOver, seed: widget.seed)); }, child: const Text('Play Again')),
    ]));
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text(_title(widget.mode)), actions:[ IconButton(icon: const Icon(Icons.pause), onPressed: (){ game.pause(); _pause(); }) ]),
      body: SafeArea(child: Column(children:[
        const SizedBox(height:8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[ _stat('Score', '$score'), _stat('Lines', '$lines'), _stat('Level', '$level'), _stat('Time','${(elapsed~/60000).toString().padLeft(2,'0')}:${((elapsed~/1000)%60).toString().padLeft(2,'0')}') ]),
        const SizedBox(height:8),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 10/20, child: Stack(children:[
          GameWidget(game: game, overlayBuilderMap:{'touch': (ctx,g)=> _touchLayer()}),
          Positioned(right: 8, top: 8, child: _nextHold()),
        ])))),
        const SizedBox(height:8),
        _controls(), const SizedBox(height:8),
      ])),
    );
  }
  String _title(GameMode m){ switch(m){ case GameMode.classic:return 'Classic'; case GameMode.zen:return 'Zen'; case GameMode.timeAttack:return 'Time Attack'; case GameMode.marathon40:return 'Marathon 40'; case GameMode.endless:return 'Endless'; case GameMode.daily:return 'Daily Challenge'; } }
  Widget _stat(String l,String v)=> Container(padding: const EdgeInsets.symmetric(vertical:8,horizontal:12), decoration: BoxDecoration(color: GFColors.panel, borderRadius: BorderRadius.circular(12)), child: Column(children:[ Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)) ]));
  Widget _nextHold()=> Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GFColors.panel.withOpacity(.9), borderRadius: BorderRadius.circular(12)), child: Row(children:[
    Column(children:[ const Text('Next', style: TextStyle(fontSize:12,color:Colors.white70)), ValueListenableBuilder<Tetromino?>(valueListenable: game.nextPreview, builder:(_,t,__)=>
      CustomPaint(size: const Size(56,56), painter: _MiniPainter(t)))]),
    const SizedBox(width:8),
    Column(children:[ const Text('Hold', style: TextStyle(fontSize:12,color:Colors.white70)), ValueListenableBuilder<Tetromino?>(valueListenable: game.holdPreview, builder:(_,t,__)=>
      CustomPaint(size: const Size(56,56), painter: _MiniPainter(t)))]),
  ]));
  Widget _controls(){ Widget btn(IconData ic, VoidCallback onTap,{VoidCallback? onLong})=> GestureDetector(onTap:onTap,onLongPress:onLong, child: Container(width:72, padding: const EdgeInsets.symmetric(vertical:12), alignment: Alignment.center, decoration: BoxDecoration(color: GFColors.panel, borderRadius: BorderRadius.circular(16)), child: Icon(ic)));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[ btn(Icons.keyboard_arrow_left, ()=> game.move(-1)), btn(Icons.rotate_right, ()=> game.rotate()), btn(Icons.keyboard_arrow_right, ()=> game.move(1)), btn(Icons.keyboard_arrow_down, ()=> game.softDrop(), onLong: ()=> game.hardDrop()), ]); }
  Widget _touchLayer()=> GestureDetector(behavior: HitTestBehavior.translucent, onTap: ()=>game.rotate(), onDoubleTap: ()=>game.hardDrop(), onHorizontalDragUpdate: (d){ if(d.delta.dx.abs()>8) game.move(d.delta.dx>0?1:-1); }, onVerticalDragUpdate: (d){ if(d.delta.dy>8) game.softDrop(); }, onLongPress: ()=> game.holdPiece(), child: const SizedBox.expand());
  void _pause(){ showModalBottomSheet(context: context, backgroundColor: GFColors.panel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_)=> Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children:[ const Text('Paused', style: TextStyle(fontSize:18,fontWeight: FontWeight.w800)), const SizedBox(height:8),
      Row(children:[ Expanded(child: FilledButton(onPressed: (){ Navigator.pop(context); game.resume(); }, child: const Text('Resume'))), const SizedBox(width:8), Expanded(child: OutlinedButton(onPressed: (){ Navigator.pop(context); Navigator.pop(context); }, child: const Text('Exit'))), ]),
    ]))); }
}

class _MiniPainter extends CustomPainter{ final Tetromino? t; const _MiniPainter(this.t);
  @override void paint(Canvas canvas, Size size){ if(t==null) return; final s=t!.shape; final rows=s.length, cols=s[0].length; final cell = (size.width/cols).clamp(0, size.width);
    final paint = Paint()..color=t!.color; for(int r=0;r<rows;r++){ for(int c=0;c<cols;c++){ if(s[r][c]==1){ final rect=Rect.fromLTWH(c*cell+2, r*cell+2, cell-4, cell-4); canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint); } } } }
  @override bool shouldRepaint(covariant _MiniPainter o)=> o.t!=t; }

class LeaderboardsPage extends StatefulWidget{ const LeaderboardsPage({super.key}); @override State<LeaderboardsPage> createState()=>_LeaderboardsPageState(); }
class _LeaderboardsPageState extends State<LeaderboardsPage>{ @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text('Leaderboards')), body: const Center(child: Text('Scores stored locally on device.'))); }
