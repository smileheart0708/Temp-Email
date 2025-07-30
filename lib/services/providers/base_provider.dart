import '../../models/email_message.dart';

/// Abstract class defining the contract for an email service provider.
///
/// Each concrete provider must implement these methods to fetch email data.
abstract class EmailProvider {
  /// Fetches a list of [EmailMessage] for a given email ID.
  Future<List<EmailMessage>> getMessages(String apiKey, String emailId);

  /// Fetches the detailed content of a specific email message as an HTML string.
  Future<String> getMessageDetail(String apiKey, String messageId);
} 