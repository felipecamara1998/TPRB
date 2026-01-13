import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> pickExcelBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;

  if (bytes == null || bytes.isEmpty) {
    throw Exception(
      'Could not read file bytes. '
          'Try updating file_picker or run on Chrome.',
    );
  }

  return bytes;
}
