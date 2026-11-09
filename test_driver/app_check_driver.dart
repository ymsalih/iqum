import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 4),
  responseDataCallback: (data) async {
    await Directory('output').create(recursive: true);
    await File(
      'output/app-check-native-result.json',
    ).writeAsString(jsonEncode(data));
  },
);
