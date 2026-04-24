import 'dart:io';

void main() {
  final file = File('lib/services/watermark_service.dart');
  String content = file.readAsStringSync();
  
  if (content.startsWith('ï»¿')) {
    content = content.substring(3);
    print('Removed textual BOM');
  } else if (content.startsWith('\uFEFF')) {
    content = content.substring(1);
    print('Removed zero-width no-break space (BOM)');
  }
  
  // also check for literal replacement
  content = content.replaceAll('ï»¿', '');
  
  file.writeAsStringSync(content);
}
