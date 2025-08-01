import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:email/models/email_message.dart';
import 'package:email/services/providers/mailcx_provider.dart';
import 'package:email/services/providers/base_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import 'log_service.dart';
import 'haptic_service.dart';

enum EmailGenerationStatus { initial, loading, success, failure }

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

class EmailService {
  EmailService._() {
    _registerProviders();
    // Load settings from storage when the service is initialized.
    _loadSettings();
  }

  static final EmailService instance = EmailService._();

  final _storage = StorageService.instance;
  final _logger = LogService.instance;
  final _hapticService = HapticService.instance;

  // --- Provider Registry ---
  final Map<String, EmailProvider> _providers = {};

  void _registerProviders() {
    _providers['Mailcx'] = MailcxProvider();
  }

  // --- State Notifiers ---
  final ValueNotifier<EmailGenerationState> emailState =
      ValueNotifier(EmailGenerationState());
  final ValueNotifier<String?> emailId = ValueNotifier(null);
  final ValueNotifier<List<EmailMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isFetchingMessages = ValueNotifier(false);
  final ValueNotifier<String?> fetchMessagesError = ValueNotifier(null);
  final ValueNotifier<bool> isFetchingDetails = ValueNotifier(false);
  final ValueNotifier<String?> fetchDetailsError = ValueNotifier(null);
  final ValueNotifier<int> refreshTrigger = ValueNotifier(0);

  // --- Suffix Pool and Selection Strategy State ---
  List<String> _activeSuffixPool = [];
  String _selectionMode = 'fixed';
  String? _fixedSelection;
  int _sequentialIndex = 0;
  List<String> _randomPool = [];

  Future<void> _loadSettings() async {
    // This method should be called from the settings page whenever a setting changes.
    // For now, it's called on init.
    _selectionMode = await _storage.getSuffixSelectionMode();
    _fixedSelection = await _storage.getFixedSuffixSelection();

    // In a real app, you'd load the enabled suffixes for each provider
    // and build the active pool. For now, we'll assume some defaults.
    // This will be properly managed by the settings page later.
    final mailCxSuffixes = (await _storage.getProviderSuffixes('Mailcx'))
            ?.where((s) => s['isEnabled'] as bool? ?? true)
            .map((s) => s['value'] as String)
            .toList() ??
        ['qabq.com', 'nqmo.com', 'end.tw', 'uuf.me', '6n9.net'];

    _activeSuffixPool = {...mailCxSuffixes}.toList()..sort();
    
    if (_activeSuffixPool.isNotEmpty && _fixedSelection == null) {
      _fixedSelection = _activeSuffixPool.first;
      await _storage.saveFixedSuffixSelection(_fixedSelection!);
    }
  }

  /// Reloads settings from storage. Should be called when settings change.
  Future<void> reloadSettings() async {
    await _loadSettings();
  }

  String _selectNextSuffix() {
    if (_activeSuffixPool.isEmpty) {
      throw Exception('没有可用的邮箱后缀名');
    }

    switch (_selectionMode) {
      case 'random':
        if (_randomPool.isEmpty) {
          _randomPool = List.from(_activeSuffixPool)..shuffle();
        }
        return _randomPool.removeLast();
      case 'sequential':
        final suffix = _activeSuffixPool[_sequentialIndex];
        _sequentialIndex = (_sequentialIndex + 1) % _activeSuffixPool.length;
        return suffix;
      case 'fixed':
      default:
        return _fixedSelection ?? _activeSuffixPool.first;
    }
  }

  String _generateRandomUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final length = 8 + random.nextInt(5); // 8-12 chars
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> getTempEmail() async {
    _hapticService.lightImpact();
    emailState.value = EmailGenerationState(status: EmailGenerationStatus.loading);
    emailId.value = null;
    messages.value = [];

    try {
      await reloadSettings(); // Ensure we have the latest settings
      final suffix = _selectNextSuffix();
      final username = _generateRandomUsername();
      final newEmail = '$username@$suffix';

      // The concept of a single API call to "generate" an email is gone.
      // The email is now constructed locally. We just need to set the state.
      emailId.value = newEmail; // The full email is now the ID
      emailState.value = EmailGenerationState(
        status: EmailGenerationStatus.success,
        email: newEmail,
      );
    } catch (e) {
      final errorMessage = '生成邮箱失败: ${e.toString().replaceAll('Exception: ', '')}';
      await _logger.logError(errorMessage);
      emailState.value = EmailGenerationState(
        status: EmailGenerationStatus.failure,
        errorMessage: errorMessage,
      );
    }
  }

  EmailProvider _getProviderForEmail(String email) {
    // Since we only have one provider now, we can just return it.
    return _providers['Mailcx']!;
  }

  Future<void> refreshMessages() async {
    final currentEmailId = emailId.value;
    if (currentEmailId == null) return;

    isFetchingMessages.value = true;
    fetchMessagesError.value = null;

    try {
      final provider = _getProviderForEmail(currentEmailId);
      // The apiKey is no longer needed as MailcxProvider ignores it.
      final fetchedMessages = await provider.getMessages('', currentEmailId);
      messages.value = fetchedMessages;
    } catch (e) {
      final errorMessage = '获取邮件列表失败: ${e.toString().replaceAll('Exception: ', '')}';
      fetchMessagesError.value = errorMessage;
      await _logger.logError(errorMessage);
    } finally {
      isFetchingMessages.value = false;
    }
  }

  Future<File> getAndCacheMessageDetails(String messageId) async {
    isFetchingDetails.value = true;
    fetchDetailsError.value = null;
    final currentEmail = emailId.value;
    if (currentEmail == null) {
      throw Exception('无法获取邮件详情，因为当前没有邮箱地址。');
    }

    try {
      final emailsDir = await _getEmailsDirectory();
      final fullMessageId = '$currentEmail-$messageId';
      final cachedFile = File('${emailsDir.path}/$fullMessageId.html');

      if (await cachedFile.exists()) {
        return cachedFile;
      }

      final provider = _getProviderForEmail(currentEmail);
      // The apiKey is no longer needed.
      // For Mailcx, the messageId needs to be 'email/mailId'
      final providerMessageId = '$currentEmail/$messageId';

      final htmlContent = await provider.getMessageDetail('', providerMessageId);

      await cachedFile.writeAsString(htmlContent);
      await _manageCache();
      return cachedFile;
    } catch (e) {
      final errorMessage = '加载邮件详情失败: ${e.toString().replaceAll('Exception: ', '')}';
      fetchDetailsError.value = errorMessage;
      await _logger.logError(errorMessage);
      throw Exception(errorMessage);
    } finally {
      isFetchingDetails.value = false;
    }
  }

  // --- Helper and Cleanup Methods ---

  void triggerMailListRefresh() {
    _hapticService.lightImpact();
    refreshTrigger.value++;
  }

  Future<Directory> _getEmailsDirectory() async {
    Directory? baseDir;
    try {
      final externalCacheDirs = await getExternalCacheDirectories();
      if (externalCacheDirs != null && externalCacheDirs.isNotEmpty) {
        baseDir = externalCacheDirs.first;
      }
    } catch (e) {
      await _logger.logError('获取外部缓存目录失败: $e');
    }
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
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
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