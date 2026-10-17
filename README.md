# SentinelOps — Enterprise IT Service Management (ITSM) Platform

[![CI](https://github.com/nisakrkmz/sentinel_ops/actions/workflows/ci.yml/badge.svg)](https://github.com/nisakrkmz/sentinel_ops/actions/workflows/ci.yml)
![Ruby Version](https://img.shields.io/badge/ruby-3.3.8-red.svg)
![Rails Version](https://img.shields.io/badge/rails-8.1.4-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> **Canlı Uygulama URL:** Henüz yayınlanmadı. Render yapılandırması [render.yaml](./render.yaml) dosyasında bulunuyor, ancak Render servisi henüz oluşturulmadı.
> **GitHub Deposu:** [https://github.com/nisakrkmz/sentinel_ops](https://github.com/nisakrkmz/sentinel_ops)
> **İlham Kaynağı:** Bu proje, kurumsal BT dünyasının sektör standardı olan **ServiceNow (IT Service Management - Incident Management)** ürününün mimarisinden ve ITIL v4 operasyon standartlarından ilham alınarak geliştirilmiştir. Orijinal marka adı veya logosu uygulamada yer almaz.

---

## 📊 Faz 1: Fortune 500 SaaS Ekosistemi Araştırması

Fortune'un 2026 listesi şirketleri **gelire** göre sıralar; değerleme ve SaaS tüketimi Fortune tarafından tek bir standart aralık olarak yayımlanmaz. Aşağıdaki değerler farklı kaynakların yaklaşık kurumsal göstergeleridir; Fortune 500'ün tamamını kapsayan denetlenmiş bir veri seti değildir.

| Metrik | Değer / Aralık | Doğrulanmış Kaynak |
| :--- | :--- | :--- |
| **a. Değerleme (piyasa değeri)** | Halka açık büyük şirketlerde yaklaşık **$1 milyar mertebesinden birkaç trilyon dolara**; şirket ve tarih seçimine göre değişir. Fortune listesi piyasa değerine göre sıralanmadığı ve özel şirketleri de içerdiği için bu, Fortune 500 için kesin minimum-maksimum değildir. | [Fortune 500 sıralama yöntemi](https://fortune.com/ranking/fortune500/) (gelir) · [CompaniesMarketCap şirket değerleri](https://companiesmarketcap.com/) (günlük değişen piyasa değeri) |
| **b. Çalışan sayısı** | Yaklaşık **1.000'lerden 2,1 milyona**. Düşük uç, şirket bildirimlerinden türetilmiş yaklaşık büyüklüktür; Walmart üst uç örneğidir. | [Fortune 500](https://fortune.com/ranking/fortune500/) · [Statista: Fortune 500'de en büyük işverenler](https://www.statista.com/statistics/264423/number-of-employees-at-the-largest-us-companies/) |
| **c. Firma başına SaaS sayısı** | [Zylo 2026 SaaS Management Index](https://zylo.com/2026-saas-management-index) örnekleminde ortalama **305 uygulama**. Bu Fortune 500'e özel sayım değil, kurumsal SaaS portföyü benchmark'ıdır. | [Zylo 2026 SaaS Management Index](https://zylo.com/2026-saas-management-index) |
| **d. Yıllık SaaS harcaması** | Aynı Zylo benchmark'ında kuruluş başına ortalama **$55,7 milyon/yıl**. Örneklem ortalaması; her Fortune 500 şirketi için geçerli veya denetlenmiş bir tutar değil. | [Zylo 2026 SaaS Management Index](https://zylo.com/2026-saas-management-index) |

---

## 🏢 SaaS Seçimi & Fortune 500 Kanıtı

- **Seçilen Ürün:** **ServiceNow (ITSM - Incident Management)**
- **Fortune 500 kanıtı:** [Walmart](https://fortune.com/ranking/fortune500/) Fortune 500 şirketidir ve [ServiceNow'un Walmart müşteri hikâyesinde](https://www.servicenow.com/customers/walmart.html) müşteri olarak yer alır. Bu, en az bir Fortune 500 şirketinin ürünü kullandığına kanıttır; **%85** iddiası için doğrulanabilir kaynak bulunmadığından çıkarılmıştır.
- **Ölçek:** ServiceNow kaynak kodu yayımlanmadığı için gerçek LOC sayısı bilinmiyor. Aşağıdaki **~300.000 LOC** yalnızca kendi kaba tahminimdir; ölçülmüş veya vendor tarafından doğrulanmış bir sayı değildir.

---

## 💰 Faz 2: Maliyet & Geliştirme Tahmini

### 1. Satır Sayısı Tahmini ve Metodoloji
- **Tahmini satır sayısı:** ~300.000 LOC (düşük güvenli, kaba merkez tahmini).
- **Tahmin yöntemi:** Özel kaynak kodu erişilebilir olmadığından modül bazlı kaba büyüklük tahmini yaptım: olay/durum motoru (~50k), SLA/iş kuralları (~45k), CMDB/varlıklar (~55k), kullanıcı/roller/portallar (~45k), entegrasyonlar/raporlama (~45k), arayüz/otomasyon/yönetim (~60k); toplam ~300k LOC. Bu, dosya sayımı veya yayımlanmış vendor verisi değildir; kesinlik iddiası taşımaz. FPA/COCOMO ölçümü yaptığım iddiası kaldırıldı.

### 2. Coding Agent ile Üretim: Tahmin vs. Gerçek

| Parametre | Ön tahmin | Gerçekleşen |
| :--- | :--- | :--- |
| **Geliştirme süresi** | 3-5 iş günü | AI kullanıldığı doğrulandı; toplam çalışma süresi bilinmiyor ve zaman kaydı yok. |
| **Token / abonelik maliyeti** | Yaklaşık 15 milyon token ve model fiyatına göre $45-75 API maliyeti (kendi tahminim; abonelik sabit ücreti hariç) | Bu depoda kullanım/billing dökümü yok; 3,4 milyon token ve $14,50 iddiası doğrulanamadığı için gerçekleşen değer olarak sunulmuyor. Gerçek tutar bilinmiyor. |
| **Ajan / model** | Model bağımsız | AI ajanı kullanıldı; kullanılan ürün/model doğrulanmadı. |

---

## 🫀 Aort Dilimi: Uçtan Uca Olay Akışı

SentinelOps yerel olarak **ITSM Olay Yönetimi (Incident Management)** akışını uygular. Uygulama testi bu akışı doğrular; Render URL'sinin canlı çalıştığı bu ortamdan doğrulanamamıştır.

1. **Durum Akışı (State Workflow):**
   $$\text{New (Yeni)} \xrightarrow{\text{start\_progress!}} \text{In Progress (İşlemde)} \xrightarrow{\text{put\_on\_hold!}} \text{On Hold (Beklemede)} \xrightarrow{\text{resolve!}} \text{Resolved (Çözüldü)}$$
2. **Zaman Kuralı & Dinamik SLA Motoru:**
   - **P1 - Critical:** 15 Dakika Hedef SLA
   - **P2 - High:** 2 Saat Hedef SLA
   - **P3 - Moderate:** 4 Saat Hedef SLA
   - **P4 - Low:** 24 Saat Hedef SLA
   - SLA, liste/detay sayfası veya aksiyon isteği geldiğinde kontrol edilir; ayrı bir arka plan zamanlayıcısı yoktur. Süre geçtiyse `sla_status` ihlal olarak işaretlenir, olayın iş akışı durumu ayrıca değişmez ve zaman çizelgesine kayıt eklenir.
3. **Minitest + `travel_to` Testleri:**
   22 test senaryosu Ubuntu/WSL ortamında 17 Ekim 2026 tarihinde çalıştırıldı: **22 runs, 111 assertions, 0 failures, 0 errors, 0 skips**. Bu yerel sonuç GitHub Actions'ın yeşil olduğu anlamına gelmez; CI ancak yayımlanmış repoda Actions çalıştıktan sonra doğrulanmış sayılır.

---

## 🎯 100 Puanlık Pas: Kullanıcı Acısı & SentinelOps Çözümü

### 1. Kullanıcı acısı ve kaynak durumu
- **Kaynakta bulunan acı:** G2 arama sonucunda ServiceNow incelemesinden şu alıntı görüntülendi: *“The learning curve is real and I think ServiceNow undersells how much effort it takes to get set up properly.”*
- **Kaynak:** [G2 ServiceNow IT Service Management incelemeleri](https://www.g2.com/products/servicenow-it-service-management/reviews). G2 sayfası bu ortamda erişim engeli verdi; arama sonucunda inceleme yazarının adı, tarihi ve tekil inceleme kalıcı bağlantısı doğrulanamadı. Kaynak sayfası bireysel inceleme URL'si yerine ürün incelemeleri listesidir.
- **Dürüstlük notu:** Bu kanıt henüz sunumda 100 puan kriteri için yeterince doğrulanmış değildir. Gerçek incelemeyi açıp bireysel bağlantıyı ve bağlamı README'ye eklemeden 100 puanlık kullanıcı acısının kanıtlandığını iddia etmiyorum.

### 2. SentinelOps çözümü: Smart Incident Knowledge Matcher
- Bu küçük olay yönetimi dilimi için ilk kurulum gerektirmeyen SLA varsayılanları, hazır olay şablonları ve geçmiş çözülmüş olaylarla benzerlik eşleştirmesi sunulur. Amaç yeni operatörün doğru akışı hızla deneyebilmesidir; tam platform kurulumunu kolaylaştırdığı iddia edilmiyor.
- **Benzerlik puanlaması:** Yeni açılan biletin servisi, hata başlığı ve açıklaması geçmişte çözülmüş vakalarla karşılaştırılır:
  - Servis eşleşmesi: **+35 puan**
  - Kategori eşleşmesi: **+10 puan**
  - Jaccard metin benzerliği: **+55 puana kadar**
  - Aynı parmak izi için algoritmik skor: **98/100** (başarı oranı değildir).
- **1 tıkla geçmiş çözümü uygula:** Detay sayfasında bulunan benzer olayın kök neden ve çözüm notları mevcut olaya aktarılır ve olay çözüldü durumuna alınır.

### 3. Sunumda Tek Cümlelik Pas Formülü:
> *“G2'de belirtilen kurulum/öğrenme eğrisi acısına karşı SentinelOps, bu olay yönetimi diliminde hazır SLA ve olay şablonları ile geçmiş çözümü tek tıkla uygulama akışı sunuyor; bireysel inceleme bağlantısı doğrulanana kadar 100 puan kanıtı tamamlanmış sayılmıyor.”*

---

## 🎨 Arayüz Tasarımı: Kurumsal Light Theme SaaS

- Neon/karanlık temadan tamamen arındırılmış, kurumsal ServiceNow web konsolu çizgisinde profesyonel aydınlık tema (`bg-slate-50`, `#f8fafc`).
- Lacivert/kurumsal mavi tonları (`#0f172a`, `#2563eb`), kurumsal kartlar ve temiz listeleme tabloları.
- Üst düzey yönetici metrik kartları (*Toplam Açık Bilet, Devam Edenler, SLA İhlalleri, Knowledge Match Oranı, Çözülen Biletler*).
- Canlı demo simülatörü (*SAP ERP S/4HANA, Global VPN Gateway, Active Directory SSO, Payment Gateway*).

---

## 🛑 Yapamadıklarım / Bilinen Kısıtlar

*Şeffaflık ve dürüstlük ilkesi gereği projede bilinçli olarak kapsam dışı bırakılan veya simüle edilen kısıtlar:*

1. **Active Directory / LDAP Canlı Entegrasyonu:** Gerçek bir Microsoft Domain Controller yerine kurumsal SSO Kerberos senkronizasyonu simüle edilmiş ve JWT formatında hata fırlatılmıştır.
2. **İki Yönlü E-Posta Dönüştürücü (Inbound Email Parsing):** Kullanıcıların e-posta atarak bilet açması veya e-posta yanıtıyla bilet güncellemesi için SMTP/IMAP worker servisi kurulmamış; biletler web formu ve simülasyon motoru ile üretilmektedir.
3. **Rol Tabanlı Erişim Kontrolü (RBAC):** ServiceNow'daki yüzlerce yetki rolü (admin, itil, itil_admin, ess) yerine tüm bilet aksiyonları hızlı sunum ve değerlendirme amacıyla açık bırakılmıştır.
4. **Çok Dilli Sözlük (i18n):** Kurumsal ITIL jargonu gereği terimler (P1-P4, SLA Breached, In Progress) küresel ServiceNow standardı olan İngilizce/Türkçe hibrit formatta bırakılmıştır.
5. **Arka plan SLA zamanlayıcısı:** İhlal kontrolü istek sırasında yapılır; periyodik worker/cron kurulmadı. Uzun süre hiç açılmayan kayıt, sayfa/aksiyon isteği gelene kadar işaretlenmez.
6. **Canlı yayın ve CI kanıtı:** Kod GitHub'da yayımlandı. GitHub Actions, `74ffb01` commit-inde başarılı geçti. Render yapılandırması mevcut ancak Render servisi henüz oluşturulmadı; canlı deploy olmadan teslim ölçütleri tamamlanmış sayılmaz.
7. **Kullanıcı yorumu kanıtı:** G2'deki tekil yorum sayfası açılamadı; kişiye/yoruma özgü permalink doğrulanmadı. 100 puan kriteri bu yüzden henüz kanıtlanmış değil.
8. **Kalıcı veritabanı diski:** Render yapılandırması SQLite kullanıyor ve kalıcı disk tanımlamıyor; yeniden deploy/uyku sonrası demo kayıtlarının korunacağı garanti edilmez.

---

## 🧪 Testleri Çalıştırma

```bash
# Model, SLA travel_to ve Controller testlerinin tamamı:
bin/rails test

# Son doğrulama: 22 runs, 111 assertions, 0 failures, 0 errors, 0 skips (Ubuntu/WSL, 2026-10-17).
```

---

## 🛠️ Kurulum & Yerel Çalıştırma

```bash
# Bağımlılıklar
bundle install

# Veritabanı ve Tohum Verileri
bin/rails db:prepare
bin/rails db:seed

# Sunucuyu Başlatın
bin/rails server -b 0.0.0.0 -p 3000
```
Tarayıcınızdan `http://localhost:3000` adresine giderek uygulamayı inceleyebilirsiniz.
