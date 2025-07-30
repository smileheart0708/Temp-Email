import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'services/haptic_service.dart';

class EmailViewScreen extends StatefulWidget {
  final File htmlFile;

  const EmailViewScreen({super.key, required this.htmlFile});

  @override
  State<EmailViewScreen> createState() => _EmailViewScreenState();
}

class _EmailViewScreenState extends State<EmailViewScreen> {
  late final WebViewController _controller;
  String? _verificationCode;
  final _hapticService = HapticService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findVerificationCode();
    _initializeWebView();
  }

  Future<void> _findVerificationCode() async {
    try {
      final content = await widget.htmlFile.readAsString();

      // This regex finds a 6-character alphanumeric code.
      // It supports two common patterns:
      // 1. A code that is the only content inside a tag (e.g., `<p>123456</p>`).
      //    - `>\s*([a-zA-Z0-9]{6})\s*<`
      // 2. A code that immediately precedes a closing `</span>` or `</p>` tag.
      //    - `([a-zA-Z0-9]{6})(?:<\/span|<\/p>)`
      // The `|` acts as an OR, and we use two capture groups.
      final regExp = RegExp(r'>\s*([a-zA-Z0-9]{6})\s*<|([a-zA-Z0-9]{6})(?:<\/span|<\/p>)');
      final matches = regExp.allMatches(content).toList();

      if (matches.isNotEmpty) {
        // Verification codes are often the last prominent number in an email.
        // We'll take the last match found.
        final match = matches.last;
        // The regex has two capture groups for the code, due to the OR condition.
        // We need to check both to find the captured code.
        final code = match.group(1) ?? match.group(2);

        if (mounted && code != null) {
          setState(() {
            _verificationCode = code;
          });
        }
      }
    } catch (e) {
      // It's okay if this fails, we just won't show the button.
      // This is a non-critical error, so we log it silently.
      debugPrint('Could not find verification code: $e');
    }
  }

  void _copyCodeToClipboard() {
    _hapticService.lightImpact();
    if (_verificationCode != null) {
      Clipboard.setData(ClipboardData(text: _verificationCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('验证码 "$_verificationCode" 已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleError(String errorDescription) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog.
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('加载失败'),
          content: SingleChildScrollView(child: Text(errorDescription)),
          actions: <Widget>[
            TextButton(
              child: const Text('复制错误日志'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: errorDescription));
                Navigator.of(dialogContext).pop(); // Close the dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('错误信息已复制'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                // Also pop the screen after copying the error
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确认'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }



  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              _handleError('页面加载失败: ${error.description}');
            }
          },
        ),
      );

    // Add support for file access on Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadFile(widget.htmlFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('邮件详情'),
        actions: [
          if (_verificationCode != null)
            TextButton.icon(
              icon: const Icon(Icons.content_copy),
              label: const Text('复制验证码'),
              onPressed: _copyCodeToClipboard,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
