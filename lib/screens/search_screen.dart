import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_result.dart';
import '../services/semantic_search_service.dart';
import '../services/auth_service.dart';
import '../services/program_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ProgramService _programService = ProgramService();

  List<SearchResult> results = [];
  List<SearchResult> recentSearchResults = [];
  bool loading = false;
  String errorMessage = '';
  bool _showEmptyState = true;
  bool _useLocalData =
      true; // Set to true to use local JSON data instead of API

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to schedule the loading after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      loading = true;
    });

    // Load programs from JSON
    await _programService.loadPrograms();

    // Load initial suggestions
    _loadInitialSuggestions();

    setState(() {
      loading = false;
    });
  }

  void _loadInitialSuggestions() async {
    try {
      List<SearchResult> suggestions;

      if (_useLocalData) {
        // Use local JSON data
        suggestions = _programService.searchPrograms("program");
      } else {
        // Use remote API
        final authService = Provider.of<AuthService>(context, listen: false);
        final searchService = SemanticSearchService(authService: authService);
        suggestions = await searchService.search("yazılım");
      }

      if (mounted) {
        setState(() {
          recentSearchResults = suggestions;
          _showEmptyState = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
        });
      }
      print("Öneriler yüklenirken hata: $e");
    }
  }

  Future<void> performSearch() async {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Lütfen arama sorgusu girin';
      });
      return;
    }

    setState(() {
      loading = true;
      results = [];
      errorMessage = '';
      _showEmptyState = false;
    });

    try {
      List<SearchResult> searchResults;

      if (_useLocalData) {
        // Use local JSON data for search
        searchResults = _programService.searchPrograms(_controller.text.trim());
      } else {
        // Use remote API for search
        try {
          final authService = Provider.of<AuthService>(context, listen: false);

          if (!authService.isAuthenticated) {
            setState(() {
              loading = false;
              errorMessage =
                  'API aramak için giriş yapmalısınız. Lütfen giriş yapın veya yerel modu kullanın.';
              _useLocalData = true; // Switch back to local mode
            });
            return;
          }

          final searchService = SemanticSearchService(authService: authService);
          searchResults = await searchService.search(_controller.text.trim());
        } catch (apiError) {
          print("API error: $apiError");
          // Fall back to local search if API fails
          setState(() {
            _useLocalData = true; // Switch to local mode
          });
          searchResults = _programService.searchPrograms(
            _controller.text.trim(),
          );
        }
      }

      if (mounted) {
        setState(() {
          results = searchResults;
          // Store as recent results if we got something
          if (searchResults.isNotEmpty) {
            recentSearchResults = searchResults;
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          loading = false;
        });
      }
      print("Arama hatası: $e");
    }
  }

  Widget buildResultCard(SearchResult result) {
    // Calculate a color based on similarity score
    final Color scoreColor =
        HSLColor.fromAHSL(
          1.0,
          120 * result.similarity, // Hue: 0 (red) to 120 (green)
          0.8, // Saturation
          0.4, // Lightness
        ).toColor();

    // Split description to get metadata
    final String mainDescription = result.description.split('\n\n').first;
    final String metadata =
        result.description.contains('\n\n')
            ? result.description.split('\n\n').last
            : '';

    return Card(
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
            ),
            Divider(height: 16),

            // Main Description
            Text(mainDescription, style: TextStyle(fontSize: 14)),
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
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12),

            // Similarity score
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scoreColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Benzerlik: ${(result.similarity * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 80, color: Colors.blue.withOpacity(0.3)),
            SizedBox(height: 24),
            Text(
              'Semantik Arama',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: Text(
                'Anahtar kelimeler yerine doğal dil ile aramak isteğinizi ifade edin',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(height: 32),
            if (recentSearchResults.isNotEmpty) ...[
              Text(
                'Popüler Konular',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children:
                    recentSearchResults
                        .map(
                          (result) => ActionChip(
                            avatar: Icon(Icons.history, size: 16),
                            label: Text(result.title),
                            onPressed: () {
                              _controller.text = result.title;
                              performSearch();
                            },
                          ),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Fırsat Arama'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Toggle between local and API search
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                Text(
                  _useLocalData ? 'Yerel Arama' : 'API Arama',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _useLocalData ? Colors.green : Colors.orange,
                  ),
                ),
                Switch(
                  value: _useLocalData,
                  activeColor: Colors.green,
                  activeTrackColor: Colors.green.withOpacity(0.5),
                  inactiveThumbColor: Colors.orange,
                  inactiveTrackColor: Colors.orange.withOpacity(0.5),
                  onChanged: (value) {
                    setState(() {
                      _useLocalData = value;
                      // Clear any previous errors
                      errorMessage = '';
                      // Reload suggestions with the new data source
                      _loadInitialSuggestions();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.withOpacity(0.05), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Mobil uygulama geliştirme hakkında bilgi ver...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon:
                        _controller.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _showEmptyState = true;
                                  results.clear();
                                });
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onSubmitted: (_) => performSearch(),
                  onChanged: (value) {
                    setState(
                      () {},
                    ); // Just to update the clear button visibility
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: Text('Ara', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(height: 20),
              if (errorMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              if (_showEmptyState && !loading) _buildEmptyState(),
              if (loading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Semantik arama yapılıyor...',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!loading && results.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder:
                        (context, index) => buildResultCard(results[index]),
                  ),
                ),
              if (!loading &&
                  results.isEmpty &&
                  errorMessage.isEmpty &&
                  _controller.text.isNotEmpty &&
                  !_showEmptyState)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Sonuç bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _useLocalData
                              ? 'Programa özgü başka anahtar kelimeler deneyin veya API aramasına geçin'
                              : 'Farklı anahtar kelimelerle tekrar deneyin',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        if (_useLocalData)
                          OutlinedButton.icon(
                            icon: Icon(Icons.swap_horiz),
                            label: Text('API Aramasına Geç'),
                            onPressed: () {
                              setState(() {
                                _useLocalData = false;
                                performSearch();
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
