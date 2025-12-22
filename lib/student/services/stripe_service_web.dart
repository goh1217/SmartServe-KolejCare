// Web-specific implementation
import 'dart:html' as html;

void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

String getCurrentUrl() {
  return html.window.location.origin ?? 'http://localhost';
}
