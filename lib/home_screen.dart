import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/haptic_service.dart';
import 'package:email/services/email_service.dart';
import 'package:email/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 电子邮件逻辑和状态现在由 EmailService 处理。
  final _emailService = EmailService.instance;

  // 密码生成器的状态保留在本地。
  double _passwordLength = 8.0;
  bool _includeNumbers = true;
  bool _includeLetters = true;
  bool _includeSymbols = false;
  bool _mixCase = true;
  String? _generatedPassword;
  final _hapticService = HapticService.instance;
  final _storageService = StorageService.instance;

  @override
  void initState() {
    super.initState();
    _loadPasswordSettingsAndGenerate();
  }

  Future<void> _loadPasswordSettingsAndGenerate() async {
    final settings = await _storageService.getPasswordSettings();
    if (mounted) {
      setState(() {
        _passwordLength = settings.$1;
        _includeNumbers = settings.$2;
        _includeLetters = settings.$3;
        _includeSymbols = settings.$4;
        _mixCase = settings.$5;
      });
      _generatePassword();
    }
  }

  Future<void> _savePasswordSettings() async {
    await _storageService.savePasswordSettings(
      length: _passwordLength,
      includeNumbers: _includeNumbers,
      includeLetters: _includeLetters,
      includeSymbols: _includeSymbols,
      mixCase: _mixCase,
    );
  }

  void _generatePassword({bool userInitiated = false}) {
    if (userInitiated) {
      _hapticService.lightImpact();
    }
    if (!_includeNumbers && !_includeLetters && !_includeSymbols) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一种字符类型'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final random = Random.secure();
    List<String> charSet = [];
    const String numbers = '0123456789';
    const String lettersLower = 'abcdefghijklmnopqrstuvwxyz';
    const String lettersUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    List<String> passwordChars = [];

    if (_includeLetters) {
      passwordChars.add(lettersLower[random.nextInt(lettersLower.length)]);
      if (_mixCase) {
        passwordChars.add(lettersUpper[random.nextInt(lettersUpper.length)]);
      }
    }
    if (_includeNumbers) {
      passwordChars.add(numbers[random.nextInt(numbers.length)]);
    }
    if (_includeSymbols) {
      passwordChars.add(symbols[random.nextInt(symbols.length)]);
    }

    if (_includeNumbers) charSet.addAll(numbers.split(''));
    if (_includeLetters) {
      charSet.addAll(lettersLower.split(''));
      if (_mixCase) {
        charSet.addAll(lettersUpper.split(''));
      }
    }
    if (_includeSymbols) charSet.addAll(symbols.split(''));

    final remainingLength = _passwordLength.toInt() - passwordChars.length;
    if (charSet.isNotEmpty) {
      for (int i = 0; i < remainingLength; i++) {
        passwordChars.add(charSet[random.nextInt(charSet.length)]);
      }
    }

    passwordChars.shuffle(random);

    setState(() {
      _generatedPassword = passwordChars.join('');
    });
  }

  void _copyPasswordToClipboard() {
    _hapticService.lightImpact();
    if (_generatedPassword != null) {
      Clipboard.setData(ClipboardData(text: _generatedPassword!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密码已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyEmailToClipboard(String email) {
    _hapticService.lightImpact();
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('邮箱地址已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ValueListenableBuilder<EmailGenerationState>(
              valueListenable: _emailService.emailState,
              builder: (context, state, child) {
                switch (state.status) {
                  case EmailGenerationStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case EmailGenerationStatus.failure:
                    return _buildInfoCard(
                      context: context,
                      icon: Icons.error_outline,
                      iconColor: Theme.of(context).colorScheme.error,
                      title: '操作失败',
                      subtitle: state.errorMessage ?? '未知错误',
                    );
                  case EmailGenerationStatus.success:
                    if (state.email != null) {
                      return _buildEmailCard(context, state.email!);
                    }
                    // If email is null on success, treat as initial state.
                    return _buildInfoCard(
                      context: context,
                      icon: Icons.email_outlined,
                      title: '准备就绪',
                      subtitle: '点击下方按钮获取一个临时邮箱地址',
                    );
                  case EmailGenerationStatus.initial:
                    return _buildInfoCard(
                      context: context,
                      icon: Icons.email_outlined,
                      title: '准备就绪',
                      subtitle: '点击下方按钮获取一个临时邮箱地址',
                    );
                }
              },
            ),
            const SizedBox(height: 24),
            // 获取按钮的状态也由 EmailService 控制。
            ValueListenableBuilder<EmailGenerationState>(
              valueListenable: _emailService.emailState,
              builder: (context, state, child) {
                final isLoading = state.status == EmailGenerationStatus.loading;
                return FilledButton.tonal(
                  onPressed: isLoading ? null : _emailService.getTempEmail,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '获取临时邮箱',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildPasswordGeneratorCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailCard(BuildContext context, String email) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Icon(
          Icons.mark_email_read_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('临时邮箱', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          email,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: '复制',
          onPressed: () => _copyEmailToClipboard(email),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon,
                size: 48,
                color: iconColor ?? Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordGeneratorCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('随机密码生成',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_generatedPassword != null) _buildPasswordResultCard(context),
            const SizedBox(height: 16),
            Text('密码长度: ${_passwordLength.toInt()}',
                style: Theme.of(context).textTheme.bodyLarge),
            Slider(
              value: _passwordLength,
              min: 6,
              max: 32,
              divisions: 26,
              label: _passwordLength.toInt().toString(),
              onChanged: (value) {
                setState(() {
                  _passwordLength = value;
                });
              },
              onChangeEnd: (value) {
                _hapticService.lightImpact();
                _savePasswordSettings();
                _generatePassword();
              },
            ),
            SwitchListTile(
              title: const Text('包含数字 (0-9)'),
              value: _includeNumbers,
              onChanged: (value) {
                _hapticService.lightImpact();
                setState(() => _includeNumbers = value);
                _savePasswordSettings();
                _generatePassword();
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('包含字母 (a-z, A-Z)'),
              value: _includeLetters,
              onChanged: (value) {
                _hapticService.lightImpact();
                setState(() {
                  _includeLetters = value;
                  if (!value) {
                    _mixCase = false;
                  }
                });
                _savePasswordSettings();
                _generatePassword();
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('混合大小写'),
              value: _mixCase,
              onChanged: _includeLetters
                  ? (value) {
                      _hapticService.lightImpact();
                      setState(() => _mixCase = value);
                      _savePasswordSettings();
                      _generatePassword();
                    }
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('包含符号 (!@#...)'),
              value: _includeSymbols,
              onChanged: (value) {
                _hapticService.lightImpact();
                setState(() => _includeSymbols = value);
                _savePasswordSettings();
                _generatePassword();
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _generatePassword(userInitiated: true),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '生成新密码',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordResultCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          _generatedPassword!,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: '复制密码',
          onPressed: _copyPasswordToClipboard,
        ),
      ),
    );
  }
}