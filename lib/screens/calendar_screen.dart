import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  TextEditingController _controller = TextEditingController();
  List<Calendar> _calendars = [];
  Calendar? _selectedCalendar;
  String _statusMessage = "Henüz etkinlik eklenmedi";

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones(); // Timezone verisini başlat
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Hem okuma hem yazma izni isteyelim
    var calendarStatus = await Permission.calendarWriteOnly.request();
    
    if (calendarStatus.isGranted) {
      _loadCalendars();
    } else {
      setState(() {
        _statusMessage = "Takvim izni verilmedi: $calendarStatus";
      });
      print("Takvim izni verilmedi: $calendarStatus");
    }
  }
  
  Future<void> _loadCalendars() async {
    try {
      var calendarsResult = await _calendarPlugin.retrieveCalendars();
      
      print("Mevcut takvimler: ${calendarsResult.data?.map((c) => "${c.id}: ${c.name}").join(", ")}");
      
      // Null güvenliği için boş liste kullan
      final calList = calendarsResult.data as List<Calendar>? ?? <Calendar>[];
      
      setState(() {
        _calendars = calList;
        // Eğer takvimler varsa ve daha önce seçilmiş bir takvim yoksa, ilkini seçelim
        if (calList.isNotEmpty && _selectedCalendar == null) {
          _selectedCalendar = calList.first;
        }
        
        if(calList.isEmpty) {
          _statusMessage = "Kullanılabilir takvim bulunamadı";
        } else {
          _statusMessage = "Kullanılacak takvim: ${_selectedCalendar?.name ?? 'Seçilmedi'}";
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Takvimler yüklenirken hata: $e";
      });
      print("Takvimler yüklenirken hata: $e");
    }
  }

  Future<Map<String, dynamic>?> _extractEvent(String text) async {
    const apiKey = "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";
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    try {
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
              "content": "Kullanıcının etkinlik cümlesinden başlık, başlangıç ve bitiş zamanını çıkar. Şu formatta JSON ver: {\"title\":\"\", \"start\":\"yyyy-MM-dd HH:mm\", \"end\":\"yyyy-MM-dd HH:mm\"}"
            },
            {
              "role": "user",
              "content": text
            }
          ],
          "temperature": 0.2
        }),
      );

      print("API yanıtı: ${response.statusCode}");
      print("API yanıt gövdesi: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return jsonDecode(content);
      } else {
        print("API Hatası: ${response.body}");
        setState(() {
          _statusMessage = "API Hatası: ${response.statusCode}";
        });
        return null;
      }
    } catch (e) {
      print("İstek hatası: $e");
      setState(() {
        _statusMessage = "İstek hatası: $e";
      });
      return null;
    }
  }

  Future<void> _handleUserInput() async {
    final input = _controller.text;
    if (_selectedCalendar == null || input.isEmpty) {
      setState(() {
        _statusMessage = "Takvim seçilmedi veya metin boş";
      });
      return;
    }

    setState(() {
      _statusMessage = "Etkinlik ayıklanıyor...";
    });

    final eventData = await _extractEvent(input);

    print("Ayıklanan veri: $eventData");

    if (eventData != null) {
      try {
        setState(() {
          _statusMessage = "Etkinlik oluşturuluyor...";
        });
        
        final start = DateTime.parse(eventData['start']);
        final end = DateTime.parse(eventData['end']);
        
        // TZDateTime nesneleri oluştur
        final tzStart = tz.TZDateTime.from(start, tz.local);
        final tzEnd = tz.TZDateTime.from(end, tz.local);
        
        print("Etkinlik oluşturuluyor: ${eventData['title']}");
        print("Başlangıç: $tzStart");
        print("Bitiş: $tzEnd");
        print("Takvim ID: ${_selectedCalendar!.id}");
        
        final event = Event(
          _selectedCalendar!.id,
          title: eventData['title'],
          start: tzStart,
          end: tzEnd,
        );

        final result = await _calendarPlugin.createOrUpdateEvent(event);
        print("Etkinlik ekleme sonucu: $result");
        
        if (result?.isSuccess == true) {
          setState(() {
            _statusMessage = "Etkinlik eklendi: ${event.title}";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Etkinlik eklendi: ${event.title}")),
          );
          _controller.clear();
          
          // Takvim uygulamasını açmayı deneyelim
          _openCalendarApp();
        } else {
          setState(() {
            _statusMessage = "Etkinlik eklenemedi: ${result?.errors.join(", ")}";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Etkinlik eklenemedi: ${result?.errors.join(", ")}")),
          );
        }
      } catch (e) {
        setState(() {
          _statusMessage = "Hata: $e";
        });
        print("Etkinlik oluşturma hatası: $e");
      }
    } else {
      setState(() {
        _statusMessage = "Etkinlik bilgileri ayıklanamadı";
      });
    }
  }
  
  Future<void> _openCalendarApp() async {
    // Bu plugin'de takvim uygulamasını açma metodu olmadığı için
    // takvim açma işlemini yapamıyoruz, ama kullanıcıyı bilgilendirebiliriz
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Lütfen manuel olarak Takvim uygulamasını açın ve etkinliklerinizi kontrol edin"),
        duration: Duration(seconds: 5),
      ),
    );
    
    setState(() {
      _statusMessage = "Takvim uygulamasını manuel olarak açmalısınız";
    });
  }

  Widget _buildCalendarDropdown() {
    if (_calendars.isEmpty) {
      return Text("Kullanılabilir takvim bulunamadı", style: TextStyle(color: Colors.red));
    }
    
    return DropdownButton<String>(
      hint: Text("Takvim Seçin"),
      value: _selectedCalendar?.id,
      isExpanded: true,
      onChanged: (String? newValue) {
        if (newValue != null) {
          final selectedCal = _calendars.firstWhere((cal) => cal.id == newValue, 
              orElse: () => _calendars.first);
          setState(() {
            _selectedCalendar = selectedCal;
            _statusMessage = "Seçilen takvim: ${selectedCal.name ?? 'İsimsiz'}";
          });
        }
      },
      items: _calendars.map<DropdownMenuItem<String>>((Calendar calendar) {
        return DropdownMenuItem<String>(
          value: calendar.id,
          child: Text(calendar.name ?? "İsimsiz Takvim"),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Akıllı Takvim Asistanı"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCalendars,
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCalendarDropdown(),
            SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains("Hata") ? Colors.red : Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Etkinlik cümlesi yaz (örn: 3 Haziran saat 14:00'te randevum var)",
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleUserInput,
              icon: Icon(Icons.event),
              label: Text("Etkinliği Takvime Ekle"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openCalendarApp,
              icon: Icon(Icons.calendar_month),
              label: Text("Takvim Uygulamasını Aç"),
            ),
          ],
        ),
      ),
    );
  }
}