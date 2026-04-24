import 'dart:io';

void main() {
  final file = File('lib/services/watermark_service.dart');
  String content = file.readAsStringSync();
  
  // Revert all erroneous replacements
  content = content.replaceAll('°C', 'C');
  
  // Only add degree to the temperature label
  content = content.replaceAll("' \${location.temperatureC.toStringAsFixed(1)} C'", "' \${location.temperatureC.toStringAsFixed(1)} °C'");
  
  file.writeAsStringSync(content);
  print('Done fixing C!');
}
