import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_text_parser.dart';

class OcrService {
  Future<String> extractText(String imagePath) async {
    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  Future<ReceiptParseResult> scanReceipt(String imagePath) async {
    final String text = await extractText(imagePath);
    return ReceiptTextParser.parse(text);
  }
}
