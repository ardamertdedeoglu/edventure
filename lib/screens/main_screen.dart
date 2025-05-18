import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'chat_screen.dart';
import 'todo_screen.dart';
import 'profile_screen.dart';
import 'premium_screen.dart';
import 'cv_review_screen.dart';
import 'budget_planner_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Navigation state
  int _bottomNavIndex = 0; // Current bottom nav bar index
  String _currentView = 'home'; // Current screen being displayed
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String? _profileImageUrl;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfileImage();
    
    // Add a listener to AuthService to refresh when profile is updated
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.addListener(_handleProfileUpdates);
  }
  
  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.removeListener(_handleProfileUpdates);
    
    super.dispose();
  }
  
  // Handler for profile updates
  void _handleProfileUpdates() {
    _loadUserProfileImage();
  }
  
  Future<void> _loadUserProfileImage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated) {
      final imageUrl = await authService.getUserProfileImageUrl();
      if (mounted) {
        setState(() {
          _profileImageUrl = imageUrl;
        });
      }
    }
  }

  // Maps screen identifiers to their widget instances
  final Map<String, Widget> _screens = {
    'home': const HomeScreen(),
    'profile': const ProfileScreen(),
    'premium': const PremiumScreen(),
    'tasks': const TodoScreen(),
    'cv_review': const CVReviewScreen(),
    'budget_planner': const BudgetPlannerScreen(),
  };
  
  // Main screens for bottom navigation
  final List<String> _mainViews = ['home', 'profile', 'premium'];

  // Handle bottom navigation bar taps
  void _onBottomNavTapped(int index) {
    // Ensure we're transitioning to a main view
    String targetView = _mainViews[index];
    
    // Update state and UI
    setState(() {
      _bottomNavIndex = index;
      _currentView = targetView;
    });
  }
  
  // Handle drawer item taps for non-main screens
  void _onDrawerItemTapped(String screenId) {
    // Close the drawer first
    Navigator.pop(context);
    
    // Update the current view to the selected screen
    setState(() {
      _currentView = screenId;
      // Reset bottom nav index to avoid highlighting wrong tab
      _bottomNavIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if the current view is a drawer view (not one of the main bottom nav views)
    final isDrawerView = !_mainViews.contains(_currentView);
    
    // Get auth service to check if user is logged in
    final authService = Provider.of<AuthService>(context);
    final isAuthenticated = authService.isAuthenticated;
    
    // Always refresh profile image when building
    if (isAuthenticated && authService.user != null) {
      // Use a future to get the latest profile image without blocking the UI
      Future.microtask(() => _loadUserProfileImage());
    }
    
    // Title for AppBar
    String title;
    switch (_currentView) {
      case 'home':
        title = 'Ana Sayfa';
        break;
      case 'profile':
        title = 'Profil';
        break;
      case 'premium':
        title = 'Premium';
        break;
      case 'tasks':
        title = 'Görevlerim';
        break;
      case 'cv_review':
        title = 'CV İnceleme';
        break;
      case 'budget_planner':
        title = 'Bütçe Planlayıcı';
        break;
      default:
        title = 'Work & Travel';
    }
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Color(0xFF246EE9),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            // Refresh profile image before opening drawer
            _loadUserProfileImage();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          // Show chat button in Home, Tasks, or CV Review screens
          if (_currentView == 'home' || _currentView == 'tasks' || _currentView == 'cv_review')
            IconButton(
              icon: Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => ChatScreen())
                );
              },
            ),
          // Show logout button in Profile screen
          if (_currentView == 'profile')
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
                Navigator.pushReplacementNamed(context, '/welcome');
              },
            ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Drawer header
              Consumer<AuthService>(
                builder: (context, authService, _) {
                  // Get the profile image from AuthService when it changes
                  if (authService.isAuthenticated && _profileImageUrl == null) {
                    Future.microtask(() async {
                      final imageUrl = await authService.getUserProfileImageUrl();
                      if (mounted) {
                        setState(() {
                          _profileImageUrl = imageUrl;
                        });
                      }
                    });
                  }
                  
                  return Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: Color(0xFF246EE9),
                    ),
                    padding: EdgeInsets.all(16),
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      children: [
                        // Profile avatar - show user image if available
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 30,
                          backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                          child: _profileImageUrl == null ? Icon(
                            Icons.person,
                            size: 35,
                            color: Color(0xFF246EE9),
                          ) : null,
                        ),
                        SizedBox(width: 16),
                        // User info
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authService.isAuthenticated 
                                  ? authService.user?.displayName ?? 'Kullanıcı'
                                  : 'Giriş Yapılmadı',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              if (authService.isAuthenticated && authService.user?.email != null)
                                Text(
                                  authService.user!.email!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Drawer items
              _buildDrawerItem(
                icon: Icons.task_alt,
                title: 'Görevlerim',
                isSelected: _currentView == 'tasks',
                onTap: () => _onDrawerItemTapped('tasks'),
              ),
              _buildDrawerItem(
                icon: Icons.description,
                title: 'CV İnceleme',
                isSelected: _currentView == 'cv_review',
                onTap: () => _onDrawerItemTapped('cv_review'),
              ),
              _buildDrawerItem(
                icon: Icons.account_balance_wallet,
                title: 'Bütçe Planlayıcı',
                isSelected: _currentView == 'budget_planner',
                onTap: () => _onDrawerItemTapped('budget_planner'),
              ),
              
              Divider(color: Colors.grey.shade300),
              
              // Navigation items section title
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ana Menü',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              _buildDrawerItem(
                icon: Icons.home,
                title: 'Ana Sayfa',
                isSelected: _currentView == 'home',
                onTap: () {
                  // Close the drawer first
                  Navigator.pop(context);
                  
                  // Update state to show home screen
                  setState(() {
                    _currentView = 'home';
                    _bottomNavIndex = 0;
                  });
                },
              ),
              _buildDrawerItem(
                icon: Icons.person,
                title: 'Profil',
                isSelected: _currentView == 'profile',
                onTap: () {
                  // Close the drawer first
                  Navigator.pop(context);
                  
                  // Update state to show profile screen
                  setState(() {
                    _currentView = 'profile';
                    _bottomNavIndex = 1;
                  });
                },
              ),
              _buildDrawerItem(
                icon: Icons.workspace_premium,
                title: 'Premium',
                isSelected: _currentView == 'premium',
                onTap: () {
                  // Close the drawer first
                  Navigator.pop(context);
                  
                  // Update state to show premium screen
                  setState(() {
                    _currentView = 'premium';
                    _bottomNavIndex = 2;
                  });
                },
              ),
              
              Spacer(),
              
              // Bottom section with app info
              Divider(color: Colors.grey.shade300),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Uygulama Sürümü: 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: isDrawerView 
        // If it's a drawer view, show the corresponding screen directly
        ? _screens[_currentView]!
        // Otherwise use PageView for swipeable screens
        : IndexedStack(
            index: _bottomNavIndex,
            children: _mainViews.map((viewId) => _screens[viewId]!).toList(),
          ),
      // Only show bottom navigation bar when not displaying a drawer view
      bottomNavigationBar: isDrawerView 
        ? null
        : BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              // Home tab
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Ana Sayfa',
              ),
              // Profile tab
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profil',
              ),
              // Premium tab
              BottomNavigationBarItem(
                icon: Icon(Icons.workspace_premium),
                label: 'Premium',
              ),
            ],
            type: BottomNavigationBarType.fixed,
            currentIndex: _bottomNavIndex,
            selectedItemColor: Color(0xFF246EE9),
            unselectedItemColor: Colors.grey.shade600,
            showUnselectedLabels: true,
            backgroundColor: Colors.white,
            elevation: 8,
            onTap: _onBottomNavTapped,
          ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Color(0xFF246EE9) : Colors.grey.shade700,
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isSelected ? Color(0xFF246EE9) : Colors.grey.shade900,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      tileColor: isSelected ? Color(0xFF246EE9).withOpacity(0.1) : null,
      onTap: onTap,
    );
  }
}
