import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isLoadingProfile = true;
  final int _maxContextMessages = 15;
  final gemini = Gemini.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _fetchedUserProfile;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      Gemini.instance;
    } catch (e) {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        Gemini.init(apiKey: apiKey);
        print('Gemini API initialized.');
      } else {
        print('Error: GEMINI_API_KEY not found in .env file.');
        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': 'AI Asistan başlatılamadı: API anahtarı eksik.',
            });
            _isLoadingProfile = false;
          });
        }
        return;
      }
    }
    await _fetchUserProfileFromFirestore();
  }

  Future<void> _fetchUserProfileFromFirestore() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content':
                'Merhaba! Premium Kariyer Asistanını kullanmak için lütfen giriş yapın.',
          });
          _isLoadingProfile = false;
        });
      }
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (mounted) {
        if (userDoc.exists) {
          _fetchedUserProfile = userDoc.data() as Map<String, dynamic>?;
          _messages.add({
            'role': 'assistant',
            'content': 'Merhaba ${_fetchedUserProfile?['name'] ?? 'Kullanici'}! Premium Kariyer Asistaniniz olarak size nasil yardimci olabilirim? CV hazirlama, niyet mektubu yazma veya kariyer planlamasi konularinda size ozel tavsiyeler sunabilirim.',
          });
        } else {
          _messages.add({
            'role': 'assistant',
            'content': 'Merhaba! Profil bilgilerinizi henuz bulamadim. Genel kariyer tavsiyeleri icin buradayim ya da profilinizi olusturabilirsiniz.',
          });
        }
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      if (mounted) {
        _messages.add({
          'role': 'assistant',
          'content': 'Profiliniz yuklenirken bir sorun olustu. Genel modda devam edebilirsiniz.',
        });
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _buildPremiumConversationContext() {
    final historyMessages =
        _messages.length > _maxContextMessages
            ? _messages.sublist(_messages.length - _maxContextMessages)
            : _messages;

    final profileName = _fetchedUserProfile?['name'] ?? 'Bilinmiyor';
    final profileAge = _fetchedUserProfile?['age']?.toString() ?? 'Bilinmiyor';
    final profileEducation = _fetchedUserProfile?['department'] ?? 'Bilinmiyor';
    final profileInterests = _fetchedUserProfile?['interests'] ?? 'Bilinmiyor';
    final profileCareerGoals = _fetchedUserProfile?['career_goals'] ?? 'Bilinmiyor';
    final profileSkills = _fetchedUserProfile?['skills'] ?? 'Bilinmiyor';
    final profileExperience = _fetchedUserProfile?['experience'] ?? 'Bilinmiyor';

    String conversationContext = """
Asagidaki kullanici profili bilgilerine gore kisisellestirilmis, detayli ve profesyonel yanitlar ver.
Bu bir premium kullanici ve kariyer danismanligi hizmeti aliyor.

KULLANICI PROFILI:
Isim: $profileName
Yas: $profileAge
Egitim: $profileEducation
Ilgi Alanlari: $profileInterests
Kariyer Hedefleri: $profileCareerGoals
Beceriler: $profileSkills
Deneyim: $profileExperience

SOHBET GECMISI:
""";

    for (final message in historyMessages) {
      String role = message['role'] == 'user' ? 'Kullanici' : 'Asistan';
      conversationContext += "$role: ${message['content']}\n\n";
    }

    return conversationContext;
  }

  void _sendMessage() async {
    final inputText = _controller.text.trim();
    if (inputText.isEmpty) return;
    if (_isLoadingProfile) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen profil bilgilerinizin yuklenmesini bekleyin.')),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': inputText});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final conversationContext = _buildPremiumConversationContext();
      if (Gemini.instance == null) {
         throw Exception("Gemini API not initialized.");
      }

      final response = await gemini.prompt(
        parts: [Part.text(conversationContext)],
      );

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response?.output ?? 'Uzgunum, bir yanit olusturulamadi.',
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
            'content': 'Uzgunum, bir hata olustu: ${e.toString()}',
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF246EE9),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _buildSettingsPanel(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _isLoadingProfile = true;
              });
              _fetchUserProfileFromFirestore();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF246EE9).withOpacity(0.05), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.all(12),
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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
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
            if (!_isLoadingProfile && _messages.isNotEmpty)
              DateChip(
                date: now,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
            Expanded(
              child: _isLoadingProfile
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Premium profiliniz yukleniyor..."),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(15),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isLoading && index == _messages.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: BubbleNormal(
                              text: 'Premium AI dusunuyor...',
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
                            color: isUser ? const Color(0xFF246EE9) : const Color(0xFFE8E8EE),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(0, -2),
                    blurRadius: 5,
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.lightbulb_outline),
                    color: const Color(0xFF246EE9),
                    onPressed: _isLoadingProfile ? null : () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => _buildQuickPromptsPanel(),
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFF246EE9).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoadingProfile,
                          decoration: InputDecoration(
                            hintText: _isLoadingProfile ? 'Profil yukleniyor...' : 'Premium asistana sorunuzu yazin...',
                            border: InputBorder.none,
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          onSubmitted: _isLoadingProfile ? null : (_) => _sendMessage(),
                          style: GoogleFonts.poppins(fontSize: 14),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF246EE9),
                    onPressed: _isLoadingProfile || _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPromptsPanel() {
    final List<Map<String, String>> prompts = [
      {
        'title': 'CV Inceleme',
        'prompt': 'CV\'mi inceleyip guclu ve zayif yonlerini belirtir misin?',
      },
      {
        'title': 'Niyet Mektubu',
        'prompt': 'X sirketine yazilim muhendisi pozisyonu icin bir niyet mektubu taslagi olusturur musun?',
      },
      {
        'title': 'Mulakat Hazirligi',
        'prompt': 'Yazilim muhendisligi pozisyonu icin sik sorulan mulakat sorulari ve cevaplari nelerdir?',
      },
      {
        'title': 'Kariyer Tavsiyesi',
        'prompt': 'Yazilim gelistirme alaninda kariyerimi ilerletmek icin hangi becerilere odaklanmaliyim?',
      },
      {
        'title': 'LinkedIn Profili',
        'prompt': 'LinkedIn profilimi daha etkili hale getirmek icin onerilerin neler?',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Hizli Sorular',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: ListView.builder(
              itemCount: prompts.length,
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                              color: const Color(0xFF246EE9),
                            ),
                          ),
                          const SizedBox(height: 4),
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

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Asistan Ayarlari',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF246EE9)),
            title: Text(
              'Profil Bilgilerini Guncelle',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Asistanin size ozel yanitlar vermesi icin bilgilerinizi guncelleyin',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profil guncelleme ozelligi yakinda eklenecek.', style: GoogleFonts.poppins())),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF246EE9)),
            title: Text(
              'Konusma Gecmisi',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Onceki konusmalarinizi goruntuleyin ve yonetin',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Konusma gecmisi ozelligi yakinda eklenecek.', style: GoogleFonts.poppins())),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download, color: Color(0xFF246EE9)),
            title: Text(
              'Konusmayi Disa Aktar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Bu konusmayi PDF veya metin dosyasi olarak kaydedin',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Konusma disa aktarma ozelligi yakinda eklenecek.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.blue,
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
