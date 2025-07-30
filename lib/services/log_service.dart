import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A service class for handling logging operations.
///
/// This singleton class centralizes logic for writing error messages to a
/// persistent log file.
class LogService {
  LogService._privateConstructor();
  static final LogService instance = LogService._privateConstructor();

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/error_log.txt');
  }

  /// Writes a given error message to the log file with a timestamp.
  Future<void> logError(String errorDetails) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('$timestamp: $errorDetails\n',
          mode: FileMode.append);
    } catch (e) {
      // If logging to a file fails, print to the console as a fallback.
      debugPrint('Failed to write to log file: $e');
      debugPrint('Original error to log: $errorDetails');
    }
  }

  /// Reads the content of the log file.
  Future<String> readLog() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.isNotEmpty ? content : '暂无日志记录。';
      }
      return '暂无日志记录。';
    } catch (e) {
      return '读取日志失败: $e';
    }
  }

  /// Deletes the log file to clear all logs.
  Future<void> clearLog() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // If deleting fails, we can't do much.
      debugPrint('Failed to clear log file: $e');
    }
  }
} 