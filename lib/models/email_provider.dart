import 'package:flutter/foundation.dart';

/// 表示一个邮箱后缀名及其启用状态。
///
/// 这是一个不可变类。要修改状态，请使用 [copyWith] 方法创建一个新的实例。
@immutable
class EmailSuffix {
  final String value;
  final bool isEnabled;

  const EmailSuffix({required this.value, this.isEnabled = true});

  /// 创建一个带有更新后值的新实例。
  EmailSuffix copyWith({
    bool? isEnabled,
  }) {
    return EmailSuffix(
      value: value,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// 从 Map 中创建实例，用于从持久化存储中加载。
  factory EmailSuffix.fromMap(Map<String, dynamic> map) {
    return EmailSuffix(
      value: map['value'] as String,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  /// 将实例转换为 Map，用于持久化存储。
  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'isEnabled': isEnabled,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailSuffix &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// 表示一个邮件服务提供商及其配置。
///
/// 这是一个不可变类。要修改状态，请使用 [copyWith] 方法创建一个新的实例。
@immutable
class EmailProviderModel {
  final String name;
  final bool requiresApiKey;
  final List<EmailSuffix> suffixes;

  const EmailProviderModel({
    required this.name,
    required this.suffixes,
    this.requiresApiKey = false,
  });

  /// 创建一个带有更新后值的新实例。
  EmailProviderModel copyWith({
    List<EmailSuffix>? suffixes,
  }) {
    return EmailProviderModel(
      name: name,
      requiresApiKey: requiresApiKey,
      suffixes: suffixes ?? this.suffixes,
    );
  }
}