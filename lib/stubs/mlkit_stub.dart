// ════════════════════════════════════════════════════════════════════════════
// mlkit_stub.dart — Web stub for google_mlkit_text_recognition
// On web the real ML Kit package cannot compile (it references native plugins).
// This stub provides the same class/enum names so smart_entry_screen.dart
// compiles on web without any changes.
// ════════════════════════════════════════════════════════════════════════════

enum TextRecognitionScript { latin }

class TextRecognizer {
  // ignore: unused_element
  TextRecognizer({TextRecognitionScript script = TextRecognitionScript.latin});
  Future<RecognizedText> processImage(InputImage image) async =>
      RecognizedText('', []);
  void close() {}
}

class RecognizedText {
  final String text;
  final List<dynamic> blocks;
  RecognizedText(this.text, this.blocks);
}

class InputImage {
  static InputImage fromFilePath(String path) => InputImage._();
  static InputImage fromBytes({
    required dynamic bytes,
    required dynamic metadata,
  }) => InputImage._();
  InputImage._();
}

class InputImageMetadata {
  final dynamic size, rotation, format;
  final int bytesPerRow;
  const InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });
}

class InputImageRotation {
  static const rotation0deg = InputImageRotation._();
  const InputImageRotation._();
}

class InputImageFormat {
  static const bgra8888 = InputImageFormat._();
  const InputImageFormat._();
}
