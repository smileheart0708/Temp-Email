import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'email_view_screen.dart';
import 'services/haptic_service.dart';
import 'package:email/services/email_service.dart';
import 'package:email/models/email_message.dart';

class MailPage extends StatefulWidget {
  const MailPage({super.key});

  @override
  State<MailPage> createState() => MailPageState();
}

class MailPageState extends State<MailPage> {
  final _emailService = EmailService.instance;
  final _hapticService = HapticService.instance;

  @override
  void initState() {
    super.initState();
    _emailService.emailId.addListener(_onEmailIdChanged);
    _emailService.refreshTrigger.addListener(_onRefreshTriggered);

    // Initial load if an email is already selected
    if (_emailService.emailId.value != null) {
      _emailService.refreshMessages();
    }
  }

  @override
  void dispose() {
    _emailService.emailId.removeListener(_onEmailIdChanged);
    _emailService.refreshTrigger.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onEmailIdChanged() {
    if (mounted) {
      _emailService.refreshMessages();
    }
  }

  void _onRefreshTriggered() {
    if (mounted) {
      // The service already handles haptics, so we just call the method.
      _emailService.refreshMessages();
    }
  }

  void _onEmailTapped(EmailMessage message) async {
    _hapticService.lightImpact();

    // Show a loading indicator using a snackbar for quick feedback.
    final snackbar = ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('正在加载邮件...'), duration: Duration(seconds: 10)));

    try {
      final File emailFile =
          await _emailService.getAndCacheMessageDetails(message.id);

      snackbar.close(); // Close the loading snackbar

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailViewScreen(htmlFile: emailFile),
          ),
        );
      }
    } catch (e) {
      snackbar.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _emailService.emailId,
      builder: (context, emailId, child) {
        if (emailId == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('请先在主页获取一个邮箱地址'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _emailService.refreshMessages,
          child: ValueListenableBuilder<String?>(
            valueListenable: _emailService.fetchMessagesError,
            builder: (context, error, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: _emailService.isFetchingMessages,
                builder: (context, isLoading, child) {
                  return ValueListenableBuilder<List<EmailMessage>>(
                    valueListenable: _emailService.messages,
                    builder: (context, messages, child) {
                      if (isLoading && messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (error != null && messages.isEmpty) {
                        return _buildErrorWidget(error);
                      }

                      if (messages.isEmpty) {
                        return _buildEmptyMessagesWidget();
                      }

                      return _buildMessagesList(messages);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(List<EmailMessage> messages) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final messageTime =
            DateTime.fromMillisecondsSinceEpoch(message.time * 1000);
        final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(messageTime);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              message.from.isNotEmpty ? message.from[0].toUpperCase() : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(message.from, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(message.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(formattedTime, style: Theme.of(context).textTheme.bodySmall),
          onTap: () => _onEmailTapped(message),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              '出错了',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _emailService.refreshMessages,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMessagesWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('收件箱是空的'),
                  SizedBox(height: 4),
                  Text(
                    '下拉以刷新邮件',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
