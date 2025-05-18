import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CVReviewScreen extends StatefulWidget {
  const CVReviewScreen({Key? key}) : super(key: key);

  @override
  _CVReviewScreenState createState() => _CVReviewScreenState();
}

class _CVReviewScreenState extends State<CVReviewScreen> {
  bool _isUploading = false;
  bool _isReviewing = false;
  bool _isCompleted = false;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // İnceleme süreci kartı
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CV İnceleme Süreci',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Adım 1: CV Yükleme
                      _buildStepItem(
                        index: 1,
                        title: 'CV Yükleme',
                        description: 'PDF veya Word formatında CV\'nizi yükleyin.',
                        isCompleted: _isUploading || _isReviewing || _isCompleted,
                        isActive: !_isUploading && !_isReviewing && !_isCompleted,
                      ),
                      
                      // Adım 2: İnceleme Süreci
                      _buildStepItem(
                        index: 2,
                        title: 'İnceleme Süreci',
                        description: 'Uzmanlarımız CV\'nizi inceliyor (24-48 saat).',
                        isCompleted: _isReviewing || _isCompleted,
                        isActive: _isUploading && !_isReviewing && !_isCompleted,
                      ),
                      
                      // Adım 3: Geri Bildirim
                      _buildStepItem(
                        index: 3,
                        title: 'Geri Bildirim',
                        description: 'Detaylı geri bildirim ve öneriler sunulur.',
                        isCompleted: _isCompleted,
                        isActive: _isReviewing && !_isCompleted,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // CV Yükleme butonu
              if (!_isUploading && !_isReviewing && !_isCompleted)
                ElevatedButton.icon(
                  onPressed: () {
                    // CV yükleme işlemi
                    _uploadCV();
                  },
                  icon: Icon(Icons.upload_file),
                  label: Text(
                    'CV\'nizi Yükleyin',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF246EE9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              
              // İnceleme sürecinde
              if (_isUploading && !_isReviewing)
                _buildStatusCard(
                  icon: Icons.hourglass_top,
                  title: 'CV\'niz Kuyruğa Alındı',
                  description: 'CV\'niz inceleme kuyruğuna alındı. Uzmanlarımız en kısa sürede incelemeye başlayacak.',
                  color: Colors.orange,
                ),
              
              // İnceleme süreci devam ediyor
              if (_isReviewing && !_isCompleted)
                _buildStatusCard(
                  icon: Icons.pending_actions,
                  title: 'İnceleme Süreci Devam Ediyor',
                  description: 'Uzmanlarımız CV\'nizi inceliyor. Bu işlem 24-48 saat sürebilir.',
                  color: Colors.blue,
                ),
              
              // İnceleme tamamlandı
              if (_isCompleted)
                _buildStatusCard(
                  icon: Icons.check_circle,
                  title: 'İnceleme Tamamlandı',
                  description: 'CV incelemeniz tamamlandı! Geri bildirimleri görüntülemek için aşağıdaki butona tıklayın.',
                  color: Colors.green,
                  button: ElevatedButton.icon(
                    onPressed: () {
                      // Geri bildirimleri görüntüle
                      _showFeedback();
                    },
                    icon: Icon(Icons.visibility),
                    label: Text(
                      'Geri Bildirimleri Görüntüle',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              
              // Add fixed height spacer instead of flexible Spacer
              SizedBox(height: 32),
              
              // Yardım notu
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 24), // Add bottom margin
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade700),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'CV\'niz hakkında sorularınız varsa, uygulama içi sohbet özelliğimizi kullanarak uzmanlarımıza danışabilirsiniz.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
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
    );
  }
  
  Widget _buildStepItem({
    required int index,
    required String title,
    required String description,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Adım numarası veya tamamlandı ikonu
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? Color(0xFF246EE9)
                    : Colors.grey.shade300,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    index.toString(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isActive || isCompleted ? Colors.black87 : Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isActive || isCompleted ? Colors.black54 : Colors.grey.shade400,
                ),
              ),
              if (!isLast)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  height: 24,
                  width: 2,
                  color: isCompleted ? Colors.green : Colors.grey.shade300,
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    Widget? button,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            if (button != null) ...[
              SizedBox(height: 16),
              button,
            ],
          ],
        ),
      ),
    );
  }
  
  // CV yükleme simülasyonu
  void _uploadCV() {
    setState(() {
      _isUploading = true;
    });
    
    // 2 saniye sonra inceleme sürecine geç
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isReviewing = true;
        });
        
        // 3 saniye sonra incelemeyi tamamla (demo için)
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isCompleted = true;
            });
          }
        });
      }
    });
  }
  
  // Geri bildirim gösterme
  void _showFeedback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'CV Geri Bildirimi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Color(0xFF246EE9),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeedbackSection(
                title: 'Güçlü Yönler',
                items: [
                  'Teknik beceriler bölümü çok detaylı ve etkileyici',
                  'Proje deneyimleri iyi açıklanmış',
                  'Eğitim geçmişi net ve anlaşılır',
                ],
                icon: Icons.thumb_up,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              _buildFeedbackSection(
                title: 'İyileştirilmesi Gereken Yönler',
                items: [
                  'Özet bölümü daha kişiselleştirilmiş olabilir',
                  'Bazı başarılar sayısal verilerle desteklenebilir',
                  'Dil becerileri bölümü daha detaylı olabilir',
                ],
                icon: Icons.build,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              _buildFeedbackSection(
                title: 'Öneriler',
                items: [
                  'Her iş deneyimi için ölçülebilir başarılar ekleyin',
                  'ATS uyumlu anahtar kelimeler kullanın',
                  'Tasarımı daha modern bir şablonla güncelleyin',
                ],
                icon: Icons.lightbulb,
                color: Colors.blue,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF246EE9),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Anladım',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeedbackSection({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
} 