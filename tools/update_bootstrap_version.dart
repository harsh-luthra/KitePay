import 'dart:io';

void main() {
  final indexFile = File('build/web/index.html');

  if (!indexFile.existsSync()) {
    print('❌ index.html not found. Make sure you run `flutter build web` first.');
    return;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final content = indexFile.readAsStringSync();

  final newContent = content.replaceAllMapped(
    RegExp(r'flutter_bootstrap\.js(\?v=\d+)?'),
        (_) => 'flutter_bootstrap.js?v=$timestamp',
  );

  indexFile.writeAsStringSync(newContent);
  print('✅ flutter_bootstrap.js updated with version ?v=$timestamp');
}
