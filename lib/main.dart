import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(HerethougApp());
}

class HerethougApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herethoug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: BoardScreen(),
    );
  }
}

class ThoughtCard {
  String id;
  String title;
  String body;
  double x;
  double y;
  int colorIndex;

  ThoughtCard({
    required this.id,
    required this.title,
    required this.body,
    required this.x,
    required this.y,
    required this.colorIndex,
  });

  factory ThoughtCard.fromJson(Map<String, dynamic> j) => ThoughtCard(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        colorIndex: j['colorIndex'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'x': x,
        'y': y,
        'colorIndex': colorIndex,
      };
}

class BoardScreen extends StatefulWidget {
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<ThoughtCard> cards = [];
  SharedPreferences? prefs;
  final storageKey = 'herethoug_cards_v1';

  final List<Color> pastelBlue = [
    Color(0xFFE3F2FD),
    Color(0xFFBBDEFB),
    Color(0xFFB3E5FC),
    Color(0xFFBEEFFF),
    Color(0xFFD5EDFF),
    Color(0xFFE8F7FF),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs!.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final arr = jsonDecode(raw) as List;
        setState(() {
          cards = arr.map((e) => ThoughtCard.fromJson(e)).toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _save() async {
    if (prefs == null) return;
    final raw = jsonEncode(cards.map((c) => c.toJson()).toList());
    await prefs!.setString(storageKey, raw);
  }

  void _addCard(Size boardSize) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final double w = 220, h = 120;
    final double centerX = (boardSize.width - w) / 2;
    final double centerY = (boardSize.height - h) / 2;
    final newCard = ThoughtCard(
      id: id,
      title: 'Новая мысль',
      body: '',
      x: centerX.clamp(8.0, boardSize.width - w - 8.0),
      y: centerY.clamp(8.0, boardSize.height - h - 8.0),
      colorIndex: cards.length % pastelBlue.length,
    );
    setState(() {
      cards.add(newCard);
    });
    _save();
  }

  void _updateCardPosition(String id, double x, double y) {
    final i = cards.indexWhere((c) => c.id == id);
    if (i == -1) return;
    setState(() {
      cards[i].x = x;
      cards[i].y = y;
    });
    _save();
  }

  void _openEditor(ThoughtCard card) async {
    final updated = await showModalBottomSheet<ThoughtCard>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CardEditor(card: card, colors: pastelBlue),
      ),
    );

    if (updated != null) {
      final i = cards.indexWhere((c) => c.id == updated.id);
      if (i != -1) {
        setState(() => cards[i] = updated);
        _save();
      }
    }
  }

  void _deleteCard(String id) {
    setState(() {
      cards.removeWhere((c) => c.id == id);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final boardSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Container(color: Colors.white),
            ...cards.map((c) {
              return Positioned(
                left: c.x,
                top: c.y,
                child: DraggableCard(
                  card: c,
                  color: pastelBlue[c.colorIndex % pastelBlue.length],
                  onDragEnd: (nx, ny) {
                    final newX = nx.clamp(8.0, boardSize.width - 236.0);
                    final newY = ny.clamp(8.0, boardSize.height - 136.0);
                    _updateCardPosition(c.id, newX, newY);
                  },
                  onTap: () => _openEditor(c),
                  onDelete: () => _deleteCard(c.id),
                ),
              );
            }).toList(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Text('Herethoug', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton(
                onPressed: () => _addCard(boardSize),
                child: Icon(Icons.add),
                tooltip: 'Добавить мысль',
              ),
            ),
          ],
        );
      }),
    );
  }
}

class DraggableCard extends StatefulWidget {
  final ThoughtCard card;
  final Color color;
  final void Function(double x, double y) onDragEnd;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DraggableCard({
    Key? key,
    required this.card,
    required this.color,
    required this.onDragEnd,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> {
  double dx = 0;
  double dy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => setState(() {
        dx += details.delta.dx;
        dy += details.delta.dy;
      }),
      onPanEnd: (_) {
        final newX = widget.card.x + dx;
        final newY = widget.card.y + dy;
        dx = 0;
        dy = 0;
        widget.onDragEnd(newX, newY);
      },
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: 220,
          constraints: BoxConstraints(minHeight: 110),
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.card.body,
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardEditor extends StatefulWidget {
  final ThoughtCard card;
  final List<Color> colors;

  const CardEditor({Key? key, required this.card, required this.colors}) : super(key: key);

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  late TextEditingController titleCtrl;
  late TextEditingController bodyCtrl;
  late int selectedColor;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.card.title);
    bodyCtrl = TextEditingController(text: widget.card.body);
    selectedColor = widget.card.colorIndex;
  }

  void _save() {
    final updated = ThoughtCard(
      id: widget.card.id,
      title: titleCtrl.text.trim().isEmpty ? 'Новая мысль' : titleCtrl.text.trim(),
      body: bodyCtrl.text.trim(),
      x: widget.card.x,
      y: widget.card.y,
      colorIndex: selectedColor,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal:16.0).copyWith(top:16,bottom:16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Редактировать мысль', style: TextStyle(fontSize:18,fontWeight: FontWeight.w700)),
                  Spacer(),
                  TextButton(onPressed: _save, child: Text('Готово')),
                ],
              ),
              SizedBox(height:8),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Заголовок',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              SizedBox(height:10),
              TextField(
                controller: bodyCtrl,
                decoration: InputDecoration(
                  hintText: 'Детали (коротко)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                maxLines: 4,
              ),
              SizedBox(height:12),
              Row(
                children: [
                  Text('Цвет'),
                  SizedBox(width:8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(widget.colors.length, (i){
                          final c = widget.colors[i];
                          final sel = i == selectedColor;
                          return GestureDetector(
                            onTap: () => setState(() => selectedColor = i),
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal:6),
                              width: sel?40:34,
                              height: sel?40:34,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(8),
                                border: sel?Border.all(color: Colors.black26,width:1.5):null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height:12),
            ],
          ),
        ),
      ),
    );
  }
}
