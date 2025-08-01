import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/email_message.dart';
import 'base_provider.dart';

/// An implementation of [EmailProvider] for the 'idataiver.com' service.
class IdataiverProvider implements EmailProvider {
  // Note: The URLs are kept from the original 'apiok.us' as per the code.
  // If the service URL also changes, these should be updated.
  static const String _messagesUrl = 'https://apiok.us/api/cbea/messages/v1';
  static const String _messageDetailUrl =
      'https://apiok.us/api/cbea/message/detail/v1';

  @override
  Future<List<EmailMessage>> getMessages(String apiKey, String emailId) async {
    final url = Uri.parse(_messagesUrl)
        .replace(queryParameters: {'apikey': apiKey, 'id': emailId});

    final response = await http.get(url).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 0 && data['result']['messages'] != null) {
        final List messages = data['result']['messages'];
        return messages.map((m) => EmailMessage.fromJson(m)).toList();
      } else if (data['code'] == 1001) {
        throw Exception('API密钥不正确或已失效');
      } else {
        // Return an empty list for other API-level "errors" that aren't exceptions
        return [];
      }
    } else {
      throw Exception('无法连接到服务器 (状态码: ${response.statusCode})');
    }
  }

  @override
  Future<String> getMessageDetail(String apiKey, String messageId) async {
    final url = Uri.parse(_messageDetailUrl)
        .replace(queryParameters: {'apikey': apiKey, 'id': messageId});
    final response = await http.get(url).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 0 && data['result']['content'] != null) {
        return data['result']['content'] as String;
      } else if (data['code'] == 1001) {
        throw Exception('API密钥不正确或已失效');
      } else {
        throw Exception('获取邮件详情失败 (Code: ${data['code']})');
      }
    } else {
      throw Exception('服务器连接失败 (状态码: ${response.statusCode})');
    }
  }
} 