import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../models/search_result.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final FavoritesService _favoritesService = FavoritesService();

  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  String? _userName;
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _userData;

  List<SearchResult> _favoritePrograms = [];
  bool _isFavoritesLoading = false;

  // Ülke ve eyalet listeleri
  final List<String> _countries = [
    'Amerika Birleşik Devletleri',
    'Almanya',
    'İngiltere',
    'Fransa',
    'İtalya',
    'İspanya',
    'Hollanda',
    'Belçika',
    'İsviçre',
    'Avusturya',
    'İrlanda',
    'İsveç',
    'Norveç',
    'Danimarka',
    'Finlandiya',
    'Yunanistan',
    'Portekiz',
  ];

  // ABD eyaletleri
  final List<String> _states = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
  ];

  @override
  void initState() {
    super.initState();
    
    _loadUserData();
    _loadFavoritePrograms();
    
    // Add a listener to the AuthService to refresh when updates happen
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.addListener(_handleProfileUpdates);
  }
  
  @override
  void dispose() {
    _ageController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _classController.dispose();
    
    // Remove the listener when the widget is disposed
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.removeListener(_handleProfileUpdates);
    
    super.dispose();
  }
  
  // Handler for profile updates from other screens
  void _handleProfileUpdates() {
    if (mounted) {
      _loadUserData();
      _loadFavoritePrograms();
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user != null) {
        final userId = authService.user!.uid;

        // Kullanıcı adını al
        _userName = await authService.getUserName();

        // Check if user document exists in Firestore
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();

            // Populate form fields with existing data
            _ageController.text = _userData?['age']?.toString() ?? '';
            _universityController.text = _userData?['university'] ?? '';
            _departmentController.text = _userData?['department'] ?? '';
            _classController.text = _userData?['class'] ?? '';
            _selectedCountry = _userData?['country'];
            _selectedState = _userData?['state'];
            _profileImageUrl = _userData?['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı bilgileri yüklenirken hata: $e')),
      );
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavoritePrograms() async {
    setState(() {
      _isFavoritesLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user != null) {
        final favorites = await _favoritesService.getFavorites(
          authService.user!.uid,
        );
        setState(() {
          _favoritePrograms = favorites;
        });
      }
    } catch (e) {
      print('Error loading favorite programs: $e');
    } finally {
      setState(() {
        _isFavoritesLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Fotoğraf Seç'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçilirken hata: $e')));
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_profileImage == null) return _profileImageUrl;

    setState(() {
      _isLoading = true; // Show loading indicator during upload
    });

    try {
      // Daha basit bir referans yolu kullanıyoruz
      final storageRef = _storage
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // Upload işlemini basitleştirelim
      final uploadTask = storageRef.putFile(_profileImage!);

      // Yükleme tamamlanana kadar bekleyin
      final snapshot = await uploadTask;

      // Download URL'yi alın
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Image uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenirken hata: $e')));
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _isEditing = false; // Düzenleme modunu kapat
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.user != null) {
          final userId = authService.user!.uid;
          final email = authService.user!.email;

          // Upload profile image if selected
          String? imageUrl;
          if (_profileImage != null) {
            try {
              imageUrl = await _uploadImage(userId);

              if (imageUrl == null) {
                throw Exception('Profil resmi yüklenemedi');
              }
            } catch (e) {
              print('Profile image upload error: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $e')),
              );
              setState(() {
                _isLoading = false;
              });
              return;
            }
          } else {
            imageUrl = _profileImageUrl; // Keep existing URL if no new image
          }

          // Save user data to Firestore
          try {
            final userRef = _firestore.collection('users').doc(userId);
            await userRef.set({
              'uid': userId,
              'email': email,
              'age': int.tryParse(_ageController.text.trim()) ?? 0,
              'university': _universityController.text.trim(),
              'department': _departmentController.text.trim(),
              'class': _classController.text.trim(),
              'country': _selectedCountry,
              'state': _selectedState,
              'profileImageUrl': imageUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // Update local state
            setState(() {
              _profileImageUrl = imageUrl;
              _userData = {
                'uid': userId,
                'email': email,
                'age': int.tryParse(_ageController.text.trim()) ?? 0,
                'university': _universityController.text.trim(),
                'department': _departmentController.text.trim(),
                'class': _classController.text.trim(),
                'country': _selectedCountry,
                'state': _selectedState,
                'profileImageUrl': imageUrl,
              };
            });

            // Force a refresh in the AuthService to update all listening widgets
            authService.notifyProfileUpdated();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profil bilgileriniz kaydedildi'),
                backgroundColor: Colors.green,
              ),
            );

            // Profil verilerini hemen yenilemek için loadUserData çağır
            await _loadUserData();
          } catch (e) {
            print('Firestore save error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profil bilgileri kaydedilemedi: $e')),
            );
          }
        }
      } catch (e) {
        print('Error saving profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken hata: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildFavoriteCard(SearchResult program) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProgramDetails(program),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      program.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF246EE9),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _removeFromFavorites(program),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                program.description.split('\n\n').first,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeFromFavorites(SearchResult program) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user != null) {
      final success = await _favoritesService.removeFromFavorites(
        authService.user!.uid,
        program.id,
      );

      if (success) {
        setState(() {
          _favoritePrograms.removeWhere((p) => p.id == program.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Program kaydedilenlerden çıkarıldı',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  void _showProgramDetails(SearchResult result) {
    // Show program details in a dialog
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.zero, // Full screen dialog
            child: Column(
              children: [
                // Custom header instead of AppBar
                Container(
                  color: Color(0xFF246EE9),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Program Detayı',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Program title
                            Text(
                              result.title,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF246EE9),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Program description
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.description,
                                        color: Color(0xFF246EE9),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Program Açıklaması',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF246EE9),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    result.description.split('\n\n').first,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Program metadata
                            if (result.description.contains('\n\n')) ...[
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF246EE9),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Program Detayları',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF246EE9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      result.description.split('\n\n').last,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 30),

                            // Action button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeFromFavorites(result);
                              },
                              icon: Icon(Icons.bookmark, color: Colors.white),
                              label: Text(
                                'Kaydedilenlerden Çıkar',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF246EE9),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Add this method to build the favorites section
  Widget _buildFavoritesSection() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.bookmark, color: Color(0xFF246EE9)),
                SizedBox(width: 8),
                Text(
                  'Kaydedilen Programlar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF246EE9),
                  ),
                ),
                Spacer(),
                if (_favoritePrograms.isNotEmpty)
                  TextButton.icon(
                    onPressed: _loadFavoritePrograms,
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text(
                      'Yenile',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1),
          if (_isFavoritesLoading)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_favoritePrograms.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz kaydedilmiş program yok',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Programları kaydederek burada görüntüleyebilirsiniz',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children:
                    _favoritePrograms
                        .map((program) => _buildFavoriteCard(program))
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isAuthenticated = authService.isAuthenticated;

    if (!isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Giriş Yapılmadı',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Profil bilgilerinizi görüntülemek için giriş yapın',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text('Giriş Yap', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF246EE9),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return _isLoading
      ? Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: () async {
            await _loadUserData();
            await _loadFavoritePrograms();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile actions
                  // if (!_isEditing)
                  //   Align(
                  //     alignment: Alignment.topRight,
                  //     child: IconButton(
                  //       icon: Icon(Icons.logout),
                  //       onPressed: () async {
                  //         await authService.signOut();
                  //         Navigator.pushReplacementNamed(context, '/welcome');
                  //       },
                  //       tooltip: 'Çıkış Yap',
                  //       color: Color(0xFF246EE9),
                  //     ),
                  
                  // Rest of the profile content
                  _isEditing
                    ? _buildEditForm()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile header
                          _buildProfileHeader(),

                          // Favorites section
                          _buildFavoritesSection(),

                          // Other profile sections
                          _buildInfoSection(
                            title: 'Kişisel Bilgiler',
                            icon: Icons.person,
                            children: [
                              _buildInfoRow(
                                label: 'Yaş',
                                value: _userData?['age']?.toString() ?? '-',
                              ),
                              _buildInfoRow(
                                label: 'Üniversite',
                                value: _userData?['university'] ?? '-',
                              ),
                              _buildInfoRow(
                                label: 'Bölüm',
                                value: _userData?['department'] ?? '-',
                              ),
                              _buildInfoRow(
                                label: 'Sınıf',
                                value: _userData?['class'] ?? '-',
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          _buildInfoSection(
                            title: 'Tercih Edilen Konum Bilgileri',
                            icon: Icons.flight_takeoff,
                            children: [
                              _buildInfoRow(
                                label: 'Ülke',
                                value: _userData?['country'] ?? '-',
                              ),
                              if (_selectedCountry == 'Amerika Birleşik Devletleri')
                                _buildInfoRow(
                                  label: 'Eyalet',
                                  value: _selectedState ?? '-',
                                ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Edit button
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                            icon: Icon(Icons.edit, color: Colors.white),
                            label: Text(
                              'Profili Düzenle',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF246EE9),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
      );
  }

  // Profile header with user image and name
  Widget _buildProfileHeader() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile image
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _getProfileImage(),
                  child:
                      _profileImageUrl == null && _profileImage == null
                          ? Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey.shade400,
                          )
                          : null,
                ),
                if (_isEditing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(0xFF246EE9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Kullanıcı',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF246EE9),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  Provider.of<AuthService>(context).user?.email ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get profile image
  ImageProvider? _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (_profileImageUrl != null) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  // Build a section with title and children
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Color(0xFF246EE9)),
                SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF246EE9),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Build a row with label and value
  Widget _buildInfoRow({required String label, required String value}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Build edit form for profile
  Widget _buildEditForm() {
    final isUSA = _selectedCountry == 'Amerika Birleşik Devletleri';

    // Debug prints to check country list
    print('Countries list length: ${_countries.length}');
    print('Selected country: $_selectedCountry');
    print('Countries: $_countries');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image edit section
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _getProfileImage(),
                        child:
                            _profileImageUrl == null && _profileImage == null
                                ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                )
                                : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF246EE9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Fotoğrafı Değiştir',
                  style: GoogleFonts.poppins(
                    color: Color(0xFF246EE9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 32),

          // Personal Information Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Color(0xFF246EE9)),
                    SizedBox(width: 8),
                    Text(
                      'Kişisel Bilgiler',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF246EE9),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Age field
                Text(
                  'Yaş',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextFormField(
                  controller: _ageController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Yaşınızı girin',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF246EE9),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen yaşınızı girin';
                    }
                    final age = int.tryParse(value);
                    if (age == null) {
                      return 'Geçerli bir yaş girin';
                    }
                    if (age < 18 || age > 30) {
                      return 'Work and Travel için yaşınız 18-30 arasında olmalıdır';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // University field
                Text(
                  'Üniversite',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextFormField(
                  controller: _universityController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Üniversitenizi girin',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF246EE9),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen üniversitenizi girin';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Department field
                Text(
                  'Bölüm',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextFormField(
                  controller: _departmentController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Bölümünüzü girin',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF246EE9),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen bölümünüzü girin';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Class field
                Text(
                  'Sınıf',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextFormField(
                  controller: _classController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Sınıfınızı girin',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF246EE9),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen sınıfınızı girin';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Work & Travel Information Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flight_takeoff, color: Color(0xFF246EE9)),
                    SizedBox(width: 8),
                    Text(
                      'Tercih Edilen Konum Bilgileri',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF246EE9),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Country dropdown
                Text(
                  'Ülke',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  style: GoogleFonts.poppins(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Ülke seçin',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF246EE9),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF246EE9),
                    ),
                  ),
                  dropdownColor: Colors.white,
                  elevation: 8,
                  icon: SizedBox.shrink(),
                  items:
                      _countries.map<DropdownMenuItem<String>>((
                        String country,
                      ) {
                        return DropdownMenuItem<String>(
                          value: country,
                          child: Text(
                            country,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCountry = newValue;
                      // Eğer ülke değiştiyse ve yeni ülke ABD değilse, eyalet seçimini sıfırla
                      if (newValue != 'Amerika Birleşik Devletleri') {
                        _selectedState = null;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir ülke seçin';
                    }
                    return null;
                  },
                  isExpanded: true,
                  menuMaxHeight: 300,
                  hint: Text(
                    'Ülke seçin',
                    style: GoogleFonts.poppins(color: Colors.grey[400]),
                  ),
                ),

                // State dropdown (only for USA)
                if (isUSA) ...[
                  SizedBox(height: 16),
                  Text(
                    'Eyalet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    style: GoogleFonts.poppins(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Eyalet seçin',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Color(0xFF246EE9),
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF246EE9),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    elevation: 8,
                    icon: SizedBox.shrink(),
                    items:
                        _states.map<DropdownMenuItem<String>>((String state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(
                              state,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedState = newValue;
                      });
                    },
                    validator: (value) {
                      if (isUSA && (value == null || value.isEmpty)) {
                        return 'Lütfen bir eyalet seçin';
                      }
                      return null;
                    },
                    isExpanded: true,
                    menuMaxHeight: 300,
                    hint: Text(
                      'Eyalet seçin',
                      style: GoogleFonts.poppins(color: Colors.grey[400]),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF246EE9),
                    side: BorderSide(color: Color(0xFF246EE9)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF246EE9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Kaydet',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
