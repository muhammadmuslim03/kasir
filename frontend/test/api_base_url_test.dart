import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses Android local development API fallbacks', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(
      resolveApiBaseUrlsForEnvironment(
        configuredUrl: '',
        isWeb: false,
        isReleaseMode: false,
        targetPlatform: defaultTargetPlatform,
        browserUri: Uri.parse('http://localhost:3000'),
      ),
      ['http://localhost:8080', 'http://10.0.2.2:8080'],
    );
  });

  test('uses localhost API on desktop by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(
      resolveApiBaseUrlsForEnvironment(
        configuredUrl: '',
        isWeb: false,
        isReleaseMode: false,
        targetPlatform: defaultTargetPlatform,
        browserUri: Uri.parse('http://localhost:3000'),
      ),
      ['http://localhost:8080'],
    );
  });

  test('uses configured production API URL', () {
    expect(
      resolveApiBaseUrlsForEnvironment(
        configuredUrl: ' https://api.kasir.example.com ',
        isWeb: true,
        isReleaseMode: true,
        targetPlatform: TargetPlatform.linux,
        browserUri: Uri.parse('https://kasir.example.com'),
      ),
      ['https://api.kasir.example.com'],
    );
  });

  test('requires configured API URL for web release builds', () {
    expect(
      resolveApiBaseUrlsForEnvironment(
        configuredUrl: '',
        isWeb: true,
        isReleaseMode: true,
        targetPlatform: TargetPlatform.linux,
        browserUri: Uri.parse('https://kasir.example.com'),
      ),
      isEmpty,
    );
  });
}
