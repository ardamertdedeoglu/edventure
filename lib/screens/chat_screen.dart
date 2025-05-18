import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import '../config/environment_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final int _maxContextMessages = 10; // Maximum number of messages to keep for context
  final gemini = Gemini.instance;
  
  // System prompt to keep responses focused on work and travel topics
  final String _systemPrompt = 'Kullanicinin work and travel, yurt disi egitimler ve kampanyalar, yurt disina cikis icin gerekli belgeler, daha onceden work and travel yapmis insanlar, niyet mektubu, cv, work and travel yapilabilecek ulke ve amerika eyaletleri konulari disinda kullanicilarin sorularina cevap vermemelisin. Eger konudan saptiklarini tespit edersen onlardan ozur dileyerek bu soruyu cevaplayamayacagini belirtmelisin';

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add({
      'role': 'assistant',
      'content': 'Merhaba! Work & Travel, yurt dışı eğitimler, vize işlemleri ve başvuru süreçleri hakkında sorularınızı yanıtlamaktan memnuniyet duyarım.',
    });
    
    // Initialize Gemini API if not already initialized
    try {
      Gemini.instance;
    } catch (e) {
      Gemini.init(apiKey: EnvironmentConfig.geminiApiKey);
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

  // Build conversation context for Gemini API
  String _buildConversationContext() {
    // Calculate how many messages to include (up to the last 10)
    final historyMessages = _messages.length > _maxContextMessages 
        ? _messages.sublist(_messages.length - _maxContextMessages) 
        : _messages;
    
    // Start with the system prompt
    String conversationContext = "$_systemPrompt\n\n";
    
    // Add conversation history
    conversationContext += "Aşağıdaki sohbet geçmişine dayanarak en son mesaja cevap ver:\n\n";
    
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
      // Build the conversation context
      final conversationContext = _buildConversationContext();
      
      // Send request to Gemini using the conversation context
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
        title: Text('AI Sohbet'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': 'Merhaba! Work & Travel, yurt dışı eğitimler, vize işlemleri ve başvuru süreçleri hakkında sorularınızı yanıtlamaktan memnuniyet duyarım.',
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
            colors: [Colors.blue.withOpacity(0.05), Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Date chip
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: DateChip(
                date: now,
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
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
                        text: 'AI düşünüyor...',
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
                      color: isUser ? Color(0xFF1B97F3) : Color(0xFFE8E8EE),
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
            
            // Bottom message bar
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
                  // Emoji / attachment button
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined),
                    color: Colors.grey[600],
                    onPressed: () {
                      // Emoji picker could be added here
                    },
                  ),
                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Mesajınızı yazın...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[500]),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                  ),
                  // Send button
                  IconButton(
                    icon: Icon(Icons.send),
                    color: Colors.blue,
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
  
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}





	