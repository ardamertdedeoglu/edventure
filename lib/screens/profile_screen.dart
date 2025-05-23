import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../models/search_result.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final FavoritesService _favoritesService = FavoritesService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _careerGoalsController = TextEditingController();

  // New state for chip editing
  List<String> _editingSkills = [];
  List<String> _editingInterests = [];
  final TextEditingController _skillsChipInputController =
      TextEditingController();
  final TextEditingController _interestsChipInputController =
      TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  String? _userName;
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = true;
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

  User? _currentUser;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _loadUserProfile();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Kullanici bulunamadi. Lutfen giris yapin.";
      });
    }

    // Add a listener to the AuthService to refresh when updates happen
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.addListener(_onAuthChange);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _classController.dispose();
    _nameController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    _interestsController.dispose();
    _careerGoalsController.dispose();
    _skillsChipInputController.dispose();
    _interestsChipInputController.dispose();

    // Remove the listener when the widget is disposed
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.removeListener(_onAuthChange);

    super.dispose();
  }

  // Handler for profile updates from other screens
  void _onAuthChange() {
    // When auth changes (e.g., profile update notification from AuthService),
    // reload user data.
    if (_currentUser != null && mounted) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _departmentController.text = data['department'] ?? '';

        // Populate controllers for view mode and initial chip editing lists
        _skillsController.text =
            (data['skills'] is List)
                ? (data['skills'] as List<dynamic>).join(', ')
                : (data['skills'] ?? '');
        _editingSkills =
            (data['skills'] is List) ? List<String>.from(data['skills']) : [];

        _experienceController.text = data['experience'] ?? '';

        _interestsController.text =
            (data['interests'] is List)
                ? (data['interests'] as List<dynamic>).join(', ')
                : (data['interests'] ?? '');
        _editingInterests =
            (data['interests'] is List)
                ? List<String>.from(data['interests'])
                : [];

        _careerGoalsController.text = data['career_goals'] ?? '';
        _userName = data['name'];
        _selectedCountry = data['country'];
        _selectedState = data['state'];
        _profileImageUrl = data['profileImageUrl'];
      }
    } catch (e) {
      _errorMessage = "Profil yuklenirken hata: ${e.toString()}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _saveUserProfile() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kullanıcı bulunamadı."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    Map<String, dynamic> updatedData = {
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'department': _departmentController.text.trim(),
      'university': _universityController.text.trim(),
      'class': _classController.text.trim(),
      'country': _selectedCountry,
      'state': _selectedState,
      'profileImageUrl': _profileImageUrl,
      'skills': _editingSkills,
      'experience': _experienceController.text.trim(),
      'interests': _editingInterests,
      'career_goals': _careerGoalsController.text.trim(),
      'last_profile_update': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .set(updatedData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil basariyla guncellendi!"),
          backgroundColor: Colors.green,
        ),
      );
      // After successful save, update controllers and switch back to view mode
      if (mounted) {
        setState(() {
          // Update the text controllers with the latest chip data
          _skillsController.text = _editingSkills.join(', ');
          _interestsController.text = _editingInterests.join(', ');

          _isEditing = false;
        });
      }
    } catch (e) {
      _errorMessage = "Profil kaydedilirken hata: ${e.toString()}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                        colors: [
                          Color(0xFF246EE9).withOpacity(0.05),
                          Colors.white,
                        ],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF246EE9),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('Giriş Yap', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }

    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
          onRefresh: () async {
            await _loadUserProfile();
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
                                label: 'Ad Soyad',
                                value: _nameController.text,
                              ),
                              _buildInfoRow(
                                label: 'Yaş',
                                value: _ageController.text,
                              ),
                              _buildInfoRow(
                                label: 'Bölüm',
                                value: _departmentController.text,
                              ),
                              _buildInfoRow(
                                label: 'Ülke',
                                value: _selectedCountry ?? 'Belirtilmemiş',
                              ),
                              if (_selectedCountry == 'Amerika Birleşik Devletleri' && (_selectedState != null && _selectedState!.isNotEmpty))
                                _buildInfoRow(
                                  label: 'Eyalet',
                                  value: _selectedState!,
                                ),
                              _buildInfoRow(
                                label: 'Yetenekler',
                                value: _skillsController.text,
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          _buildInfoSection(
                            title: 'Deneyimler',
                            icon: Icons.work_outline_rounded,
                            children: [
                              _buildInfoRow(
                                label: 'Deneyimler',
                                value: _experienceController.text,
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          _buildInfoSection(
                            title: 'Kişisel Gelişim',
                            icon: Icons.interests_outlined,
                            children: [
                              _buildInfoRow(
                                label: 'İlgi Alanları',
                                value: _interestsController.text,
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          _buildInfoSection(
                            title: 'Kariyer Hedefleri',
                            icon: Icons.flag_outlined,
                            children: [
                              _buildInfoRow(
                                label: 'Kariyer Hedefleri',
                                value: _careerGoalsController.text,
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Edit button
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                                // Initialize _editingSkills and _editingInterests when entering edit mode
                                _editingSkills =
                                    _skillsController.text
                                        .split(',')
                                        .map((s) => s.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList();
                                _editingInterests =
                                    _interestsController.text
                                        .split(',')
                                        .map((s) => s.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList();
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
    Widget valueDisplayWidget;
    bool isChipField = label == 'Yetenekler' || label == 'İlgi Alanları';

    if (isChipField) {
      List<String> items =
          value
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      if (items.isEmpty) {
        valueDisplayWidget = Text(
          'Belirtilmemiş',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
        );
      } else {
        valueDisplayWidget = Wrap(
          spacing: 8.0, // Horizontal gap between chips
          runSpacing: 6.0, // Vertical gap between lines of chips
          children:
              items
                  .map(
                    (item) => Chip(
                      label: Text(
                        item,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color:
                              Theme.of(context)
                                  .colorScheme
                                  .primary, // Using primary color for text
                        ),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(
                        0.12,
                      ), // Light primary color for background
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8.0,
                        ), // Softer corner radius
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary
                              .withOpacity(0.3), // Border color
                        ),
                      ),
                    ),
                  )
                  .toList(),
        );
      }
    } else {
      valueDisplayWidget = Text(
        value.isNotEmpty ? value : 'Belirtilmemiş',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: value.isNotEmpty ? Colors.black87 : Colors.grey.shade500,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Adjusted width to accommodate longer labels better
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: valueDisplayWidget),
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

                // Name field
                _buildTextField(
                  controller: _nameController,
                  label: "Ad Soyad",
                  icon: Icons.person_outline,
                ),
                SizedBox(height: 16),

                // Age field
                _buildTextField(
                  controller: _ageController,
                  label: "Yaş",
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),

                // Department field
                _buildTextField(
                  controller: _departmentController,
                  label: "Bölüm",
                  icon: Icons.school_outlined,
                ),
                SizedBox(height: 16),

                // Country Dropdown
                _buildDropdownFormField(
                  label: "Ülke",
                  icon: Icons.public,
                  value: _selectedCountry,
                  items: _countries,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCountry = newValue;
                      // Reset state if country changes, especially if it's no longer USA
                      if (newValue != 'Amerika Birleşik Devletleri') {
                        _selectedState = null;
                      }
                    });
                  },
                  hintText: "Ülke Seçin",
                ),
                SizedBox(height: 16),

                // State Dropdown (conditional)
                if (_selectedCountry == 'Amerika Birleşik Devletleri')
                  _buildDropdownFormField(
                    label: "Eyalet",
                    icon: Icons.location_city,
                    value: _selectedState,
                    items: _states, // Assuming _states list is populated
                    onChanged: (newValue) {
                      setState(() {
                        _selectedState = newValue;
                      });
                    },
                    hintText: "Eyalet Seçin",
                  ),
                if (_selectedCountry == 'Amerika Birleşik Devletleri') SizedBox(height: 16),

                // Skills field - replaced with chip editor
                _buildChipEditorFormField(
                  label: "Yetenekler",
                  icon: Icons.psychology_outlined,
                  currentChips: _editingSkills,
                  controller: _skillsChipInputController,
                  onChipsChanged: (updatedChips) {
                    setState(() {
                      _editingSkills = updatedChips;
                    });
                  },
                  hintText: "Yeni yetenek ekle...",
                ),
                SizedBox(height: 16),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Experience Section
          _buildInfoSection(
            title: 'Deneyimler',
            icon: Icons.work_outline_rounded,
            children: [
              _buildTextField(
                controller: _experienceController,
                label: "Deneyimler",
                icon: Icons.work_outline_rounded,
                maxLines: 4,
                hintText:
                    "Önceki işleriniz, projeleriniz veya stajlarınız hakkında bilgi verin...",
              ),
            ],
          ),

          SizedBox(height: 24),

          // Interests Section
          _buildInfoSection(
            title: 'Kisisel Gelisim',
            icon: Icons.interests_outlined,
            children: [
              // Interests field - replaced with chip editor
              _buildChipEditorFormField(
                label: "İlgi Alanları",
                icon: Icons.interests_outlined,
                currentChips: _editingInterests,
                controller: _interestsChipInputController,
                onChipsChanged: (updatedChips) {
                  setState(() {
                    _editingInterests = updatedChips;
                  });
                },
                hintText: "Yeni ilgi alanı ekle...",
              ),
            ],
          ),

          SizedBox(height: 24),

          // Career Goals Section
          _buildInfoSection(
            title: 'Kariyer Hedefleri',
            icon: Icons.flag_outlined,
            children: [
              _buildTextField(
                controller: _careerGoalsController,
                label: "Kariyer Hedefleri",
                icon: Icons.flag_outlined,
                maxLines: 3,
                hintText: "Gelecekteki kariyer hedeflerinizi aciklayin...",
              ),
            ],
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
                      _skillsChipInputController.clear();
                      _interestsChipInputController.clear();
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
                  onPressed: _saveUserProfile,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
          hintText: hintText ?? 'Buraya yazin...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // New Widget for Chip Editing
  Widget _buildChipEditorFormField({
    required String label,
    required IconData icon,
    required List<String> currentChips,
    required Function(List<String>) onChipsChanged,
    required TextEditingController controller,
    String hintText = "Yeni öğe ekle...",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 10.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children:
              currentChips.map((chipText) {
                return Chip(
                  label: Text(
                    chipText,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  onDeleted: () {
                    List<String> updatedChips = List.from(currentChips);
                    updatedChips.remove(chipText);
                    onChipsChanged(updatedChips);
                  },
                  deleteIconColor: Colors.red.shade400,
                  backgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                );
              }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      List<String> updatedChips = List.from(currentChips);
                      if (!updatedChips
                          .map((c) => c.toLowerCase())
                          .contains(value.trim().toLowerCase())) {
                        // Avoid duplicates (case-insensitive)
                        updatedChips.add(value.trim());
                        onChipsChanged(updatedChips);
                      }
                      controller.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Colors.blue.shade700,
                ),
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    List<String> updatedChips = List.from(currentChips);
                    if (!updatedChips
                        .map((c) => c.toLowerCase())
                        .contains(value.toLowerCase())) {
                      // Avoid duplicates (case-insensitive)
                      updatedChips.add(value);
                      onChipsChanged(updatedChips);
                    }
                    controller.clear();
                  }
                },
                tooltip: "Ekle",
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widget for DropdownButtonFormField
  Widget _buildDropdownFormField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: GoogleFonts.poppins(fontSize: 15)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (val) => val == null ? '$label gerekli' : null,
      ),
    );
  }
}
