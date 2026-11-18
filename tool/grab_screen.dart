import 'dart:io';

void main() async {
  final process = await Process.start('adb', [
    '-s', 'adb-10BD2A1J060005K-0deTd3._adb-tls-connect._tcp',
    'exec-out', 'screencap', '-p'
  ]);
  final file = File(r'C:\Users\Admin\.gemini\antigravity\brain\6a70608a-fce3-44b2-886a-e7ace0f244c1\current_app_screen.png');
  await process.stdout.pipe(file.openWrite());
  print('Screenshot saved successfully');
}
