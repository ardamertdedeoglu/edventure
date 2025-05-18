import 'package:flutter/material.dart';
import 'models/search_result.dart';
import 'services/semantic_search_service.dart';

class ProgramSearchPage extends StatefulWidget {
  const ProgramSearchPage({super.key});
  @override
  _ProgramSearchPageState createState() => _ProgramSearchPageState();
}

class _ProgramSearchPageState extends State<ProgramSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final SemanticSearchService _searchService = SemanticSearchService();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<SearchResult> results = [];
  List<SearchResult> recentSearchResults = [];
  bool loading = false;
  String errorMessage = '';
  bool _showEmptyState = true;

  @override
  void initState() {
    super.initState();
    // Simulating loading some initial suggestions
    _loadInitialSuggestions();
  }

  void _loadInitialSuggestions() async {
    setState(() {
      loading = true;
    });
    
    await Future.delayed(Duration(milliseconds: 500));
    // Get some default suggestions
    final suggestions = await _searchService.search("yazılım");
    
    setState(() {
      recentSearchResults = suggestions;
      loading = false;
      _showEmptyState = false;
    });
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
      final searchResults = await _searchService.search(_controller.text);
      setState(() {
        results = searchResults;
        // Store as recent results if we got something
        if (searchResults.isNotEmpty) {
          recentSearchResults = searchResults;
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
      print("Arama hatası: $e");
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Widget buildResultCard(SearchResult result) {
    // Calculate a color based on similarity score
    final Color scoreColor = HSLColor.fromAHSL(
      1.0,
      120 * result.similarity, // Hue: 0 (red) to 120 (green)
      0.8, // Saturation
      0.4, // Lightness
    ).toColor();
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              ),
            ),
            SizedBox(height: 8),
            Text(
              result.description,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scoreColor.withOpacity(0.3), width: 1),
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
            Icon(
              Icons.search,
              size: 80,
              color: Colors.blue.withOpacity(0.3),
            ),
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
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.grey.shade600,
                ),
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
                children: recentSearchResults.map((result) => 
                  ActionChip(
                    avatar: Icon(Icons.history, size: 16),
                    label: Text(result.title),
                    onPressed: () {
                      _controller.text = result.title;
                      performSearch();
                    },
                  )
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Semantik Arama'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
                    suffixIcon: _controller.text.isNotEmpty 
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
                    setState(() {});
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
                child: Text(
                  'Semantik Ara',
                  style: TextStyle(fontSize: 16),
                ),
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
              if (_showEmptyState && !loading)
                _buildEmptyState(),
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
                    itemBuilder: (context, index) => buildResultCard(results[index]),
                  ),
                ),
              if (!loading && results.isEmpty && errorMessage.isEmpty && _controller.text.isNotEmpty && !_showEmptyState)
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
                          style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Farklı anahtar kelimelerle tekrar deneyin',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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
