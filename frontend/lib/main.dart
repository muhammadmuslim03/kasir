import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'view/app.dart';

const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

List<String> resolveApiBaseUrls() {
  return resolveApiBaseUrlsForEnvironment(
    configuredUrl: configuredApiBaseUrl,
    isWeb: kIsWeb,
    isReleaseMode: kReleaseMode,
    targetPlatform: defaultTargetPlatform,
    browserUri: Uri.base,
  );
}

@visibleForTesting
List<String> resolveApiBaseUrlsForEnvironment({
  required String configuredUrl,
  required bool isWeb,
  required bool isReleaseMode,
  required TargetPlatform targetPlatform,
  required Uri browserUri,
}) {
  final trimmedConfiguredUrl = configuredUrl.trim();
  if (trimmedConfiguredUrl.isNotEmpty) {
    return [trimmedConfiguredUrl];
  }

  if (isWeb && isReleaseMode) {
    return const [];
  }

  final urls = <String>[];
  void addUrl(String url) {
    if (!urls.contains(url)) {
      urls.add(url);
    }
  }

  if (isWeb &&
      (browserUri.scheme == 'http' || browserUri.scheme == 'https') &&
      browserUri.host.isNotEmpty) {
    addUrl('${browserUri.scheme}://${browserUri.host}:8080');
    addUrl('http://localhost:8080');
    return urls;
  }

  if (targetPlatform == TargetPlatform.android) {
    addUrl('http://localhost:8080');
    addUrl('http://10.0.2.2:8080');
    return urls;
  }

  addUrl('http://localhost:8080');
  return urls;
}

void main() {
  runApp(KasirWarungApp(apiBaseUrls: resolveApiBaseUrls()));
}
