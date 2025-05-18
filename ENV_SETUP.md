# Environment Setup for API Keys

This application uses environment variables to securely store API keys. Follow these steps to set up your environment:

## Create a .env File

1. Create a file called `.env` in the root of your project (same level as `pubspec.yaml`)
2. Add the following environment variables to the file:

```
# API Keys
GEMINI_API_KEY=your_gemini_api_key_here
CLAUDE_API_KEY=your_claude_api_key_here
FIREBASE_WEB_API_KEY=your_firebase_web_api_key_here
FIREBASE_ANDROID_API_KEY=your_firebase_android_api_key_here
```

3. Replace the placeholder values with your actual API keys:
   - `GEMINI_API_KEY`: Your Google Gemini AI API key
   - `CLAUDE_API_KEY`: Your Anthropic Claude API key
   - `FIREBASE_WEB_API_KEY`: Your Firebase Web API key
   - `FIREBASE_ANDROID_API_KEY`: Your Firebase Android API key

## Important Security Notes

- **NEVER** commit your `.env` file to version control
- The `.env` file is already added to `.gitignore`
- Keep your API keys secure and don't share them publicly

## How It Works

The application uses the `flutter_dotenv` package to load environment variables from the `.env` file. These variables are accessed through the `EnvironmentConfig` class in `lib/config/environment_config.dart`. 