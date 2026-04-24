import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/services/watermark_service.dart');
  String content = file.readAsStringSync(encoding: const Utf8Codec(allowMalformed: true));
  
  // Glassmorphism background
  content = content.replaceFirst('..color = Colors.black.withValues(alpha: 0.74)', 
'''..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Colors.black.withValues(alpha: 0.45),
          Colors.black.withValues(alpha: 0.75),
        ],
      )''');
      
  // Border
  if (!content.contains('borderPaint')) {
    content = content.replaceFirst('..style = PaintingStyle.fill;', '..style = PaintingStyle.fill;\n\n    final Paint borderPaint = Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.0;');
    content = content.replaceFirst('canvas.drawRRect(panel, bgPaint);', 'canvas.drawRRect(panel, bgPaint);\n    canvas.drawRRect(panel, borderPaint);');
    content = content.replaceFirst('const Radius.circular(24)', 'const Radius.circular(20)');
  }
  
  // Emojis
  content = content.replaceAll("'? \${measured.temperatureLabel}'", "'☁️ \${measured.temperatureLabel}'");
  content = content.replaceAll("'?? \${measured.windLabel}'", "'💨 \${measured.windLabel}'");
  content = content.replaceAll("'? UV \${measured.uvLabel}'", "'☀️ UV \${measured.uvLabel}'");
  
  content = content.replaceAll(RegExp(r"'\?\? Dirección no disponible'"), "'📍 Dirección no disponible'");
  content = content.replaceAll(RegExp(r"'\?\? \$\{parts\.join\(''', '''\)\}'"), "'📍 \${parts.join(', ')}'");
  content = content.replaceAll(RegExp(r"'\? Lat \$\{_coordValue\(safeLocation\?\.latitude\)\}, Long \$\{_coordValue\(safeLocation\?\.longitude\)\}'"), "'🎯 Lat \${_coordValue(safeLocation?.latitude)}, Long \${_coordValue(safeLocation?.longitude)}'");
  content = content.replaceAll(RegExp(r"'\? \$\{_dateLabel\(date\)\}  \$timezoneLabel'"), "'🕒 \${_dateLabel(date)}  \$timezoneLabel'");
  
  // Latin characters
  content = content.replaceAll('Direccin', 'Dirección');
  content = content.replaceAll('Ubicacin', 'Ubicación');
  content = content.replaceAll('C', '°C');

  file.writeAsStringSync(content);
  print('Done!');
}
