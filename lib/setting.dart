import 'package:email/models/email_provider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/haptic_service.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'package:email/services/theme_service.dart';
import 'package:email/services/email_service.dart';

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
  final _storage = StorageService.instance;
  final _hapticService = HapticService.instance;
  final _themeService = ThemeService.instance;
  final _emailService = EmailService.instance;

  // --- State Notifiers for new Email Service UI ---
  final _providers = ValueNotifier<List<EmailProviderModel>>([]);
  final _activeSuffixPool = ValueNotifier<List<String>>([]);
  final _selectionMode = ValueNotifier<String>('fixed');
  final _fixedSelection = ValueNotifier<String?>(null);

  // ExpansionTile controllers
  final Map<String, bool> _expansionState = {};

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    _themeService.addListener(_onThemeSettingsChanged);
    _hapticService.addListener(_onHapticSettingsChanged);
  }

  @override
  void dispose() {
    _providers.dispose();
    _activeSuffixPool.dispose();
    _selectionMode.dispose();
    _fixedSelection.dispose();
    _themeService.removeListener(_onThemeSettingsChanged);
    _hapticService.removeListener(_onHapticSettingsChanged);
    super.dispose();
  }

  void _onThemeSettingsChanged() => setState(() {});
  void _onHapticSettingsChanged() => setState(() {});

  Future<void> _loadAllSettings() async {
    // --- Load Provider Configurations ---
    final mailcxSuffixData = await _storage.getProviderSuffixes('Mailcx');

    final mailcxProvider = EmailProviderModel(
      name: 'Mailcx',
      requiresApiKey: false,
      suffixes: mailcxSuffixData?.map((d) => EmailSuffix.fromMap(d)).toList() ??
          [
            EmailSuffix(value: 'qabq.com'),
            EmailSuffix(value: 'nqmo.com'),
            EmailSuffix(value: 'end.tw'),
            EmailSuffix(value: 'uuf.me'),
            EmailSuffix(value: '6n9.net'),
          ],
    );

    _providers.value = [mailcxProvider];
    _expansionState['Mailcx'] = true; // Default Mailcx to be expanded

    // --- Load other settings ---
    _selectionMode.value = await _storage.getSuffixSelectionMode();
    _fixedSelection.value = await _storage.getFixedSuffixSelection();

    _updateActiveSuffixPool();
  }

  void _updateActiveSuffixPool() {
    final allEnabledSuffixes = _providers.value
        .expand((p) => p.suffixes)
        .where((s) => s.isEnabled)
        .map((s) => s.value)
        .toSet()
        .toList();

    allEnabledSuffixes.sort();
    _activeSuffixPool.value = allEnabledSuffixes;

    // --- Business Logic Checks ---
    // 1. Single Suffix Lock
    if (_activeSuffixPool.value.length <= 1) {
      _selectionMode.value = 'fixed';
      _storage.saveSuffixSelectionMode('fixed');
    }

    // 2. Ensure fixed selection is valid
    if (_fixedSelection.value == null ||
        !_activeSuffixPool.value.contains(_fixedSelection.value)) {
      _fixedSelection.value =
          _activeSuffixPool.value.isNotEmpty ? _activeSuffixPool.value.first : null;
      if (_fixedSelection.value != null) {
        _storage.saveFixedSuffixSelection(_fixedSelection.value!);
      }
    }
    setState(() {}); // Rebuild UI
  }

  Future<void> _toggleSuffix(String providerName, String suffixValue) async {
    _hapticService.lightImpact();
    final providerIndex =
        _providers.value.indexWhere((p) => p.name == providerName);
    if (providerIndex == -1) return;

    final provider = _providers.value[providerIndex];
    final suffixIndex = provider.suffixes.indexWhere((s) => s.value == suffixValue);
    if (suffixIndex == -1) return;

    final currentSuffix = provider.suffixes[suffixIndex];
    final isDisabling = currentSuffix.isEnabled;

    // Rule: Cannot disable the last active suffix
    if (isDisabling && _activeSuffixPool.value.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('必须至少保留一个启用的邮箱后缀名'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedSuffix = currentSuffix.copyWith(isEnabled: !isDisabling);
    final updatedSuffixes = List<EmailSuffix>.from(provider.suffixes)
      ..[suffixIndex] = updatedSuffix;

    final updatedProvider = provider.copyWith(suffixes: updatedSuffixes);
    _providers.value = List<EmailProviderModel>.from(_providers.value)
      ..[providerIndex] = updatedProvider;

    // Save the updated suffixes for this provider
    await _storage.saveProviderSuffixes(
        providerName, updatedSuffixes.map((s) => s.toMap()).toList());

    _updateActiveSuffixPool();
    // Tell EmailService to reload its settings
    await _emailService.reloadSettings();
  }


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: <Widget>[
        _buildSectionTitle(context, '个性化设置'),
        const SizedBox(height: 12),
        _buildThemeModeSetting(),
        const SizedBox(height: 12),
        _buildDynamicColorSetting(),
        const SizedBox(height: 12),
        _buildHapticFeedbackSetting(),
        const SizedBox(height: 32),
        _buildEmailServiceSection(context),
        const SizedBox(height: 32),
        _buildAdvancedSection(context),
      ],
    );
  }

  Widget _buildEmailServiceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '邮箱服务'),
        const SizedBox(height: 12),
        _buildSuffixModeCard(context),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<EmailProviderModel>>(
          valueListenable: _providers,
          builder: (context, providerList, child) {
            return Column(
              children: providerList
                  .map((p) => _buildProviderExpansionTile(context, p))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuffixModeCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('邮箱后缀名', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<String>>(
            valueListenable: _activeSuffixPool,
            builder: (context, pool, child) {
              final isLocked = pool.length <= 1;
              return SizedBox(
                width: double.infinity, // 平铺到整个页面宽度
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fixed', label: Text('固定')),
                    ButtonSegment(value: 'sequential', label: Text('顺序')),
                    ButtonSegment(value: 'random', label: Text('随机')),
                  ],
                  selected: {_selectionMode.value},
                  onSelectionChanged: isLocked
                      ? null
                      : (newSelection) {
                          _hapticService.lightImpact();
                          setState(() {
                            _selectionMode.value = newSelection.first;
                            _storage.saveSuffixSelectionMode(newSelection.first);
                          });
                        },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: _selectionMode,
            builder: (context, mode, child) {
              if (mode == 'fixed') {
                return ValueListenableBuilder<List<String>>(
                  valueListenable: _activeSuffixPool,
                  builder: (context, pool, child) {
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: pool.map((suffix) {
                        return ChoiceChip(
                          label: Text(suffix),
                          selected: _fixedSelection.value == suffix,
                          onSelected: (selected) {
                            if (selected) {
                              _hapticService.lightImpact();
                              setState(() {
                                _fixedSelection.value = suffix;
                                _storage.saveFixedSuffixSelection(suffix);
                              });
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                );
              } else {
                final text = mode == 'sequential'
                    ? '将按 A-Z 顺序循环使用所有已启用的后缀名。'
                    : '将从已启用的后缀名中随机抽取，无放回。';
                return Text(text, style: subtitleStyle);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderExpansionTile(
      BuildContext context, EmailProviderModel provider) {
    final title =
        provider.name == 'Mailcx' ? 'Mailcx' : provider.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: _expansionState[provider.name] ?? false,
        onExpansionChanged: (isExpanded) {
          setState(() {
            _expansionState[provider.name] = isExpanded;
          });
        },
        children: [
          ...provider.suffixes.map((suffix) {
            return SwitchListTile(
              title: Text(suffix.value),
              value: suffix.isEnabled,
              onChanged: (value) => _toggleSuffix(provider.name, suffix.value),
              dense: true,
            );
          }),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), // 添加水平内边距
      child: SizedBox(
        width: double.infinity, // 确保平铺到整个页面宽度
        child: SegmentedButton<ThemeMode>(
          segments: themeOptions.entries.map((entry) {
            return ButtonSegment<ThemeMode>(
              value: entry.key,
              label: Text(entry.value),
            );
          }).toList(),
          selected: {_themeService.themeMode},
          onSelectionChanged: (newSelection) {
            if (newSelection.isNotEmpty) {
              _themeService.setThemeMode(newSelection.first);
            }
          },
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicColorSetting() {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return SwitchListTile(
      title: const Text('动态取色'),
      subtitle: Text('在支持的设备上，根据壁纸颜色生成应用主题色', style: subtitleStyle),
      value: _themeService.useDynamicColor,
      onChanged: (enabled) {
        _themeService.setUseDynamicColor(enabled);
      },
    );
  }

  Widget _buildHapticFeedbackSetting() {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return SwitchListTile(
      title: const Text('触感反馈'),
      subtitle: Text('与界面元素交互时震动', style: subtitleStyle),
      value: _hapticService.isEnabled,
      onChanged: (value) => _hapticService.setEnabled(value),
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '其他'),
        const SizedBox(height: 12),
        _buildLogCard(context),
        const SizedBox(height: 12),
        _buildGithubProjectCard(context),
      ],
    );
  }

  Widget _buildLogCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return ListTile(
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
    );
  }

  Widget _buildGithubProjectCard(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return ListTile(
      leading: const Icon(Icons.code),
      title: const Text('GitHub'),
      subtitle: Text('访问项目源代码', style: subtitleStyle),
      onTap: () async {
        _hapticService.lightImpact();
        final url = Uri.parse('https://github.com/smileheart0708/Temp-Email');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          LogService.instance.logError('Could not launch $url');
        }
      },
    );
  }
}
