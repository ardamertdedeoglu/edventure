import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/search_result.dart';
import '../services/semantic_search_service.dart';
import '../services/auth_service.dart';
import '../services/program_service.dart';
import '../services/favorites_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  final ProgramService _programService = ProgramService();
  List<SearchResult> searchResults = [];
  bool isSearchLoading = false;
  String searchErrorMessage = '';
  bool _useLocalData = true;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Today's events variables
  List<Event> _todaysEvents = [];
  bool _isLoadingTodaysEvents = false;
  
  // Welcome message variables
  String _welcomeMessage = "Work & Travel yolculuğunuzda size yardımcı olmaya devam ediyoruz. Kaldığınız yerden devam edin.";
  bool _isLoadingWelcomeMessage = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });

    tz_data.initializeTimeZones();
    _loadTodaysEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      isSearchLoading = true;
    });

    // Load programs from JSON
    await _programService.loadPrograms();
    _loadInitialSuggestions();
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated) {
      _generateAIWelcomeMessage();
    }

    setState(() {
      isSearchLoading = false;
    });
  }
  
  Future<void> _loadTodaysEvents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTodaysEvents = true;
    });

    try {
      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      
      QuerySnapshot snapshot = await _firestore
          .collection('calendar_plans')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayStart.add(const Duration(days: 1))))
          .orderBy('date')
          .get();

      List<Event> events = [];
      for (var doc in snapshot.docs) {
        events.add(Event.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
      
      events.sort((a, b) {
        final startTimeA = a.startTime.hour * 60 + a.startTime.minute;
        final startTimeB = b.startTime.hour * 60 + b.startTime.minute;
        return startTimeA.compareTo(startTimeB);
      });

      if (mounted) {
        setState(() {
          _todaysEvents = events;
          _isLoadingTodaysEvents = false;
        });
      }
    } catch (e) {
      print("Error loading today's events: $e");
      if (mounted) {
        setState(() {
          _isLoadingTodaysEvents = false;
        });
      }
    }
  }

  Future<void> _generateAIWelcomeMessage() async {
    setState(() {
      _isLoadingWelcomeMessage = true;
    });

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      final url = Uri.parse("https://api.openai.com/v1/chat/completions");

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "system",
              "content": "Sen bir Work & Travel uygulamasında kullanıcıları karşılayan bir asistansın. Kullanıcılara work and travel, yurt dışı deneyimleri, kültürel değişim programları bağlamında kısa, samimi ve motive edici bir karşılama mesajı üret. Mesaj en fazla iki cümle olmalı ve Türkçe olmalı."
            },
            {"role": "user", "content": "Kullanıcı için kişiselleştirilmiş bir karşılama mesajı üret"}
          ],
          "temperature": 0.7,
          "max_tokens": 150
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        if (mounted) {
          setState(() {
            _welcomeMessage = content.trim();
            _isLoadingWelcomeMessage = false;
          });
        }
      } else {
        print("OpenAI API error: ${response.statusCode}");
        if (mounted) {
          setState(() {
            _isLoadingWelcomeMessage = false;
          });
        }
      }
    } catch (e) {
      print("Error generating welcome message: $e");
      if (mounted) {
        setState(() {
          _isLoadingWelcomeMessage = false;
        });
      }
    }
  }

  void _loadInitialSuggestions() async {
    try {
      List<SearchResult> suggestions;

      if (_useLocalData) {
        suggestions = _programService.searchPrograms("program");
      } else {
        final authService = Provider.of<AuthService>(context, listen: false);
        final searchService = SemanticSearchService(authService: authService);
        suggestions = await searchService.search("yazılım");
      }

      if (mounted) {
        setState(() {
          searchResults = suggestions;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchErrorMessage = e.toString();
        });
      }
      print("Öneriler yüklenirken hata: $e");
    }
  }

  Future<void> performSearch() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        searchErrorMessage = 'Lütfen arama sorgusu girin';
      });
      _loadInitialSuggestions();
      return;
    }

    setState(() {
      isSearchLoading = true;
      searchResults = [];
      searchErrorMessage = '';
    });

    try {
      List<SearchResult> results;

      if (_useLocalData) {
        results = _programService.searchPrograms(_searchController.text.trim());
      } else {
        try {
          final authService = Provider.of<AuthService>(context, listen: false);

          if (!authService.isAuthenticated) {
            setState(() {
              isSearchLoading = false;
              searchErrorMessage =
                  'API aramak için giriş yapmalısınız. Lütfen giriş yapın veya yerel modu kullanın.';
              _useLocalData = true;
            });
            
            _loadInitialSuggestions();
            return;
          }

          final searchService = SemanticSearchService(authService: authService);
          results = await searchService.search(_searchController.text.trim());
        } catch (apiError) {
          print("API error: $apiError");
          setState(() {
            _useLocalData = true;
          });
          results = _programService.searchPrograms(
            _searchController.text.trim(),
          );
        }
      }

      if (mounted) {
        setState(() {
          searchResults = results;
          isSearchLoading = false;
        });
        
        if (results.isEmpty) {
          setState(() {
            searchErrorMessage = 'Sonuç bulunamadı. Farklı bir arama terimi deneyin.';
          });
          _loadInitialSuggestions();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchErrorMessage = e.toString();
          isSearchLoading = false;
        });
        
        _loadInitialSuggestions();
      }
      print("Arama hatası: $e");
    }
  }

  Widget _buildSearchResultCard(SearchResult result, {bool disableTap = false}) {
    final String mainDescription = result.description.split('\n\n').first;
    final String metadata =
        result.description.contains('\n\n')
            ? result.description.split('\n\n').last
            : '';

    Widget cardContent = Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Divider(height: 16),

            Text(
              mainDescription,
              style: TextStyle(fontSize: 14),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),

            if (metadata.isNotEmpty)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
    
    return disableTap 
        ? cardContent 
        : GestureDetector(
            onTap: () => _showProgramDetails(result),
            child: cardContent,
          );
  }

  void _showProgramDetails(SearchResult result) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    bool isInFavorites = false;
    
    if (authService.isAuthenticated) {
      final favoritesService = FavoritesService();
      isInFavorites = await favoritesService.isInFavorites(authService.user!.uid, result.id);
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Program Detayı', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              )),
              backgroundColor: Color(0xFF246EE9),
              foregroundColor: Colors.white,
              elevation: 2,
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Container(
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
                      Text(
                        result.title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF246EE9),
                        ),
                      ),
                      SizedBox(height: 24),
                      
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
                                Icon(Icons.description, color: Color(0xFF246EE9)),
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
                                  Icon(Icons.info_outline, color: Color(0xFF246EE9)),
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
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final authService = Provider.of<AuthService>(context, listen: false);
                                if (!authService.isAuthenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                      'Programları kaydetmek için giriş yapmalısınız',
                                      style: GoogleFonts.poppins(),
                                    )),
                                  );
                                  return;
                                }
                                
                                final favoritesService = FavoritesService();
                                bool success = false;
                                
                                if (isInFavorites) {
                                  success = await favoritesService.removeFromFavorites(
                                    authService.user!.uid, result.id);
                                  if (success) {
                                    setState(() => isInFavorites = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                        'Program kaydedilenlerden çıkarıldı',
                                        style: GoogleFonts.poppins(),
                                      )),
                                    );
                                  }
                                } else {
                                  success = await favoritesService.addToFavorites(
                                    authService.user!.uid, result);
                                  if (success) {
                                    setState(() => isInFavorites = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                        'Program başarıyla kaydedildi',
                                        style: GoogleFonts.poppins(),
                                      )),
                                    );
                                  }
                                }
                              },
                              icon: Icon(
                                isInFavorites ? Icons.bookmark : Icons.bookmark_border,
                                color: Colors.white,
                              ),
                              label: Text(
                                isInFavorites ? 'Kaydedilenlerden Çıkar' : 'Kaydet',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF246EE9),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                elevation: 2,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(
                                    'Paylaşım özelliği yakında',
                                    style: GoogleFonts.poppins(),
                                  )),
                                );
                              },
                              icon: Icon(Icons.share),
                              label: Text(
                                'Paylaş',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black87,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetailsDialog(Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(0, 0, 24, 16),
          title: Text(event.title, style: GoogleFonts.poppins(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (event.description.isNotEmpty) ...[
                  Text('Açıklama:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(event.description, style: GoogleFonts.poppins(fontSize: 14)),
                  const SizedBox(height: 12),
                ],
                Text('Başlangıç:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(event.startTime.format(context), style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 12),
                Text('Bitiş:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(event.endTime.format(context), style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 12),
                Text('Tarih:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(MaterialLocalizations.of(context).formatShortDate(event.date), style: GoogleFonts.poppins(fontSize: 14)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Kapat', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildTodaysPlansSection() {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today_outlined, color: Theme.of(context).primaryColorDark, size: 26),
                    const SizedBox(width: 12),
                    Text(
                      "Bugünün Planları",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: Theme.of(context).primaryColor),
                  onPressed: _loadTodaysEvents,
                  tooltip: "Yenile",
                )
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoadingTodaysEvents)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: CircularProgressIndicator(),
              ))
            else if (_todaysEvents.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_outlined, size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 15),
                      Text(
                        "Bugun icin planiniz bulunmuyor.\nHarika bir gun gecirin!",
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _todaysEvents.length,
                itemBuilder: (context, index) {
                  final event = _todaysEvents[index];
                  return InkWell(
                    onTap: () => _showEventDetailsDialog(event),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      decoration: BoxDecoration(
                         // Optional: Add a subtle background or border per item
                         // color: Colors.grey.shade50, 
                         // borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lens_blur_rounded, color: Theme.of(context).primaryColor, size: 20),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16.5)),
                                const SizedBox(height: 4),
                                Text(
                                  "${event.startTime.format(context)} - ${event.endTime.format(context)}",
                                  style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) => Divider(height: 1, indent: 15, endIndent: 15, color: Colors.grey.shade200),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                ).then((_) => _loadTodaysEvents());
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: Text('Tam Takvimi Görüntüle / Plan Ekle', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isNewUser = authService.isNewUser;
    
    if (isNewUser) {
      Future.delayed(Duration.zero, () {
        authService.clearNewUserFlag();
      });
    }
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColorLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isNewUser ? 'Hoş Geldiniz!' : 'Selam!',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColorDark,
                            ),
                          ),
                        ),
                        if (!isNewUser)
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.amber.shade700,
                            size: 28,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoadingWelcomeMessage
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Mesajınız hazırlanıyor...",
                                  style: GoogleFonts.poppins(
                                    color: Theme.of(context).primaryColorDark,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNewUser 
                                ? 'Çalışma ve seyahat deneyiminizi yönetmek için uygulamanın ana özelliklerini keşfedin.'
                                : _welcomeMessage,
                              style: GoogleFonts.poppins(fontSize: 14.5, color: Colors.black87, height: 1.5),
                            ),
                            if (!isNewUser && _welcomeMessage.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  " ✨ Powered by AI",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search_rounded, color: Theme.of(context).primaryColorDark, size: 26),
                          const SizedBox(width: 12),
                          Text(
                            'Program Ara',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColorDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Program veya kategori ara...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.search_outlined, color: Colors.grey.shade600),
                          filled: true,
                          fillColor: Colors.grey.shade100.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadInitialSuggestions();
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).primaryColor),
                                onPressed: performSearch,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            _loadInitialSuggestions();
                          }
                        },
                        onSubmitted: (_) => performSearch(),
                      ),
                      const SizedBox(height: 18),
                      if (isSearchLoading)
                        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 15.0), child: CircularProgressIndicator()))
                      else if (searchErrorMessage.isNotEmpty && searchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          child: Center(
                            child: Text(
                              searchErrorMessage,
                              style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (searchResults.isNotEmpty)
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length > 2 ? 2 : searchResults.length,
                            itemBuilder: (context, index) {
                              return _buildSearchResultCard(searchResults[index]);
                            },
                          ),
                        )
                      else if (searchResults.isEmpty && _searchController.text.isNotEmpty)
                         Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          child: Center(
                            child: Text(
                              "Aradığınız kriterlere uygun program bulunamadı.",
                              style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),


                      if (searchResults.length > 2)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.read_more_rounded, size: 20),
                            label: Text('Tüm Sonuçları Gör', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              foregroundColor: Theme.of(context).primaryColor,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: SizedBox(
                                          width: double.maxFinite,
                                          height: MediaQuery.of(context).size.height * 0.8,
                                          child: Column(
                                            children: [
                                              AppBar(
                                                title: Text(
                                                  'Arama Sonuçları',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                backgroundColor: Color(0xFF246EE9),
                                                foregroundColor: Colors.white,
                                                automaticallyImplyLeading: false,
                                                actions: [
                                                  IconButton(
                                                    icon: Icon(Icons.close),
                                                    onPressed: () => Navigator.pop(context),
                                                  ),
                                                ],
                                              ),
                                              Expanded(
                                                child: Container(
                                                  color: Colors.grey.shade50,
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    itemCount: searchResults.length,
                                                    itemBuilder: (context, index) {
                                                      return GestureDetector(
                                                        onTap: () {
                                                          Navigator.pop(context);
                                                          _showProgramDetails(searchResults[index]);
                                                        },
                                                        child: _buildSearchResultCard(
                                                          searchResults[index],
                                                          disableTap: true,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            _buildTodaysPlansSection(),
          ],
        ),
      ),
    );
  }
}
