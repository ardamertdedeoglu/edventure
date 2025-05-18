import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  // API Keys
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? 'AIzaSyB0kqcjUvlKL2GViBfCSgP9tzKn212xc6g';
  static String get claudeApiKey => dotenv.env['CLAUDE_API_KEY'] ?? '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';
  static String get firebaseWebApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? 'AIzaSyCI_jfSEQUAGg10i_eCsvf9exQUlSh0K-E';
  static String get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? 'AIzaSyAUxA_Ymtu5sY0NCU1RCybAoFo289Lew30';
} 