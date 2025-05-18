import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  _BudgetPlannerScreenState createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  // Form controller
  final TextEditingController _requestController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  List<TravelRecommendation> _recommendations = [];
  
  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }
  
  // Process user request and generate recommendations
  Future<void> _generateRecommendations() async {
    final userRequest = _requestController.text.trim();
    
    if (userRequest.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen isteğinizi detaylı bir şekilde belirtin';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recommendations = [];
    });
    
    try {
      // Call OpenAI GPT-4 API for better analysis
      final analysisResult = await _analyzeUserRequest(userRequest);
      
      if (analysisResult != null) {
        // Generate recommendations based on the analysis
        final recommendations = await _fetchRecommendations(analysisResult);
        
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'İsteğiniz analiz edilemedi, lütfen tekrar deneyin';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Bir hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
      print('Error generating recommendations: $e');
    }
  }
  
  // Analyze user request using OpenAI API
  Future<Map<String, dynamic>?> _analyzeUserRequest(String request) async {
    try {
      // Use a more capable model for precise analysis
      const apiKey = "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";
      final url = Uri.parse("https://api.openai.com/v1/chat/completions");
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-4",
          "messages": [
            {
              "role": "system",
              "content": """
              Sen bir Work & Travel bütçe planlaması yapan asistansın. Kullanıcıdan alınan Türkçe metni analiz ederek şu bilgileri çıkar:
              1. Hedef ülke veya bölge
              2. Kalış süresi (hafta veya ay olarak)
              3. Kullanıcının bütçesi
              4. Özel tercihler veya kriterler (konaklama, yemek, gezi vb.)
              
              Bu bilgileri JSON formatında şu şekilde döndür:
              {
                "destination": "Hedef ülke veya bölge",
                "duration": "Kalış süresi",
                "budget": "Bütçe miktarı (sayı olarak)",
                "currency": "Para birimi",
                "preferences": ["Tercih 1", "Tercih 2", ...]
              }
              
              Eğer bazı bilgiler metinde verilmemişse, "unknown" olarak işaretle.
              """
            },
            {
              "role": "user",
              "content": request
            }
          ],
          "temperature": 0.3,
          "max_tokens": 500
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          // Extract the JSON object from the response
          return jsonDecode(content);
        } catch (e) {
          print('Error parsing JSON from content: $e');
          print('Content: $content');
          return null;
        }
      } else {
        print('OpenAI API Error: ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error analyzing user request: $e');
      return null;
    }
  }
  
  // Generate recommendations based on the analysis
  Future<List<TravelRecommendation>> _fetchRecommendations(Map<String, dynamic> analysis) async {
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
          "model": "gpt-4",
          "messages": [
            {
              "role": "system",
              "content": """
              Sen bir Work & Travel programları konusunda uzman bir danışmansın. Kullanıcının tercihlerine göre en iyi 3 programı önermen gerekiyor.
              Verilen kullanıcı analizi doğrultusunda, Work & Travel programlarını araştırarak en uygun 3 farklı seçeneği öner.
              Her seçenek için aşağıdaki bilgileri içeren JSON listesi oluştur:
              
              [
                {
                  "title": "Program Başlığı",
                  "location": "Ülke, Şehir",
                  "duration": "Program süresi",
                  "cost": "Maliyet",
                  "description": "Program tanımı (200-250 karakter)",
                  "features": ["Özellik 1", "Özellik 2", "Özellik 3"],
                  "image_url": "Temsili görsel URL"
                },
                ...
              ]
              
              Temsili görseller için şu URL'leri kullan:
              - ABD: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29"
              - Kanada: "https://images.unsplash.com/photo-1503614472-8c93d56e92ce"
              - Avustralya: "https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9"
              - Avrupa: "https://images.unsplash.com/photo-1490642914619-7955a3fd483c"
              - Asya: "https://images.unsplash.com/photo-1493780474015-ba834fd0ce2f"
              
              Gerçekçi ve güncel bilgiler ver. Öneri yaparken bütçe, süre ve kullanıcının diğer tercihlerini dikkate al.
              """
            },
            {
              "role": "user",
              "content": "Kullanıcı analizi: ${jsonEncode(analysis)}"
            }
          ],
          "temperature": 0.7,
          "max_tokens": 1000
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          final List<dynamic> recommendationsJson = jsonDecode(content);
          
          return recommendationsJson.map((json) => TravelRecommendation.fromJson(json)).toList();
        } catch (e) {
          print('Error parsing recommendations JSON: $e');
          return [];
        }
      } else {
        print('OpenAI API Error: ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Yapay Zeka Destekli Bütçe Planlayıcı',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Doğal bir dille nerede ne kadar süre Work & Travel yapmak istediğinizi ve bütçenizi belirtin. Yapay zeka sizin için en uygun programları önerecek.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Input form
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İsteğinizi Belirtin',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _requestController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Örnek: "Amerika\'da 3 ay çalışmak istiyorum ve 3000 dolar bütçem var. Konaklama dahil olsun ve plaja yakın olsun istiyorum."',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Color(0xFF246EE9), width: 2),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _generateRecommendations,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.search),
                              label: Text(_isLoading ? 'İşleniyor...' : 'Programları Bul'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF246EE9),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                textStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Results
                  _isLoading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF246EE9)),
                              SizedBox(height: 16),
                              Text(
                                'Yapay zeka size özel programları arıyor...',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _recommendations.isEmpty && _errorMessage.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.travel_explore,
                                    size: 80,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'İsteğinizi belirtin ve programları arayın',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _recommendations.map((recommendation) {
                                return _buildRecommendationCard(recommendation);
                              }).toList(),
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecommendationCard(TravelRecommendation recommendation) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              recommendation.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: Colors.grey.shade300,
                  child: Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                );
              },
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          Text(
                            recommendation.location,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        recommendation.cost,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Süre: ${recommendation.duration}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  recommendation.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                
                // Features
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.start,
                  children: recommendation.features.map((feature) {
                    return Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      label: Text(
                        feature,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blue.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: Colors.blue.shade50,
                      padding: EdgeInsets.symmetric(horizontal: 2),
                    );
                  }).toList(),
                ),
                
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Show details or contact information
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bu özellik yakında aktif olacak')),
                    );
                  },
                  icon: Icon(Icons.info_outline),
                  label: Text('Detayları Gör'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF246EE9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size(double.infinity, 0),
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Model class for travel recommendations
class TravelRecommendation {
  final String title;
  final String location;
  final String duration;
  final String cost;
  final String description;
  final List<String> features;
  final String imageUrl;
  
  TravelRecommendation({
    required this.title,
    required this.location,
    required this.duration,
    required this.cost,
    required this.description,
    required this.features,
    required this.imageUrl,
  });
  
  factory TravelRecommendation.fromJson(Map<String, dynamic> json) {
    // Process cost to ensure it's properly formatted
    String cost = json['cost'] ?? 'Belirtilmemiş';
    // Limit length if too long
    if (cost.length > 20) {
      cost = '${cost.substring(0, 18)}...';
    }
    
    return TravelRecommendation(
      title: json['title'] ?? 'Program Başlığı',
      location: json['location'] ?? 'Belirtilmemiş Konum',
      duration: json['duration'] ?? 'Belirtilmemiş Süre',
      cost: cost,
      description: json['description'] ?? 'Program hakkında detaylı bilgi bulunmamaktadır.',
      features: List<String>.from(json['features'] ?? []),
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1507608616759-54f48f0af0ee',
    );
  }
} 