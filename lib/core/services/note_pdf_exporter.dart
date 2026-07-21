import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../features/notes/domain/note.dart';

class NotePdfExporter {
  Future<void> shareNotePdf(Note note) async {
    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(note.title.isEmpty ? 'Untitled note' : note.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (note.folder != null) pw.Text('Folder: ${note.folder}'),
          if (note.tags.isNotEmpty) pw.Text('Tags: ${note.tags.join(', ')}'),
          pw.SizedBox(height: 16),
          pw.Text(note.content, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );

    final Directory dir = await getTemporaryDirectory();
    final String safeName = note.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final File file = File('${dir.path}/${safeName.isEmpty ? 'lifeos_note' : safeName}.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(file.path)], subject: note.title, text: 'LIFEOS AI note export'),
    );
  }
}
