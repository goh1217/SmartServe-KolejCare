// Stub implementation for non-web platforms

void openUrlInNewTab(String url) {
  // Not supported on mobile - would use url_launcher package instead
  throw UnsupportedError('Opening URLs in new tab is not supported on this platform');
}

String getCurrentUrl() {
  return 'http://localhost'; // Fallback for mobile
}
