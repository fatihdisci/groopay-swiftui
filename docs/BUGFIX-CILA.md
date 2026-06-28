# BUGFIX & CİLA KAYITLARI (B119)

Bu dökümanda, Groopay iOS SwiftUI uygulamasında gerçekleştirilen iki ana özelliğin detayları ve mimari uyumluluk raporu yer almaktadır.

---

## [B119] Fiş Tarama & Kalem Bölüştürme ve Tekrarlayan Masraflar İstemci Entegrasyonu

### 1. Fiş Tarama & Kalem Bazlı Bölüştürme (Phase 1)
- **OCR Altyapısı**: Apple'ın native `Vision` framework'ü kullanılarak on-device metin tanıma (`VNRecognizeTextRequest`) yapısı kuruldu. Herhangi bir dış API veya sunucu bağımlılığı yoktur. Görseller kalıcı olarak saklanmaz.
- **Regex & Ayrıştırma**: Fiş satırlarındaki fiyatları yakalamak için çoklu binlik ve ondalık ayraçları destekleyen (`1.250,50`, `150.50`, `100` vb.) regex kalıpları geliştirildi. Ara toplam, KDV, Kasiyer vb. metaveri satırları filtrelendi.
- **Kalem Dağılımı**: Her kalem için grup üyeleri arasından atama yapılması sağlandı. Kuruş paylaşımlarındaki küsurat dağıtımı (remainder) deterministik olarak yapıldı ve toplam harcama tutarı ile kuruşu kuruşuna eşleşti.
- **Arayüz**: Plus Jakarta Sans ve Inter fontlarına uyumlu, min 44pt dokunma hedefleri olan `ReceiptScannerView` ekranı geliştirildi. `AddExpenseView` üzerine "Fişten Ekle" butonu entegre edildi.

### 2. Tekrarlayan Masraflar İstemci Motoru (Phase 2)
- **Modeller**: `RecurringExpenseRule` ve `RecurringExpenseExecution` modelleri tanımlandı. Tarih ve minor amount kodlama kurallarına (Double/Float yerine kuruş/minor unit kullanımı) tam sadık kalındı.
- **RPC Entegrasyonu**: Supabase veritabanındaki RPC fonksiyonlarını çağırmak için `CreateRecurringRuleRPCInput`, `UpdateRecurringRuleRPCInput`, `PauseRecurringRuleRPCInput` ve `DeleteRecurringRuleRPCInput` yapıları eklendi.
- **Store & State**: `GroupsStore` sınıfı genişletilerek kural ekleme, düzenleme, duraklatma ve silme metotları eklendi. GroupDetailView açıldığında kuralların yüklenmesi tetiklendi.
- **Arayüz**: `RecurringExpensesView` ekranında kurallar listelendi, aktiflik durumları toggle ile değiştirilebilir kılındı. Sürükleyerek silme desteği eklendi. Kural formunda eşit, alt küme ve özel bölüşüm şekilleri desteklendi.

---

### Mimarî ve Güvenlik Kontrolleri
- ❌ **Float/Double Kullanımı**: Hiçbir finansal hesaplamada veya veri modelinde kayan noktalı sayı kullanılmadı. Kuruş birimi (minor unit) kullanıldı.
- 🔐 **Veri Yazma Güvenliği**: Tüm hassas yazma işlemleri doğrudan tabloya değil, migration ile hazırlanan `SECURITY DEFINER` veritabanı RPC'leri üzerinden yapıldı.
- 🧪 **Unit Test**: `ReceiptParserTests` altında ayrıştırma regex'i, filtreleme kuralları, küsurat bölüşümü ve Türkçe karakter uyumlulukları test edildi.
