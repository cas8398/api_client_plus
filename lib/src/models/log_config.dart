import 'package:flutter/foundation.dart';
import 'package:flutter_fastlog/flutter_fastlog.dart';

class LogConfig {
  final bool showLog;
  final bool showCacheLog;
  final bool isColored;
  final bool useEmoji;
  final int logStyle;
  final bool prettyJson;
  final int messageLimit;
  final bool showTime;
  final bool showCaller;
  final String logLevel;

  const LogConfig({
    this.showLog = !kReleaseMode,
    this.showCacheLog = false,
    this.isColored = true,
    this.useEmoji = false,
    this.logStyle = OutputStyle.none,
    this.prettyJson = false,
    this.messageLimit = 300,
    this.showTime = true,
    this.showCaller = false,
    this.logLevel = "TRACE",
  });

  LogConfig copyWith({
    bool? showLog,
    bool? showCacheLog,
    bool? isColored,
    bool? useEmoji,
    int? logStyle,
    bool? prettyJson,
    int? messageLimit,
    bool? showTime,
    bool? showCaller,
    String? logLevel,
  }) {
    return LogConfig(
      showLog: showLog ?? this.showLog,
      showCacheLog: showCacheLog ?? this.showCacheLog,
      isColored: isColored ?? this.isColored,
      useEmoji: useEmoji ?? this.useEmoji,
      logStyle: logStyle ?? this.logStyle,
      prettyJson: prettyJson ?? this.prettyJson,
      messageLimit: messageLimit ?? this.messageLimit,
      showTime: showTime ?? this.showTime,
      showCaller: showCaller ?? this.showCaller,
      logLevel: logLevel ?? this.logLevel,
    );
  }

  /// Apply this configuration to FastLog
  void apply() {
    FastLog.config(
      showLog: showLog,
      isColored: isColored,
      useEmoji: useEmoji,
      outputStyle: logStyle,
      prettyJson: prettyJson,
      messageLimit: messageLimit,
      showTime: showTime,
      showCaller: showCaller,
      logLevel: logLevel,
    );
  }
}

class LogStyle {
  static const int standard = 0;
  static const int minimal = 1;
  static const int none = 2;
  static const int colored = 3;
}
