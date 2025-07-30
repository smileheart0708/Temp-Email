import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:email/models/email_message.dart';
import 'package:email/services/providers/apiok_provider.dart';
import 'package:email/services/providers/base_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import 'log_service.dart';
import 'haptic_service.dart';

enum EmailGenerationStatus { initial, loading, success, failure }

/// DTO to hold the state for email generation.
class EmailGenerationState {
  final EmailGenerationStatus status;
  final String? email;
  final String? errorMessage;

  EmailGenerationState({
    this.status = EmailGenerationStatus.initial,
    this.email,
    this.errorMessage,
  });
}

/// 管理与临时电子邮件相关的所有业务逻辑和状态的服务。
class EmailService {
  EmailService._();

  /// 服务的单例实例。
  static final EmailService instance = EmailService._();

  final _storage = StorageService.instance;
  final _logger = LogService.instance;
  final _hapticService = HapticService.instance;
  final EmailProvider _provider = ApiOkProvider();

  // --- State Notifiers for Email Generation ---
  final ValueNotifier<EmailGenerationState> emailState =
      ValueNotifier(EmailGenerationState());
  final ValueNotifier<String?> emailId = ValueNotifier(null);

  // --- State Notifiers for Message List ---
  final ValueNotifier<List<EmailMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isFetchingMessages = ValueNotifier(false);
  final ValueNotifier<String?> fetchMessagesError = ValueNotifier(null);

  // --- State Notifiers for a single message detail ---
  final ValueNotifier<bool> isFetchingDetails = ValueNotifier(false);
  final ValueNotifier<String?> fetchDetailsError = ValueNotifier(null);

  // A simple notifier to trigger a refresh in the UI.
  // The UI will listen to this and call the appropriate refresh logic.
  final ValueNotifier<int> refreshTrigger = ValueNotifier(0);

  /// Triggers a UI refresh for the mail list.
  void triggerMailListRefresh() {
    _hapticService.lightImpact();
    refreshTrigger.value++;
  }

  /// Refreshes the mail list.
  /// This is the primary method for the UI to call to get messages.
  Future<void> refreshMessages() async {
    final currentEmailId = emailId.value;
    if (currentEmailId == null) return;

    isFetchingMessages.value = true;
    fetchMessagesError.value = null;

    try {
      final apiKey = await _getApiKeyOrThrow();
      final fetchedMessages = await _provider.getMessages(apiKey, currentEmailId);
      messages.value = fetchedMessages;
    } catch (e) {
      final errorMessage = '获取邮件列表失败: ${e.toString().replaceAll('Exception: ', '')}';
      fetchMessagesError.value = errorMessage;
      await _logger.logError(errorMessage);
    } finally {
      isFetchingMessages.value = false;
    }
  }

  /// Gets the details for a message, using cache if available.
  Future<File> getAndCacheMessageDetails(String messageId) async {
    isFetchingDetails.value = true;
    fetchDetailsError.value = null;

    try {
      final emailsDir = await _getEmailsDirectory();
      final cachedFile = File('${emailsDir.path}/$messageId.html');

      if (await cachedFile.exists()) {
        return cachedFile;
      }

      final apiKey = await _getApiKeyOrThrow();
      final htmlContent = await _provider.getMessageDetail(apiKey, messageId);

      await cachedFile.writeAsString(htmlContent);
      // Clean up old cache files after saving a new one.
      await _manageCache();
      return cachedFile;
    } catch (e) {
      final errorMessage = '加载邮件详情失败: ${e.toString().replaceAll('Exception: ', '')}';
      fetchDetailsError.value = errorMessage;
      await _logger.logError(errorMessage);
      throw Exception(errorMessage); // Re-throw to be caught by UI if needed
    } finally {
      isFetchingDetails.value = false;
    }
  }

  Future<String> _getApiKeyOrThrow() async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('未在设置中找到API密钥');
    }
    return apiKey;
  }

Future<Directory> _getEmailsDirectory() async {
  Directory? baseDir;
  // 首先尝试获取外部缓存目录，这是安卓系统推荐的缓存位置。
  try {
    final externalCacheDirs = await getExternalCacheDirectories();
    if (externalCacheDirs != null && externalCacheDirs.isNotEmpty) {
      // 使用第一个外部缓存目录，这通常是主存储。
      baseDir = externalCacheDirs.first;
    }
  } catch (e) {
    // 在非安卓平台或权限问题时可能会失败。
    await _logger.logError('获取外部缓存目录失败: $e');
  }

  // 如果无法获取外部缓存目录，则回退到应用的内部临时目录。
  baseDir ??= await getTemporaryDirectory();

  final emailsDir = Directory('${baseDir.path}/email');
  if (!await emailsDir.exists()) {
    await emailsDir.create(recursive: true);
  }
  return emailsDir;
}

  Future<void> _manageCache({int maxCacheFiles = 20}) async {
    final emailsDir = await _getEmailsDirectory();
    final files = (await emailsDir.list().toList()).whereType<File>().toList();

    if (files.length > maxCacheFiles) {
      files.sort((a, b) {
        try {
          return a.statSync().modified.compareTo(b.statSync().modified);
        } catch (e) {
          return 0;
        }
      });

      final filesToDelete = files.length - maxCacheFiles;
      for (int i = 0; i < filesToDelete; i++) {
        try {
          await files[i].delete();
        } catch (e) {
          // Ignore
        }
      }
    }
  }

  /// 获取一个新的临时电子邮件地址。
  /// 这是获取邮件的主要入口点，由UI或后台服务调用。
  Future<void> getTempEmail() async {
    _hapticService.lightImpact();
    emailState.value = EmailGenerationState(status: EmailGenerationStatus.loading);
    // 在获取新邮件之前清除旧邮件
    emailId.value = null;
    messages.value = []; // Also clear previous messages

    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      emailState.value = EmailGenerationState(
        status: EmailGenerationStatus.failure,
        errorMessage: '请先在设置页面配置 API 密钥',
      );
      return;
    }

    final customUrl = await _storage.getRequestUrl();
    const defaultUrl = 'https://apiok.us/api/cbea/generate/v1';
    String? finalError;

    // 首先尝试自定义地址
    if (customUrl != null && customUrl.isNotEmpty) {
      try {
        await _performApiRequest(customUrl, apiKey);
        // The state will be set to success inside _performApiRequest
        return; // 成功，直接返回
      } catch (e) {
        finalError = '自定义地址请求失败: $e';
        await _logger.logError(finalError);
        // 失败后继续尝试默认地址
      }
    }

    // 如果自定义地址失败或未设置，则尝试默认地址
    try {
      await _performApiRequest(defaultUrl, apiKey);
    } catch (e) {
      finalError = finalError == null
          ? '请求失败: $e'
          : '$finalError\n默认地址也请求失败: $e';
      await _logger.logError('Default URL request failed: $e');
      emailState.value = EmailGenerationState(
        status: EmailGenerationStatus.failure,
        errorMessage: finalError.replaceAll('Exception: ', ''),
      );
    }
  }

  /// 执行实际的API请求。
  Future<void> _performApiRequest(String urlString, String apiKey) async {
    final url =
        Uri.parse(urlString).replace(queryParameters: {'apikey': apiKey});
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final apiCode = data['code'];

        if (apiCode == 0) {
          if (data['result'] != null) {
            final emailResult = data['result']['email'] as String?;
            emailId.value = data['result']['id'] as String?;
            emailState.value = EmailGenerationState(
              status: EmailGenerationStatus.success,
              email: emailResult,
            );
          } else {
            throw Exception('API响应成功但缺少数据');
          }
        } else if (apiCode == 1001) {
          throw Exception('API密钥不正确或已失效，请在设置中检查');
        } else {
          throw Exception(data['msg'] ?? 'API返回未知错误 (code: $apiCode)');
        }
      } on FormatException catch (e) {
        // Log the detailed error for debugging.
        await _logger.logError(
            'JSON parsing failed for URL: $urlString. Error: $e. Response Body: ${response.body}');
        // Throw a user-friendly error to be displayed in the UI.
        throw Exception('无法解析服务器响应');
      }
    } else {
      throw Exception('服务器错误，状态码: ${response.statusCode}');
    }
  }
  
  /// 清理资源。
  void dispose() {
    emailState.dispose();
    emailId.dispose();
    refreshTrigger.dispose();
    messages.dispose();
    isFetchingMessages.dispose();
    fetchMessagesError.dispose();
    isFetchingDetails.dispose();
    fetchDetailsError.dispose();
  }
} 