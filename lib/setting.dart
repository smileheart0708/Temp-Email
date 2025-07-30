import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/haptic_service.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'package:email/services/theme_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _logService = LogService.instance;
  late Future<String> _logContentFuture;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    if (mounted) {
      setState(() {
        _logContentFuture = _logService.readLog();
      });
    }
  }

  void _showClearConfirmDialog() {
    HapticService.instance.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认清空'),
          content: const Text('您确定要清空所有错误日志吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                HapticService.instance.lightImpact();
                await _logService.clearLog();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _loadLogs(); // Refresh the view
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('确认清空'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错误日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _showClearConfirmDialog,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _logContentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorText = '加载日志失败: ${snapshot.error}';
            // Avoid getting into a logging loop if logging itself fails.
            // We just display the error here.
            return Center(child: Text(errorText));
          }
          final logContent = snapshot.data ?? '日志文件为空或不存在。';
          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(logContent),
            ),
          );
        },
      ),
    );
  }
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final _apiKeyNotifier = ValueNotifier<String?>(null);
  final _requestUrlNotifier = ValueNotifier<String?>(null);

  final _storage = StorageService.instance;
  final _hapticService = HapticService.instance;
  final _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
    _hapticService.addListener(_onHapticSettingsChanged);
    _themeService.addListener(_onThemeSettingsChanged);
  }

  Future<void> _loadInitialSettings() async {
    _apiKeyNotifier.value = await _storage.getApiKey();
    _requestUrlNotifier.value = await _storage.getRequestUrl();
  }

  @override
  void dispose() {
    _apiKeyNotifier.dispose();
    _requestUrlNotifier.dispose();
    _hapticService.removeListener(_onHapticSettingsChanged);
    _themeService.removeListener(_onThemeSettingsChanged);
    super.dispose();
  }

  void _onHapticSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeSettingsChanged() {
    if (mounted) setState(() {});
  }

  // --- Generic Dialogs for Refactoring ---

  void _showInputDialog({
    required String title,
    required String label,
    required String hint,
    required Future<void> Function(String) onSave,
    Widget? extraContent,
  }) {
    _hapticService.lightImpact();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (extraContent != null) ...[
                const SizedBox(height: 16),
                extraContent,
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.isEmpty) return;
                await onSave(controller.text);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    _hapticService.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () {
                _hapticService.lightImpact();
                onConfirm();
                // No need to check mounted here, as the pop is synchronous
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  // --- Setting Handlers ---

  Future<void> _launchApiKeyUrl() async {
    final url = Uri.parse('https://www.idatariver.com/zh-cn/console/apikeys');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      LogService.instance.logError('Could not launch $url');
    }
  }

  Future<void> _saveRequestUrl(String url) async {
    await _storage.saveRequestUrl(url);
    _requestUrlNotifier.value = url;
  }

  Future<void> _deleteRequestUrl() async {
    await _storage.deleteRequestUrl();
    _requestUrlNotifier.value = null;
  }

  Future<void> _saveApiKey(String apiKey) async {
    await _storage.saveApiKey(apiKey);
    _apiKeyNotifier.value = apiKey;
  }

  Future<void> _deleteApiKey() async {
    await _storage.deleteApiKey();
    _apiKeyNotifier.value = null;
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: <Widget>[
        _buildSectionTitle(context, '界面设置'),
        const SizedBox(height: 12),
        _buildThemeModeSetting(),
        const SizedBox(height: 12),
        _buildDynamicColorSetting(),
        const SizedBox(height: 12),
        _buildHapticFeedbackSetting(),
        const SizedBox(height: 32),
        _buildApiSection(context),
        const SizedBox(height: 32),
        _buildAdvancedSection(context),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildThemeModeSetting() {
    final themeOptions = {
      ThemeMode.system: '跟随系统',
      ThemeMode.light: '浅色模式',
      ThemeMode.dark: '深色模式',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: themeOptions.entries.map((entry) {
          return RadioListTile<ThemeMode>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: _themeService.themeMode,
            onChanged: (value) {
              if (value != null) {
                _themeService.setThemeMode(value);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDynamicColorSetting() {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        title: const Text('动态取色'),
        subtitle: Text('在支持的设备上，根据壁纸颜色生成应用主题色', style: subtitleStyle),
        value: _themeService.useDynamicColor,
        onChanged: (enabled) {
          _themeService.setUseDynamicColor(enabled);
        },
      ),
    );
  }

  Widget _buildHapticFeedbackSetting() {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        title: const Text('触感反馈'),
        subtitle: Text('与界面元素交互时震动', style: subtitleStyle),
        value: _hapticService.isEnabled,
        onChanged: (value) => _hapticService.setEnabled(value),
      ),
    );
  }

  Widget _buildApiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'API 设置'),
        const SizedBox(height: 12),
        _buildRequestUrlCard(context),
        const SizedBox(height: 12),
        _buildApiKeyCard(context),
      ],
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '高级'),
        const SizedBox(height: 12),
        _buildLogCard(context),
      ],
    );
  }

  Widget _buildLogCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('错误日志'),
        subtitle: Text('查看和管理应用错误记录', style: subtitleStyle),
        onTap: () {
          _hapticService.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogViewerScreen()),
          );
        },
      ),
    );
  }

  Widget _buildRequestUrlCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: ValueListenableBuilder<String?>(
        valueListenable: _requestUrlNotifier,
        builder: (context, url, child) {
          if (url != null) {
            return ListTile(
              title: const Text('请求地址'),
              subtitle: Text(
                url,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
              trailing: TextButton(
                onPressed: () => _showConfirmationDialog(
                  title: '确认重置',
                  content: '您确定要重置请求地址吗？将会使用应用内置的默认地址。',
                  confirmText: '确认重置',
                  onConfirm: _deleteRequestUrl,
                ),
                child: const Text('重置'),
              ),
            );
          } else {
            return ListTile(
              title: const Text('请求地址'),
              subtitle: Text('未设置 (使用默认)', style: subtitleStyle),
              trailing: TextButton(
                onPressed: () => _showInputDialog(
                  title: '添加请求地址',
                  label: 'URL',
                  hint: '在此输入您的请求地址',
                  onSave: _saveRequestUrl,
                ),
                child: const Text('添加'),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildApiKeyCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: ValueListenableBuilder<String?>(
        valueListenable: _apiKeyNotifier,
        builder: (context, apiKey, child) {
          if (apiKey != null) {
            return ListTile(
              title: const Text('API 密钥'),
              subtitle: Text('已设置', style: subtitleStyle),
              trailing: TextButton(
                onPressed: () => _showConfirmationDialog(
                  title: '确认删除',
                  content: '您确定要删除已保存的 API 密钥吗？此操作不可撤销。',
                  confirmText: '确认删除',
                  onConfirm: _deleteApiKey,
                ),
                child: const Text('删除'),
              ),
            );
          } else {
            return ListTile(
              title: const Text('API 密钥'),
              subtitle: Text('未设置', style: subtitleStyle),
              trailing: TextButton(
                onPressed: () => _showInputDialog(
                  title: '添加 API 密钥',
                  label: 'API 密钥',
                  hint: '在此输入您的 API 密钥',
                  onSave: _saveApiKey,
                  extraContent: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        _hapticService.lightImpact();
                        _launchApiKeyUrl();
                      },
                      child: const Text('获取 API 密钥'),
                    ),
                  ),
                ),
                child: const Text('添加'),
              ),
            );
          }
        },
      ),
    );
  }
}
