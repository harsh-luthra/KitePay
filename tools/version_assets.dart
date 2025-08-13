// version_assets.dart
import 'dart:io';

void main() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  // 1. Update index.html
  final indexPath = 'build/web/index.html';
  final indexFile = File(indexPath);

  if (!indexFile.existsSync()) {
    print('❌ index.html not found.');
    return;
  }

  var indexContent = indexFile.readAsStringSync();
  indexContent = indexContent.replaceAllMapped(
    RegExp(r'flutter_bootstrap\.js(\?v=\d+)?'),
    (_) => 'flutter_bootstrap.js?v=$timestamp',
  );
  indexFile.writeAsStringSync(indexContent);
  print('✅ index.html updated: flutter_bootstrap.js?v=$timestamp');

  // 2. Update flutter_bootstrap.js to version main.dart.js
  final bootstrapPath = 'build/web/flutter_bootstrap.js';
  final bootstrapFile = File(bootstrapPath);

  if (bootstrapFile.existsSync()) {
    var bootstrapContent = bootstrapFile.readAsStringSync();
    bootstrapContent = bootstrapContent.replaceAllMapped(
      RegExp(r'main\.dart\.js(\?v=\d+)?'),
      (_) => 'main.dart.js?v=$timestamp',
    );
    bootstrapFile.writeAsStringSync(bootstrapContent);
    print('✅ flutter_bootstrap.js updated: main.dart.js?v=$timestamp');
  } else {
    print('⚠ flutter_bootstrap.js not found.');
  }
}
