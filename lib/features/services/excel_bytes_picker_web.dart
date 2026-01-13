// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<Uint8List?> pickExcelBytes() async {
  final input = html.FileUploadInputElement()
    ..accept = '.xlsx'
    ..multiple = false;

  input.click();

  // aguarda seleção do arquivo (ou cancelamento)
  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) return null;

  final file = files.first;

  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();

  reader.onLoadEnd.listen((_) {
    final result = reader.result;

    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }

    // alguns browsers retornam Uint8List diretamente
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }

    completer.completeError(
      Exception('Could not read file as ArrayBuffer. Reader result: ${result.runtimeType}'),
    );
  });

  reader.onError.listen((_) {
    completer.completeError(Exception('FileReader error while reading file.'));
  });

  reader.readAsArrayBuffer(file);

  return completer.future;
}
