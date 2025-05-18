import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Gemini API
  try {
    Gemini.init(apiKey: 'AIzaSyB0kqcjUvlKL2GViBfCSgP9tzKn212xc6g');
    print('Gemini API initialized successfully');
  } catch (e) {
    print('Error initializing Gemini API: $e');
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(MyApp());
  } catch (e) {
    print('Firebase initialization error: $e');
    // Run app without Firebase in case of error
    runApp(MyApp(errorMessage: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  final String? errorMessage;
  
  const MyApp({this.errorMessage, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'Work & Travel',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF246EE9)),
              useMaterial3: true,
              textTheme: GoogleFonts.poppinsTextTheme(
                Theme.of(context).textTheme,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Color(0xFF246EE9),
                foregroundColor: Colors.white,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: Color(0xFF246EE9),
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
                selectedIconTheme: IconThemeData(size: 28),
                selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            home: errorMessage != null
                ? _buildErrorScreen(errorMessage!)
                : FutureBuilder(
                    future: authService.initialize(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return _buildErrorScreen(snapshot.error.toString());
                      }
                      
                      // Kullanıcı giriş yapmışsa MainScreen'e, yapmamışsa WelcomeScreen'e yönlendir
                      return authService.isAuthenticated 
                        ? MainScreen() 
                        : WelcomeScreen();
                    },
                  ),
            routes: {
              '/welcome': (context) => WelcomeScreen(),
              '/login': (context) => LoginScreen(),
              '/main': (context) => MainScreen(),
              '/register': (context) => RegisterScreen(),
            },
          );
        },
      ),
    );
  }
  
  Widget _buildErrorScreen(String errorMessage) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 20),
              Text(
                'Uygulama başlatılamadı',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
