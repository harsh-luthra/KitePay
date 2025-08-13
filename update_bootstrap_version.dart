import 'dart:io';

void main() {
  final indexPath = 'build/web/index.html';
  final file = File(indexPath);

  if (!file.existsSync()) {
    print('index.html not found.');
    return;
  }

  final content = file.readAsStringSync();
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  final updated = content.replaceAllMapped(
    RegExp(r'flutter_bootstrap\.js(\?v=\d+)?'),
    (_) => 'flutter_bootstrap.js?v=$timestamp',
  );

  file.writeAsStringSync(updated);
  print('Updated flutter_bootstrap.js to version ?v=$timestamp');
}
