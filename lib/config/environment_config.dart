import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  // API Keys
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? 'AIzaSyB0kqcjUvlKL2GViBfCSgP9tzKn212xc6g';
  static String get claudeApiKey => dotenv.env['CLAUDE_API_KEY'] ?? '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';
  static String get firebaseWebApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? 'AIzaSyCI_jfSEQUAGg10i_eCsvf9exQUlSh0K-E';
  static String get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? 'AIzaSyAUxA_Ymtu5sY0NCU1RCybAoFo289Lew30';
} 