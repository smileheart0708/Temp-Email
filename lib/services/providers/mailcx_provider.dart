import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/email_message.dart';
import '../log_service.dart';
import 'base_provider.dart';

/// An implementation of [EmailProvider] for the 'mail.cx' service.
///
/// This provider uses a temporary authorization token instead of a persistent API key.
class MailcxProvider implements EmailProvider {
  static const String _apiBaseUrl = 'https://api.mail.cx/api/v1';
  static const String _authTokenUrl = '$_apiBaseUrl/auth/authorize_token';

  final _logger = LogService.instance;
  String? _token;
  DateTime? _tokenExpiry;

  /// Fetches a temporary authorization token from the mail.cx API.
  ///
  /// The token is cached for 5 minutes to avoid excessive requests.
  Future<String?> _getAuthToken() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token;
    }

    try {
      final response = await http.post(
        Uri.parse(_authTokenUrl),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer undefined',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        // The response body is a plain string, strip quotes and whitespace.
        _token = response.body.replaceAll('"', '').trim();
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 5));
        return _token;
      } else {
        throw Exception(
            'Failed to get auth token (Status: ${response.statusCode})');
      }
    } catch (e) {
      // Log the error or handle it as needed
      _logger.logError('Error getting auth token: $e');
      rethrow;
    }
  }

  @override
  Future<List<EmailMessage>> getMessages(String apiKey, String emailId) async {
    // The 'apiKey' parameter is ignored for this provider.
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Could not retrieve authorization token.');
    }

    final url = Uri.parse('$_apiBaseUrl/mailbox/$emailId');
    final response = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((m) => EmailMessage.fromJson(m)).toList();
    } else {
      throw Exception('Failed to load messages (Status: ${response.statusCode})');
    }
  }

  @override
  Future<String> getMessageDetail(String apiKey, String messageId) async {
    // The 'apiKey' parameter is ignored. 'messageId' should be in the format 'emailId/mailId'.
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Could not retrieve authorization token.');
    }

    final url = Uri.parse('$_apiBaseUrl/mailbox/$messageId/source');
    final response = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception(
          'Failed to load message detail (Status: ${response.statusCode})');
    }
  }
}