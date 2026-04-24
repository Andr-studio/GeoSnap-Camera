import 'dart:io';

void main() {
  final file = File('lib/services/watermark_service.dart');
  var bytes = file.readAsBytesSync();
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    bytes = bytes.sublist(3);
    file.writeAsBytesSync(bytes);
    print('Removed BOM');
  } else {
    print('No BOM found');
  }
}
