import 'dart:io';

Future<double> measureDownloadSpeedMbps() async {
  final url = Uri.parse(
      'https://speed.cloudflare.com/__down?bytes=1000000'); // test file
  final stopwatch = Stopwatch()..start();
  final request = await HttpClient().getUrl(url);
  final response = await request.close();

  int totalBytes = 0;
  await for (var chunk in response) {
    totalBytes += chunk.length;
  }

  stopwatch.stop();
  final seconds = stopwatch.elapsedMilliseconds / 1000.0;
  final mbps = (totalBytes * 8 / 1e6) / seconds;

  // Round to 1 decimal place
  return double.parse(mbps.toStringAsFixed(1));
}
