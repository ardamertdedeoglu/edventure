import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/search_result.dart';
import '../services/semantic_search_service.dart';
import '../services/auth_service.dart';
import '../services/program_service.dart';
import '../services/favorites_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

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

  // Calendar related variables
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  final TextEditingController _eventController = TextEditingController();
  List<Calendar> _calendars = [];
  Calendar? _selectedCalendar;
  String _calendarStatusMessage = "Henüz etkinlik eklenmedi";
  
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
    _requestCalendarPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      isSearchLoading = true;
    });

    // Load programs from JSON
    await _programService.loadPrograms();
    _loadInitialSuggestions();
    
    // Get auth service to check if user is logged in
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated) {
      // Generate AI welcome message for all users
      _generateAIWelcomeMessage();
    }

    setState(() {
      isSearchLoading = false;
    });
  }
  
  // Generate a personalized welcome message using OpenAI API
  Future<void> _generateAIWelcomeMessage() async {
    setState(() {
      _isLoadingWelcomeMessage = true;
    });

    try {
      const apiKey = "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";
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
      _loadInitialSuggestions(); // Load initial suggestions if search is empty
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
            
            // Still load initial suggestions if authentication fails
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
        
        // If no results found, show a message but maintain the initial suggestions
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
        
        // Load initial suggestions on error
        _loadInitialSuggestions();
      }
      print("Arama hatası: $e");
    }
  }

  // Calendar related methods
  Future<void> _requestCalendarPermissions() async {
    var calendarStatus = await Permission.calendarWriteOnly.request();

    if (calendarStatus.isGranted) {
      _loadCalendars();
    } else {
      setState(() {
        _calendarStatusMessage = "Takvim izni verilmedi: $calendarStatus";
      });
    }
  }

  Future<void> _loadCalendars() async {
    try {
      var calendarsResult = await _calendarPlugin.retrieveCalendars();

      final calList = calendarsResult.data as List<Calendar>? ?? <Calendar>[];

      setState(() {
        _calendars = calList;
        if (calList.isNotEmpty && _selectedCalendar == null) {
          _selectedCalendar = calList.first;
        }

        if (calList.isEmpty) {
          _calendarStatusMessage = "Kullanılabilir takvim bulunamadı";
        } else {
          _calendarStatusMessage =
              "Kullanılacak takvim: ${_selectedCalendar?.name ?? 'Seçilmedi'}";
        }
      });
    } catch (e) {
      setState(() {
        _calendarStatusMessage = "Takvimler yüklenirken hata: $e";
      });
    }
  }

  Future<Map<String, dynamic>?> _extractEvent(String text) async {
    print("Extracting event from text: $text");
    const apiKey =
        "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";
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    try {
      // Pre-process the text to handle relative dates
      Map<String, dynamic>? processedEvent = _processRelativeDates(text);
      if (processedEvent != null) {
        print("Local relative date processing result: $processedEvent");
        return processedEvent;
      }

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  """Kullanıcının etkinlik cümlesinden başlık, başlangıç ve bitiş zamanını çıkar. 
Şu formatta JSON ver: {"title":"Etkinlik başlığı", "start":"yyyy-MM-dd HH:mm", "end":"yyyy-MM-dd HH:mm"}.

Görevler:
1. 'Yarın' gibi ifadeler için yarının tarihini kullan.
2. '3 gün sonra' gibi ifadeler için uygun tarihi hesapla.
3. Eğer bitiş zamanı verilmemişse, başlangıç zamanından 1 saat sonrası için bir bitiş zamanı belirle.
4. Eğer başlangıç zamanı da verilmemişse, uygun bir zaman (örn. 09:00) belirle.
5. Etkinlik başlığı verilmemişse, isteğin içeriğine göre uygun bir başlık koy.

Örnek 1:
Girdi: "Yarın saat 15:00'da iş görüşmesi var"
Çıktı: {"title":"İş görüşmesi", "start":"2023-12-15 15:00", "end":"2023-12-15 16:00"}

Örnek 2:
Girdi: "3 gün sonra doktor randevusu"
Çıktı: {"title":"Doktor randevusu", "start":"2023-12-17 09:00", "end":"2023-12-17 10:00"}

Örnek 3:
Girdi: "Yarın toplantı"
Çıktı: {"title":"Toplantı", "start":"2023-12-15 09:00", "end":"2023-12-15 10:00"}
""",
            },
            {"role": "user", "content": text},
          ],
          "temperature": 0.2,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print("API response content: $content");
        
        try {
          final Map<String, dynamic> parsedData = jsonDecode(content);
          print("Parsed event data: $parsedData");
          return parsedData;
        } catch (parseError) {
          print("JSON parse error: $parseError for content: $content");
          setState(() {
            _calendarStatusMessage = "JSON ayrıştırma hatası: $parseError";
          });
          return null;
        }
      } else {
        print("API error with status code: ${response.statusCode}");
        print("API error response: ${response.body}");
        setState(() {
          _calendarStatusMessage = "API Hatası: ${response.statusCode}";
        });
        return null;
      }
    } catch (e) {
      print("Extract event error: $e");
      setState(() {
        _calendarStatusMessage = "İstek hatası: $e";
      });
      return null;
    }
  }

  // Process relative dates locally without relying on API
  Map<String, dynamic>? _processRelativeDates(String text) {
    text = text.toLowerCase();
    
    // Initialize with current date
    DateTime now = DateTime.now();
    DateTime startDate = now;
    DateTime endDate = now.add(Duration(hours: 1));
    bool timeSpecified = false;
    
    try {
      // Step 1: Parse date
      
      // Handle "tomorrow" (yarın)
      if (text.contains("yarın") || text.contains("yarin")) {
        startDate = DateTime(now.year, now.month, now.day + 1);
      } 
      // Handle "next week" (gelecek hafta, önümüzdeki hafta)
      else if (text.contains("gelecek hafta") || text.contains("önümüzdeki hafta") || text.contains("haftaya")) {
        startDate = DateTime(now.year, now.month, now.day + 7);
      }
      // Handle "next month" (gelecek ay, önümüzdeki ay)
      else if (text.contains("gelecek ay") || text.contains("önümüzdeki ay")) {
        startDate = DateTime(now.year, now.month + 1, now.day);
      }
      // Handle "in N days" (N gün sonra)
      else {
        RegExp daysLaterRegex = RegExp(r'(\d+)\s+g[üu]n sonra');
        Match? match = daysLaterRegex.firstMatch(text);
        if (match != null) {
          int daysLater = int.parse(match.group(1)!);
          startDate = DateTime(now.year, now.month, now.day + daysLater);
        } else {
          // No relative date found, return null to let API handle it
          return null;
        }
      }
      
      // Step 2: Parse time
      RegExp timeRegex = RegExp(r'(\d{1,2})[\s:\.]*(\d{0,2})');
      Match? timeMatch = timeRegex.firstMatch(text);
      
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        int minute = 0;
        if (timeMatch.group(2) != null && timeMatch.group(2)!.isNotEmpty) {
          minute = int.parse(timeMatch.group(2)!);
        }
        
        // Check if time is valid
        if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          startDate = DateTime(
            startDate.year, 
            startDate.month, 
            startDate.day, 
            hour, 
            minute
          );
          timeSpecified = true;
        }
      }
      
      // If no specific time found, set default time to 9:00 AM
      if (!timeSpecified) {
        startDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          9,
          0
        );
      }
      
      // Set end time 1 hour later
      endDate = startDate.add(Duration(hours: 1));
      
      // Step 3: Extract the event title - use simple keyword removal
      String title = text;
      
      // Remove time and date related terms
      List<String> termsToRemove = [
        "yarın", "yarin", "bugün", "bugun", "gelecek hafta", "önümüzdeki hafta",
        "haftaya", "gelecek ay", "önümüzdeki ay", "gün sonra", "saat", "da", "de", "ta", "te"
      ];
      
      for (String term in termsToRemove) {
        title = title.replaceAll(term, ' ');
      }
      
      // Remove time patterns like "16:00", "16.00", "16", etc.
      title = title.replaceAll(RegExp(r'\d{1,2}[\s:\.]*\d{0,2}'), ' ');
      
      // Clean up multiple spaces and trim
      title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Remove common filler words at the beginning and end
      List<String> fillerWords = ["var", "olacak", "yapılacak", "için", "ile"];
      for (String word in fillerWords) {
        if (title.startsWith("$word ")) {
          title = title.substring(word.length + 1).trim();
        }
        if (title.endsWith(" $word")) {
          title = title.substring(0, title.length - word.length - 1).trim();
        }
      }
      
      // If title is empty after all cleaning, use a generic title
      if (title.isEmpty) {
        title = "Hatırlatıcı";
      }
      
      // Format dates as strings
      String formatDateTime(DateTime dt) {
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
             "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      
      return {
        "title": title,
        "start": formatDateTime(startDate),
        "end": formatDateTime(endDate)
      };
    } catch (e) {
      print("Error in local date processing: $e");
      return null;
    }
  }

  Future<void> _handleEventCreation() async {
    final input = _eventController.text.trim();
    print("Handling event creation for input: '$input'");
    
    if (_selectedCalendar == null || input.isEmpty) {
      print("Validation failed: Calendar selected: ${_selectedCalendar != null}, Input empty: ${input.isEmpty}");
      setState(() {
        _calendarStatusMessage = "Takvim seçilmedi veya metin boş";
      });
      return;
    }

    print("Selected calendar: ${_selectedCalendar?.name} (ID: ${_selectedCalendar?.id})");
    setState(() {
      _calendarStatusMessage = "Etkinlik ayıklanıyor...";
    });

    final eventData = await _extractEvent(input);

    if (eventData != null) {
      try {
        setState(() {
          _calendarStatusMessage = "Etkinlik oluşturuluyor...";
        });
        
        // Ensure we have all required fields
        if (eventData['title'] == null || eventData['title'].toString().trim().isEmpty) {
          print("Missing title in event data");
          eventData['title'] = input.length > 30 ? input.substring(0, 30) : input;
          print("Using fallback title: ${eventData['title']}");
        }

        // Handle missing start time - use tomorrow at 9am
        if (eventData['start'] == null || eventData['start'].toString().trim().isEmpty) {
          print("Missing start time in event data");
          final tomorrow = DateTime.now().add(Duration(days: 1));
          eventData['start'] = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')} 09:00";
          print("Using fallback start time: ${eventData['start']}");
        }

        // Handle missing end time - 1 hour after start
        if (eventData['end'] == null || eventData['end'].toString().trim().isEmpty) {
          print("Missing end time in event data");
          final start = DateTime.parse(eventData['start'].toString().replaceAll(' ', 'T'));
          final end = start.add(Duration(hours: 1));
          eventData['end'] = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
          print("Using fallback end time: ${eventData['end']}");
        }

        // Normalize date strings for reliable parsing
        String normalizeDateTime(String dateTimeStr) {
          print("Normalizing date string: $dateTimeStr");
          // Replace space with T for ISO format
          String normalized = dateTimeStr.trim().replaceAll(' ', 'T');
          
          // Ensure proper formatting with padded values
          if (!normalized.contains('T')) {
            normalized = '${normalized}T00:00';
          }
          
          // Ensure it has seconds if needed
          if (normalized.split('T')[1].split(':').length < 3) {
            normalized = '$normalized:00';
          }
          
          print("Normalized date string: $normalized");
          return normalized;
        }

        print("Trying to parse start date: ${eventData['start']}");
        final startStr = normalizeDateTime(eventData['start'].toString());
        final start = DateTime.parse(startStr);
        
        print("Trying to parse end date: ${eventData['end']}");
        final endStr = normalizeDateTime(eventData['end'].toString());
        final end = DateTime.parse(endStr);

        print("Converted to DateTime - Start: $start, End: $end");
        
        final tzStart = tz.TZDateTime.from(start, tz.local);
        final tzEnd = tz.TZDateTime.from(end, tz.local);
        print("Timezone applied - TZ Start: $tzStart, TZ End: $tzEnd");

        final event = Event(
          _selectedCalendar!.id,
          title: eventData['title'].toString(),
          start: tzStart,
          end: tzEnd,
          description: "Oluşturuldu: ${DateTime.now()}",
        );
        print("Event created: $event");
        print("Event details - Title: ${event.title}, Start: ${event.start}, End: ${event.end}");

        final result = await _calendarPlugin.createOrUpdateEvent(event);
        print("Calendar plugin result: $result");
        print("Is success: ${result?.isSuccess}, Errors: ${result?.errors}");

        if (result?.isSuccess == true) {
          print("Event added successfully");
          setState(() {
            _calendarStatusMessage = "Etkinlik eklendi: ${event.title}";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Etkinlik eklendi: ${event.title}"),
              backgroundColor: Colors.green,
            ),
          );
          _eventController.clear();
        } else {
          print("Failed to add event. Errors: ${result?.errors}");
          final errorMsg = result?.errors.join(", ") ?? "Bilinmeyen hata";
          setState(() {
            _calendarStatusMessage = "Etkinlik eklenemedi: $errorMsg";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Etkinlik eklenemedi: $errorMsg"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print("Exception during event creation: $e");
        setState(() {
          _calendarStatusMessage = "Hata: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Etkinlik oluşturulurken hata: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print("Failed to extract event data from input text");
      setState(() {
        _calendarStatusMessage = "Etkinlik bilgileri ayıklanamadı";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Etkinlik bilgileri ayıklanamadı"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildCalendarDropdown() {
    if (_calendars.isEmpty) {
      return Text(
        "Kullanılabilir takvim bulunamadı",
        style: TextStyle(color: Colors.red),
      );
    }

    return DropdownButton<String>(
      hint: Text("Takvim Seçin"),
      value: _selectedCalendar?.id,
      isExpanded: true,
      onChanged: (String? newValue) {
        if (newValue != null) {
          final selectedCal = _calendars.firstWhere(
            (cal) => cal.id == newValue,
            orElse: () => _calendars.first,
          );
          setState(() {
            _selectedCalendar = selectedCal;
            _calendarStatusMessage =
                "Seçilen takvim: ${selectedCal.name ?? 'İsimsiz'}";
          });
        }
      },
      items:
          _calendars.map<DropdownMenuItem<String>>((Calendar calendar) {
            return DropdownMenuItem<String>(
              value: calendar.id,
              child: Text(calendar.name ?? "İsimsiz Takvim"),
            );
          }).toList(),
    );
  }

  Widget _buildSearchResultCard(SearchResult result, {bool disableTap = false}) {
    // Split description to get metadata
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
            // Title
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

            // Main Description
            Text(
              mainDescription,
              style: TextStyle(fontSize: 14),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16),

            // Metadata (if available)
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
    
    // Return the card with or without tap behavior
    return disableTap 
        ? cardContent 
        : GestureDetector(
            onTap: () => _showProgramDetails(result),
            child: cardContent,
          );
  }

  // Show detailed program view in full screen
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
          insetPadding: EdgeInsets.zero, // Full screen dialog
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
                      
                      // Action buttons
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
                                  // Remove from favorites
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
                                  // Add to favorites
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
                                // Implement share functionality
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

  @override
  Widget build(BuildContext context) {
    // Get the auth service to check if user is new
    final authService = Provider.of<AuthService>(context);
    final bool isNewUser = authService.isNewUser;
    
    // Clear new user flag after showing welcome message
    if (isNewUser) {
      // Use Future.delayed to avoid calling setState during build
      Future.delayed(Duration.zero, () {
        authService.clearNewUserFlag();
      });
    }
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
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
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        if (!isNewUser)
                          Icon(
                            Icons.auto_awesome, 
                            color: Colors.amber,
                            size: 20,
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _isLoadingWelcomeMessage
                      ? Center(
                          child: SizedBox(
                            height: 40,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Mesajınız hazırlanıyor...",
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontStyle: FontStyle.italic,
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
                              style: TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                            if (!isNewUser) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    "Powered by AI",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                  ],
                ),
              ),
            ),

            // Search Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search, color: Colors.blue.shade700),
                          SizedBox(width: 10),
                          Text(
                            'Program Ara',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Program veya kategori ara...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadInitialSuggestions(); // Reload initial suggestions
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.send),
                                onPressed: performSearch,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) {
                          // If search field is empty, reload initial suggestions
                          if (value.isEmpty) {
                            _loadInitialSuggestions();
                          }
                        },
                        onSubmitted: (_) => performSearch(),
                      ),
                      SizedBox(height: 16),
                      if (isSearchLoading)
                        Center(child: CircularProgressIndicator())
                      else if (searchErrorMessage.isNotEmpty)
                        Text(
                          searchErrorMessage,
                          style: TextStyle(color: Colors.red),
                        )
                      else if (searchResults.isNotEmpty)
                        SizedBox(
                          height: 200, // Fixed height for search results
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount:
                                searchResults.length > 2
                                    ? 2
                                    : searchResults.length,
                            itemBuilder: (context, index) {
                              return _buildSearchResultCard(
                                searchResults[index],
                              );
                            },
                          ),
                        ),

                      if (searchResults.length > 2)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: Icon(Icons.arrow_forward),
                            label: Text('Tüm Sonuçları Gör'),
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
                                                          // Close the current dialog first
                                                          Navigator.pop(context);
                                                          // Then show the program details
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

            // Calendar Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Etkinlik Ekle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildCalendarDropdown(),
                      SizedBox(height: 16),
                      TextField(
                        controller: _eventController,
                        decoration: InputDecoration(
                          hintText:
                              'Örnek: "Yarın saat 15:00\'da iş görüşmesi var" veya "15 Ocak 2024 10:00-11:30 toplantı"',
                          helperText: 'Tarih ve saat belirtmeyi unutmayın',
                          helperStyle: TextStyle(fontStyle: FontStyle.italic),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Color(0xFF246EE9), width: 2),
                          ),
                          prefixIcon: Icon(Icons.event_note),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _eventController.clear();
                            },
                          ),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _handleEventCreation,
                        icon: Icon(Icons.add),
                        label: Text('Etkinliği Takvime Ekle'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _calendarStatusMessage.contains("eklendi") ? Colors.green.shade50 : 
                                _calendarStatusMessage.contains("hata") || _calendarStatusMessage.contains("eklenemedi") ? Colors.red.shade50 : 
                                Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _calendarStatusMessage.contains("eklendi") ? Colors.green.shade300 : 
                                  _calendarStatusMessage.contains("hata") || _calendarStatusMessage.contains("eklenemedi") ? Colors.red.shade300 : 
                                  Colors.blue.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _calendarStatusMessage.contains("eklendi") ? Icons.check_circle : 
                                  _calendarStatusMessage.contains("hata") || _calendarStatusMessage.contains("eklenemedi") ? Icons.error : 
                                  Icons.info,
                                  color: _calendarStatusMessage.contains("eklendi") ? Colors.green : 
                                        _calendarStatusMessage.contains("hata") || _calendarStatusMessage.contains("eklenemedi") ? Colors.red : 
                                        Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _calendarStatusMessage,
                                    style: TextStyle(
                                      color: _calendarStatusMessage.contains("eklendi") ? Colors.green.shade800 : 
                                            _calendarStatusMessage.contains("hata") || _calendarStatusMessage.contains("eklenemedi") ? Colors.red.shade800 : 
                                            Colors.blue.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_calendarStatusMessage.contains("eklenemedi") || _calendarStatusMessage.contains("hata"))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 28),
                                child: Text(
                                  "Not: Samsung takvimlerinde gecikme olabilir. Lütfen birkaç dakika bekleyip takvim uygulamanızı kontrol edin.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
