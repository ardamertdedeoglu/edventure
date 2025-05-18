# Ana Sayfa Özelliği

Bu belge, uygulamaya eklenen ana sayfa özelliğini açıklamaktadır.

## Genel Bakış

Ana sayfa özelliği, uygulamanın merkezi bir navigasyon noktası olarak tasarlanmıştır. Kullanıcılar için sezgisel ve kolay erişilebilir bir deneyim sunarak, uygulamanın temel işlevlerini tek bir yerden yönetmelerine olanak tanır.

### Amaç

1. Kullanıcıların uygulamayı daha kolay tanımasını sağlamak
2. Daha önce ayrı sekmelerde bulunan Semantik Arama ve Takvim özelliklerini tek bir merkezi ekrana entegre etmek
3. Kullanıcı deneyimini iyileştirmek ve uygulamada geçirilen süreyi artırmak
4. Sadeleştirilmiş bir navigasyon yapısı sunmak (3 ana sekme)

## Tasarım ve Uygulamanın Özellikleri

### Ana Ekran Bileşenleri

1. **Karşılama Başlığı**: Kullanıcıyı karşılayan ve genel amaç hakkında bilgi veren başlık alanı
2. **Semantik Arama Kartı**: Program ve kategorileri aramak için arama kutusu içeren kart
3. **Takvim Kartı**: Etkinlik ekleme için doğal dil girişi ve takvim seçici içeren kart

### Semantik Arama Özellikleri

- Program ve kategorileri aramak için arama kutusu
- Görsel olarak geliştirilmiş arama sonuçları
- Özet sonuç görünümü ve tüm sonuçlara erişim imkanı
- Benzerlik skorları ve detaylı metadata görüntüleme

### Takvim Özellikleri

- Etkinlik ekleme için doğal dil girişi 
- Takvim seçici
- Durum bildirimleri ve geribildirim

## Navigasyon Entegrasyonu

### Değişiklikler
- Daha sadeleştirilmiş bir gezinme çubuğu ile 3 ana sekme:
  1. Görevler
  2. Ana Sayfa (ortada)
  3. Profil

- Sohbet özelliği artık her ekranın AppBar'ında erişilebilir:
  - Ana Sayfa AppBar'ında sohbet butonu
  - Görevler AppBar'ında sohbet butonu

### Ana Sayfa Konumu
- Ana sayfa, alt gezinme çubuğunun ortasında belirgin bir şekilde konumlandırılmıştır
- Özel bir gezinme düğmesi olarak tasarlanmıştır
- Yükseltilmiş yüzen düğme (FloatingActionButton) olarak vurgulanmıştır
- Görsel olarak öne çıkarılarak ana sayfa hissi güçlendirilmiştir

## Kullanıcı Deneyimi İyileştirmeleri

1. **Tek Ekranda Bütünleşik Deneyim**: Kullanıcılar tüm önemli özellikleri tek bir ana sayfada görebilir
2. **Azaltılmış Gezinme**: Sadece 3 ana sekme ve kolay erişilebilir sohbet özelliği
3. **Sezgisel Tasarım**: Kartlara bölünmüş, kolay anlaşılır arayüz
4. **Görsel Hiyerarşi**: Önemli içerik ve eylemler ön plana çıkarılmıştır

## Teknik Uygulama

- Uygulama içi navigasyon için `Navigator.push` kullanımı
- Ana sayfada takvim ve arama özelliklerinin entegrasyonu
- Alt navigasyon çubuğunda özelleştirilmiş ana düğme için `Stack` kullanımı
- AppBar'larda tutarlı sohbet butonu uygulaması

## Gelecek Geliştirmeler

1. Ana sayfaya daha fazla widget eklemek (hava durumu, yaklaşan etkinlikler, kişiselleştirilmiş öneriler)
2. Kullanıcı tercihlerine göre ana sayfayı özelleştirme seçenekleri
3. Veri analizi ve kullanıcı davranışına dayalı içerik gösterimi 