import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class PremiumChatScreen extends StatefulWidget {
  const PremiumChatScreen({super.key});
  
  @override
  _PremiumChatScreenState createState() => _PremiumChatScreenState();
}

class _PremiumChatScreenState extends State<PremiumChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final int _maxContextMessages = 15; // Premium'da daha fazla bağlam
  final gemini = Gemini.instance;
  
  // Premium kullanıcıları için önceden tanımlanmış kişisel bilgiler
  final Map<String, String> _userProfile = {
    'name': 'Arda Mert',
    'age': '18',
    'education': 'Yıldız Teknik Üniversitesi, Bilgisayar Mühendisliği',
    'interests': 'Yazılım geliştirme, Yapay zeka, Mobil uygulama',
    'career_goals': 'Büyük bir teknoloji şirketinde yazılım mühendisi olarak çalışmak',
    'skills': 'Flutter, Dart, Python, Javascript, Firebase',
    'experience': '1 yıl staj deneyimi, 1 mobil uygulama projesi'
  };

  @override
  void initState() {
    super.initState();
    // Premium karşılama mesajı
    _messages.add({
      'role': 'assistant',
      'content': 'Merhaba ${_userProfile['name']}! Premium Kariyer Asistanınız olarak size nasıl yardımcı olabilirim? CV hazırlama, niyet mektubu yazma veya kariyer planlaması konularında size özel tavsiyeler sunabilirim.',
    });
    
    // Initialize Gemini API if not already initialized
    try {
      Gemini.instance;
    } catch (e) {
      Gemini.init(apiKey: 'AIzaSyB0kqcjUvlKL2GViBfCSgP9tzKn212xc6g');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Premium kullanıcılar için gelişmiş bağlam oluşturma
  String _buildPremiumConversationContext() {
    // Daha fazla mesaj geçmişi (15 mesaj)
    final historyMessages = _messages.length > _maxContextMessages 
        ? _messages.sublist(_messages.length - _maxContextMessages) 
        : _messages;
    
    // Kullanıcı profili bilgilerini ekleyerek kişiselleştirilmiş yanıtlar al
    String conversationContext = """
Aşağıdaki kullanıcı profili bilgilerine göre kişiselleştirilmiş, detaylı ve profesyonel yanıtlar ver.
Bu bir premium kullanıcı ve kariyer danışmanlığı hizmeti alıyor.

KULLANICI PROFİLİ:
İsim: ${_userProfile['name']}
Yaş: ${_userProfile['age']}
Eğitim: ${_userProfile['education']}
İlgi Alanları: ${_userProfile['interests']}
Kariyer Hedefleri: ${_userProfile['career_goals']}
Beceriler: ${_userProfile['skills']}
Deneyim: ${_userProfile['experience']}

SOHBET GEÇMİŞİ:
""";
    
    for (final message in historyMessages) {
      String role = message['role'] == 'user' ? 'Kullanıcı' : 'Asistan';
      conversationContext += "$role: ${message['content']}\n\n";
    }
    
    return conversationContext;
  }

  // Function to handle sending a message
  void _sendMessage() async {
    // Get and trim the input text
    final inputText = _controller.text.trim();
    // Do nothing if input is empty
    if (inputText.isEmpty) return;

    // Add the user's message to the chat
    setState(() {
      _messages.add({'role': 'user', 'content': inputText});
      _isLoading = true;
    });
    // Clear the input field
    _controller.clear();
    
    _scrollToBottom();

    try {
      // Build the premium conversation context with user profile
      final conversationContext = _buildPremiumConversationContext();
      
      // Send request to Gemini using the enhanced context
      final response = await gemini.prompt(
        parts: [Part.text(conversationContext)]
      );

      if (mounted) {
        // Add the bot's response to the chat
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response?.output ?? 'Üzgünüm, bir yanıt oluşturulamadı.',
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Üzgünüm, bir hata oluştu: ${e.toString()}',
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Premium AI Asistan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF246EE9),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Premium ayarlar menüsü
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _buildSettingsPanel(),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': 'Merhaba ${_userProfile['name']}! Premium Kariyer Asistanınız olarak size nasıl yardımcı olabilirim? CV hazırlama, niyet mektubu yazma veya kariyer planlaması konularında size özel tavsiyeler sunabilirim.',
                });
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Premium badge
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.amber.shade700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Premium Deneyim',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Date chip
            DateChip(
              date: now,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(15),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator as the last item if loading
                  if (_isLoading && index == _messages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: BubbleNormal(
                        text: 'Premium AI düşünüyor...',
                        isSender: false,
                        color: Color(0xFFE8E8EE),
                        tail: true,
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }
                  
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  final text = message['content'] ?? '';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: BubbleNormal(
                      text: text,
                      isSender: isUser,
                      color: isUser ? Color(0xFF246EE9) : Color(0xFFE8E8EE),
                      tail: true,
                      textStyle: TextStyle(
                        fontSize: 16,
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Bottom message bar with premium styling
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, -2),
                    blurRadius: 5,
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quick prompts button (premium feature)
                  IconButton(
                    icon: Icon(Icons.lightbulb_outline),
                    color: Color(0xFF246EE9),
                    onPressed: () {
                      // Show quick prompts
                      showModalBottomSheet(
                        context: context,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => _buildQuickPromptsPanel(),
                      );
                    },
                  ),
                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Color(0xFF246EE9).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Premium asistana sorunuzu yazın...',
                            border: InputBorder.none,
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ),
                  ),
                  // Send button
                  IconButton(
                    icon: Icon(Icons.send),
                    color: Color(0xFF246EE9),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Premium quick prompts panel
  Widget _buildQuickPromptsPanel() {
    final List<Map<String, String>> prompts = [
      {
        'title': 'CV İnceleme',
        'prompt': 'CV\'mi inceleyip güçlü ve zayıf yönlerini belirtir misin?'
      },
      {
        'title': 'Niyet Mektubu',
        'prompt': 'X şirketine yazılım mühendisi pozisyonu için bir niyet mektubu taslağı oluşturur musun?'
      },
      {
        'title': 'Mülakat Hazırlığı',
        'prompt': 'Yazılım mühendisliği pozisyonu için sık sorulan mülakat soruları ve cevapları nelerdir?'
      },
      {
        'title': 'Kariyer Tavsiyesi',
        'prompt': 'Yazılım geliştirme alanında kariyerimi ilerletmek için hangi becerilere odaklanmalıyım?'
      },
      {
        'title': 'LinkedIn Profili',
        'prompt': 'LinkedIn profilimi daha etkili hale getirmek için önerilerin neler?'
      },
    ];
    
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Hızlı Sorular',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: ListView.builder(
              itemCount: prompts.length,
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _controller.text = prompt['prompt']!;
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prompt['title']!,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF246EE9),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            prompt['prompt']!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Premium settings panel
  Widget _buildSettingsPanel() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Asistan Ayarları',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.person, color: Color(0xFF246EE9)),
            title: Text(
              'Profil Bilgilerini Güncelle',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Asistanın size özel yanıtlar vermesi için bilgilerinizi güncelleyin',
              style: GoogleFonts.poppins(
                fontSize: 12,
              ),
            ),
            onTap: () {
              // Profil güncelleme ekranı
              Navigator.pop(context);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.history, color: Color(0xFF246EE9)),
            title: Text(
              'Konuşma Geçmişi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Önceki konuşmalarınızı görüntüleyin ve yönetin',
              style: GoogleFonts.poppins(
                fontSize: 12,
              ),
            ),
            onTap: () {
              // Konuşma geçmişi ekranı
              Navigator.pop(context);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.file_download, color: Color(0xFF246EE9)),
            title: Text(
              'Konuşmayı Dışa Aktar',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Bu konuşmayı PDF veya metin dosyası olarak kaydedin',
              style: GoogleFonts.poppins(
                fontSize: 12,
              ),
            ),
            onTap: () {
              // Dışa aktarma işlemi
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Konuşma dışa aktarıldı', 
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 