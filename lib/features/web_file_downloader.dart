// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadStringWeb(String content, String filename, String mimeType) {
  final bytes = utf8.encode(content);
  downloadFileWeb(bytes, filename, mimeType);
}
