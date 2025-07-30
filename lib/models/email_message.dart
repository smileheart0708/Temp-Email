// 数据模型
class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final int time;

  EmailMessage(
      {required this.id,
      required this.from,
      required this.subject,
      required this.time});

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: json['id'],
      from: json['from'],
      subject: json['subject'],
      time: json['time'],
    );
  }
} 