import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/utils/media_path_helper.dart';

class NoteDrawingPage extends StatefulWidget {
  const NoteDrawingPage({super.key});

  @override
  State<NoteDrawingPage> createState() => _NoteDrawingPageState();
}

class _NoteDrawingPageState extends State<NoteDrawingPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();
  final List<Offset?> _points = <Offset?>[];
  Color _color = Colors.indigo;
  double _stroke = 4;

  Future<void> _save() async {
    final RenderRepaintBoundary? boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      return;
    }
    final String path = await MediaPathHelper.nextPath(folder: 'drawings', extension: 'png');
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    if (mounted) {
      Navigator.of(context).pop(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear',
            onPressed: () => setState(_points.clear),
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                for (final Color c in <Color>[Colors.indigo, Colors.red, Colors.teal, Colors.black])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: c,
                        child: _color == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    ),
                  ),
                const Spacer(),
                const Text('Stroke'),
                Slider(
                  value: _stroke,
                  min: 2,
                  max: 12,
                  onChanged: (double v) => setState(() => _stroke = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                key: _canvasKey,
                color: Colors.white,
                child: GestureDetector(
                  onPanUpdate: (DragUpdateDetails details) {
                    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box == null) {
                      return;
                    }
                    setState(() => _points.add(box.globalToLocal(details.globalPosition)));
                  },
                  onPanEnd: (_) => setState(() => _points.add(null)),
                  child: CustomPaint(
                    painter: _SketchPainter(points: _points, color: _color, strokeWidth: _stroke),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({required this.points, required this.color, required this.strokeWidth});

  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      final Offset? a = points[i];
      final Offset? b = points[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
