import 'package:web/web.dart' as web;

const String apiBaseUrl = 'https://api.passmarketplace.com';

String get apiUrl {
  final host = web.window.location.hostname;
  if (host == 'localhost' || host == '127.0.0.1') {
    return 'http://localhost:3000';
  }
  return apiBaseUrl;
}
