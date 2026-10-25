# Hafta 1 — Geliştirme ve Yapay Zekâ Eşliğinde Programlama Günlüğü (eski adı: AGENT.md)

> Bu dosya proje sahibinin geliştirme sürecine ilişkin notlarıdır; geçmiş oturum, model kullanımı ve maliyet iddiaları kod deposundan bağımsız olarak doğrulanamaz. G2 kullanıcı yorumu kanıtının ayrıntısı ve doğrulanmış test çıktısı için README'ye bakın.

Bu doküman, **SentinelOps (Enterprise ServiceNow ITSM Klonu)** projesinin geliştirilmesi sırasında insan yazılımcı ile Antigravity içindeki **Gemini 3.8 Flash** ve ayrıca **GitHub Copilot** kullanılarak yürütülen çift programlama (pair-programming) sürecini, karşılaşılan teknik sorunları, uygulanan stratejileri ve çıkarılan dersleri açıklar. Copilot'un model/sürüm bilgisi kaydedilmemiştir.

---

## 1. Proje Özeti ve Başlangıç Hedefi

- **Proje Adı:** SentinelOps
- **Hedef:** Fortune 500 firmalarının kullandığı **ServiceNow (Incident Management)** ürününün aort dilimini (bilet yaşam döngüsü, SLA motoru, öncelik matrisi) klonlamak ve benzer geçmiş olayları eşleştiren **Smart Incident Knowledge Matcher** katmanını geliştirmek. README'de bağlantısı verilen G2 incelemesinde küçük ekipler için kurulum/öğrenme eğrisi zorluğu anlatılır; bu küçük olay yönetimi dilimindeki hazır şablon ve geçmiş çözüm özellikleri başlangıç yükünü azaltmayı hedefler.
- **Teknoloji Yığını:** Ruby 3.3.8, Ruby on Rails 8.1.4, SQLite3, Pure Enterprise Vanilla CSS (Light Theme), Minitest + `travel_to` Time-Travel Engine.

---

## 2. Karşılaşılan Kritik Krizler ve Çözüm Süreci

Geliştirme sürecinde hiçbir şey "sihirli" bir şekilde tek komutta bitmedi. Ajanın takıldığı, insan müdahalesinin gerektiği ve birlikte çözülen 3 ana teknik kriz yaşandı:

### Kriz 1: Windows MinGW / MSYS2 Toolchain Kilitlenmesi ve WSL Pivotu
- **Sorun:** Proje ilk etapta Windows PowerShell ortamında çalıştırılmak istendi. Ancak `bundle install` başlatıldığında, Windows altındaki MSYS2 paket yöneticisi `pacman-key` PGP anahtar doğrulama hatası verdi ve native gem derleme (bootsnap, nokogiri) dakikalarca askıda kaldı. Ajan arka planda kurulumu beklemeyi önerdi.
- **İnsan Müdahalesi:** Yazılımcı duruma müdahale ederek *"wsl de çalıştı zaten"* uyarısında bulundu.
- **Ajanın Adaptasyonu:** Ajan Windows task'ını hemen iptal etti (`kill`), WSL (Ubuntu) ortamını taradı ve projenin zaten Linux üzerinde `ruby 3.3.8` ve Rails ile hazır olduğunu tespit etti. Tüm geliştirme, migrasyon ve test süreçleri derhal WSL ortamına taşınarak kriz aşıldı.

### Kriz 2: Rails 8 Enum İsim ve Metot Çakışması (`ArgumentError`)
- **Sorun:** ServiceNow mimarisine geçerken `state` (new_ticket, in_progress, on_hold, resolved, closed) adında yeni bir enum eklendi. Ancak eski kod tabanındaki `status` enum'ı da `:resolved` değerine sahipti. `bin/rails db:seed` çalıştırıldığında Rails şu kritik hatayı fırlattı:
  ```text
  ArgumentError: You tried to define an enum named "status" on the model "Incident", 
  but this will generate an instance method "resolved?", which is already defined by another enum.
  ```
- **Çözüm:** Ajan duplicate enum yerine modern bir geriye dönük uyumluluk katmanı tasarladı:
  - `state` ana enum olarak tanımlandı.
  - `status` ve `reported?`, `investigating?` gibi eski çağrılar için method override yapıldı ve `before_save :sync_legacy_status_column` callback'i ile veritabanındaki integer sütun hatasız senkronize edildi.

### Kriz 3: Puma Sunucusunun Eski Şema Önbelleği (Schema Cache Stale)
- **Sorun:** Migrasyon başarıyla uygulandıktan sonra canlı sunucuya atılan HTTP isteklerinde:
  ```text
  RuntimeError (Undeclared attribute type for enum 'state' in Incident. Enums must be backed by a database column...)
  ```
  hatası alındı.
- **Neden:** Arka planda çalışan Puma prosesi, migrasyondan önceki SQLite şemasını RAM'de tutuyordu.
- **Çözüm:** Ajan sunucu prosesini sonlandırdı, `tmp/pids/server.pid` dosyasını sildi ve WSL üzerinde taze şema ile sunucuyu yeniden ayağa kaldırdı. Sayfa anında `200 OK` yanıtı vermeye başladı.

---

## 3. İşe Yarayan Prompt Stratejileri

| Strateji | Neden İşe Yaradı? | Örnek |
| :--- | :--- | :--- |
| **Tam Etki Alanı Spesifikasyonu (Domain Modeling)** | Genel bir "bilet sistemi yap" demek yerine alanları (`number: INC00xxxx`, `caller_id`, `service_affected`, `priority P1-P4`, `state`) listelemek daha hedefli bir taslak üretti; her çıktı yine kod incelemesi ve test gerektirir. | *"Incident modelini number: INC001024, caller_id, service_affected, priority P1-P4 standartlarıyla güncelle"* |
| **Sınır Değerli Test Direktifleri (`travel_to`)** | "Test yaz" yerine doğrudan zaman sınırlarını belirten komut verildiğinde ajan Minitest `TimeHelpers` kütüphanesini kusursuz entegre etti. | *"travel_to kullanarak P1 için 10. dakikada ihlal olmamasını, 20. dakikada ise sla_breached durumuna düştüğünü test et"* |
| **Kullanıcı ihtiyacının doğrudan tanımı** | Kurulum ve öğrenme yükünü azaltma hedefi hazır olay şablonları, varsayılan SLA'lar ve benzer geçmiş çözümü tek tıkla uygulama akışına yansıtıldı. İlgili G2 incelemesi ve kaynak sınırlamaları README'de belgelenmiştir. | *"Bilet açıldığında benzer geçmiş çözümü bulup tek tıkla uygulasın"* |

---

## 4. İnsan vs. Yapay Zekâ Rol Dağılımı

### Kullanılan AI araçları ve maliyet kaydı

- **Antigravity / Gemini 3.8 Flash:** Uygulama geliştirme ve Rails kodu üzerinde çift programlama için kullanıldı.
- **GitHub Copilot:** Projenin sonraki aşamalarındaki kod/repo çalışmaları ve dokümantasyon için kullanıldı; kullanılan model/sürüm kaydedilmedi.
- **Gerçek token veya API maliyeti:** Kullanım dökümü/billing kaydı tutulmadığından bilinmiyor. Tahmin ile gerçek maliyet ayrımı README'deki Faz 2 tablosundadır.
- **Geliştirme süresi:** Yaklaşık 3 gün olarak kaydedildi; ayrıntılı zaman çizelgesi tutulmadı.

### İnsanın Katkısı:
1. **Stratejik Yön:** IncidentFox konseptinden vazgeçip Fortune 500'lerin devasa harcama yaptığı ServiceNow pazarına odaklanma kararını verdi.
2. **Ortam Hakikati (Ground Truth):** Windows pacman kilitlenmesinde ajanın sonsuz bekleme döngüsünü kırıp WSL'e yönlendirdi.
3. **Kalite Eşiği:** Ajanın ürettiği kodun sunum şartnamesindeki 85 ve 100 puan kriterlerine uyup uymadığını denetledi.

### Ajanın Katkısı:
1. **Hızlı Mimari İnşası:** Rails 8 migrasyonları, model callback'leri ve controller durum geçişlerini dakikalar içinde üretti.
2. **Akıllı Benzerlik Algoritması:** Başlık, açıklama, kategori ve servis bazlı metin benzerlik eşleştiricisi geliştirildi; doğruluğu testlerle sınırlı örneklerde kontrol edildi.
3. **Test Kapsamı:** `travel_to` içeren testler mevcut. 19 Ekim 2026 tarihinde Ubuntu/WSL ortamında çalıştırılan testler **22 runs, 111 assertions, 0 failures, 0 errors, 0 skips** sonucu verdi. GitHub Actions CI bu testlerden ayrı olarak `b831627` commit'inde başarılı tamamlandı. Komut, kapsam ve diğer teslim bilgileri README'dedir.
4. **Kurumsal Arayüz:** Dış bağımlılık olmadan saf CSS ile ServiceNow tarzı profesyonel bir Light Theme oluşturdu.

---

## 5. Çıkarılan Temel Ders

> *"Bu proje kurumsal ürünün tamamı değil, Ruby on Rails ile hazırlanmış küçük bir olay yönetimi prototipidir. 300.000 LOC ifadesi kaynak kod sayımı değil, README'de açıklanan kaba ürün ölçeği tahminidir. Üretilen kodun çalıştığını kanıtlayan şey, gerçekten çalıştırılmış testler ve canlı uygulama doğrulamasıdır."*
