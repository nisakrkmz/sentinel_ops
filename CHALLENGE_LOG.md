# CHALLENGE_LOG

> Öğrenci: Nisa · Proje: SentinelOps (ServiceNow Incident Management klonu) · Hafta 2

## Başlangıç noktası

- **Klonlanan ürün:** ServiceNow — IT Service Management, Incident Management modülü (ITIL v4 Service Operations hizalı).
- **Canlı URL:** https://sentinel-ops-k0km.onrender.com
- **Geçen haftanın son commit'i:** [`40cb27a`](https://github.com/nisakrkmz/sentinel_ops/tree/40cb27a7948fa514cebf5854dda0ffe2d22cea11) ("Align project documentation and add logo", 19 Ekim 2026). Bu haftanın tüm değişiklikleri: [`40cb27a...main`](https://github.com/nisakrkmz/sentinel_ops/compare/40cb27a7948fa514cebf5854dda0ffe2d22cea11...main).
- **Başlangıç durumu:** Klasik, insandan insana bir ITSM listesi: insan bilet açıyor, insan atıyor, insan çözüyor. "Smart Incident Knowledge Matcher" aslında servis/kategori ve kelime benzerliğine puan veren deterministik bir kuraldı (`docs/AUDIT.md`).
- **Bu ürüne kim, neden para ödüyor?** Kurumsal BT operasyon ve servis masası ekipleri ile yönetilen hizmet sağlayıcılar (MSP). Karar veren: BT operasyon yöneticisi / ITSM platform sahibi. Ödeme sebebi: kesintilerin maliyeti (SLA cezası, iş durması) ve servis masası emeğinin maliyeti. Örnek Fortune 500 müşterisi: [Walmart, ServiceNow müşteri hikâyesi](https://www.servicenow.com/customers/walmart.html).

## Acı

- **Kullanıcı:** L1/L2 servis masası mühendisi ve olay yöneticisi (major incident manager).
- **Acı 1 — Yanlış gruba giden, gruplar arasında sekip duran biletler:** uzayan çözüm süresi, eskalasyon ve manuel triage. Kaynak: [ServiceNow Community — Why tickets bounce between assignment groups](https://www.servicenow.com/community/itsm-forum/why-tickets-bounce-between-assignment-groups-and-how-to-stop-it/m-p/3456724)
- **Acı 2 — Otomatik triage isteniyor ama öneriler hatalı olabiliyor:** ServiceNow'un kendi dokümanı AI önerilerinin her zaman doğru olmayabileceğini söylüyor; bu, güven skoru ve insana devir (HITL) ihtiyacını gösteriyor. Kaynak: [ServiceNow Docs — AI-native ITSM](https://www.servicenow.com/docs/r/it-service-management/fulfiller-experience-ai-native-itsm.html)
- **Acı 3 — Kurulum ve öğrenme yükü:** G2'de doğrulanmış bir kullanıcı, kurulum için gereken eforun küçümsendiğini yazıyor. Kaynak: [G2 ServiceNow ITSM incelemeleri, sayfa 9](https://www.g2.com/products/servicenow-it-service-management/reviews?page=9) (ekran görüntüsü: `docs/images/g2-servicenow-review-page-9.png`).

## Bu haftanın vaadi

> "Geçen hafta insandan insana bir ITSM listesi getirdim. Bu hafta üzerine **bileti agent'ın açıp triyajladığı, geçmiş çözümlerden kaynaklı öneri ürettiği ve gerektiğinde insana devrettiği** bir akış ekleyeceğim."

- Anahtar kelime tabanlı kararı kaldırıp triage'ı tipli, güven skorlu LLM kararına vermek
- RAG ile kaynaklı çözüm önerisi; kanıt yetersizse çekimser kalıp insana devretmek
- Agent'ların kullanabileceği REST API + MCP
- Politika tabanlı HITL: otomatik çözüm / insan onayı / devir; Onay Kuyruğu ve Agent Run Trace
- Kişisel hedef: RAG + Jev araştırması + Alibaba page-agent

## Yapılanlar ve kanıt

**Testler:** `bin/rails test` → **137 runs, 794 assertions, 0 failures, 0 errors** (WSL Ubuntu, Ruby 3.3.8, 25 Ekim 2026). Brakeman: 0 uyarı.

| Özellik | Commit | Kanıt |
|---|---|---|
| Actor modeli (insan/agent/sistem), hash'li API token, `decisions` denetim izi, `handoffs` | [`81d2cb1`](https://github.com/nisakrkmz/sentinel_ops/commit/81d2cb1) | Model/migration testleri |
| Anahtar kelime kararı kaldırıldı; tipli, şema doğrulamalı LLM triage + 40 örneklik eval seti | [`4c21c13`](https://github.com/nisakrkmz/sentinel_ops/commit/4c21c13), [`1b3a1ea`](https://github.com/nisakrkmz/sentinel_ops/commit/1b3a1ea) | `test/services/triage/*`; keyword baseline yalnızca `eval/baselines/` içinde |
| RAG — Incident Memory: 24 makale / 96 parça, embedding araması, alaka kapısı, alıntı doğrulama, abstain | [`bfbac5d`](https://github.com/nisakrkmz/sentinel_ops/commit/bfbac5d), [`1799975`](https://github.com/nisakrkmz/sentinel_ops/commit/1799975) | Lokal gerçek Gemini çalıştırması: VPN bileti → triage → 3 ilgili parça (güven 0.92) → alıntılı 3 adımlı çözüm (güven 0.90) → insana devir |
| Agent-first REST API + MCP + OpenAPI / agent-card / llms.txt | [`989682d`](https://github.com/nisakrkmz/sentinel_ops/commit/989682d) | Kontrat, idempotency, scope reddi ve injection testleri |
| HITL politikası (`config/hitl_policy.yml`), Onay Kuyruğu, Agent Run Trace, Kurumsal Simülasyon | [`c41368e`](https://github.com/nisakrkmz/sentinel_ops/commit/c41368e) | P1 onay, P3 otomatik çözüm, sağlayıcısız devir uçtan uca testleri |
| Jev (TypeSafe System One) adapter'ı: triage + RAG alaka kararı, resmî `/v1/systemone` sözleşmesi | [`e1d2732`](https://github.com/nisakrkmz/sentinel_ops/commit/e1d2732) | `jev_provider_test.rb` (7 test). Canlı Jev çağrısı yapılmadı, bkz. Karar |
| page-agent Copilot: sağ alt buton → orijinal panel + hareket eden imleç; gerçek izin listesi, PII maskeleme, sunucu proxy'si, onay | [`08652db`](https://github.com/nisakrkmz/sentinel_ops/commit/08652db), [`eefc5ff`](https://github.com/nisakrkmz/sentinel_ops/commit/eefc5ff), [`f3decba`](https://github.com/nisakrkmz/sentinel_ops/commit/f3decba) | Headless Chrome + gerçek Gemini: "KB'de VPN IP havuzu ara" görevi sayfa geçişi boyunca tamamlandı; "Yeni bilet aç…" görevi formu doldurdu, onaydan sonra bilet oluştu |
| DB'ye bağlı giriş (kayıt/giriş, PBKDF2), responsive arayüz, `/healthz`, hata düzeltmeleri | [`5b2f999`](https://github.com/nisakrkmz/sentinel_ops/commit/5b2f999), [`fa4ca42`](https://github.com/nisakrkmz/sentinel_ops/commit/fa4ca42), [`1f8c1e8`](https://github.com/nisakrkmz/sentinel_ops/commit/1f8c1e8) | Oturum/kayıt testleri; 390px'te yatay taşma yok |

**Eval** ([`eval/RESULTS.md`](eval/RESULTS.md)) — 40 etiketli TR/EN bilet (negasyon, "acil" ama düşük öncelik, duplicate, prompt injection örnekleri dahil):

| Metrik | Kelime tabanlı baseline | LLM |
|---|---|---|
| Öncelik doğruluğu | 0.40 | Ölçülmedi |
| `needs_human` precision / recall | 1.00 / 0.40 | Ölçülmedi |

**Kullanılan sağlayıcılar (dürüstçe):** Triage, RAG alaka kararı, çözüm üretimi ve page-agent için Google Gemini (`gemini-flash-lite-latest`), embedding için `gemini-embedding-001`. Jev ile hiçbir canlı çağrı yapılmadı.

**Canlı demo adımları:**
1. Canlı URL → giriş ekranında "Bilgileri doldur" ile demo hesabı → üst barda "Agent'lar: N aktif · Onay bekleyen: N"
2. **⚡ Kurumsal Simülasyon** → Monitoring Agent kimliğiyle P1 SAP bileti açılır
3. Bilet detayı → Agent triage kararı (sağlayıcı, güven, gerekçe) → Incident Memory'nin alıntılı önerisi → Agent Run Trace → P1 olduğu için agent kapatmaz, insan onayına gönderir
4. **Onay Kuyruğu** → insan olarak onayla / düzelt / reddet
5. Sağ alttaki **Page Agent Copilot** → "Knowledge Base'de VPN IP havuzu ara" → imleç hareket eder, sayfa değişir, arama yapılır

### Vaat edip yapamadıklarım

- **LLM eval sayıları yok.** Tabloda yalnızca keyword baseline ölçüldü; gerçek modelle `EVAL_LIVE=1 bin/eval_triage` ve `EVAL_RAG_LIVE=1 bin/eval_rag` çalıştırılmadı.
- **Jev ile canlı çağrı yok.** Adapter yazıldı ve testlendi; canlı demoda bilinçli olarak kullanılmıyor (bkz. Karar).
- **Agent'ın REST API/MCP üzerinden bilet açması canlıda gösterilmedi.** API testlerle doğrulandı. Canlıda token için Render'da `AGENT_TOKEN_PEPPER` gerekiyor; canlı demodaki agent kaynaklı bilet Kurumsal Simülasyon üzerinden açılıyor.
- **Render'ın diski kalıcı değil.** Her deploy'da veritabanı sıfırlanır; demo verisi ve demo hesabı her açılışta yeniden oluşur.
- **Canlı deploy yapıldı (25 Ekim 2026, commit `7df9099`):** `/healthz` → DB ok, triage/RAG/Page Agent sağlayıcıları Gemini'de yapılandırılmış, KB 24/24 indeksli; Render logunda `Indexed 96 chunks using gemini/gemini-embedding-001`. GitHub Actions CI #19 yeşil. Canlı demo adımlarının tamamı tarayıcıda ayrıca kayıt altına alınmadı.

## Zaman

| | Süre |
|---|---|
| **İnsan zamanı (Nisa)** | **Yaklaşık 3 saat** (Nisa'nın kendi tahmini; ölçülmedi) |
| **Agent zamanı — toplam** | **Yaklaşık 7–8 saat** (Nisa'nın tahmini; oturumların çoğunda kayıt tutulmadığı için ölçüm değil) |
| Agent zamanı — ölçülen kısım | ≈ 1 saat 20 dakika: 19–20 Ekim Faz 0–1 ≈ 29 dk (zaman damgalarıyla) + 25 Ekim denetim/düzeltme oturumu ≈ 51 dk (16:48:32–17:39:18) |
| Agent zamanı — ölçülemeyen kısım | 20–24 Ekim oturumları (triage, RAG, API/MCP, HITL, page-agent) ve 25 Ekim'deki sonraki düzeltmeler için güvenilir başlangıç/bitiş kaydı tutulmadı; toplam tahmine dahildir |

**İlk prompt (olduğu gibi, yazım hataları dahil):** Claude'a (sohbet arayüzü) yazdığım ham ilk mesaj. Ekler: `odev.docx` (hocanın ödev metni) ve projenin canlı deploy ekran görüntüsü.

> Ruby dersinde geliştirmeye başladığımız proje üzerinde yeni geliştirmeler yapmak üzere bu haftanın ödevini tamamlamam gerekiyor. Planlı şekilde gitmek istiyorum. Ne kadar zamanımı aldı, projemdeki yeni güncellemeler neler olmalı gibi bilgileri düzenli olarak tutmak istiyorum. Benim projem SentinelOps isminde, ServiceNow firmasının Incident Managament modülünü ele aldığım bir proje. Aslında kurumsal yapıların işletim sistemi tarzında bir adlandırmadan bahsedilen oldukça güçlü bir proje olabilir burası. Benim ilk ödev olarak atanan ödevde çok daha basit ve klasik kaldığımı anladım hocamın yorumlamasından. Ayrıca şuan insandan-insana şeklinde bir akış var içeride fakat çok daha güçlü olmasını istiyorum. Sana ödevi ve projemin canlı deployda şuanki görüntüsünü veriyorum ona göre durum analizi yapmanı ve agent ile geliştirmeye tekrar başlamayı istiyorum, bunun için de comprehensive bir prompt istiyorum senden. odev dokümanında ismim de var, Nisa. Oradan da hocamın bana tavsiyelerini uygulamak istiyorum.

Kaynak dosyalar (değiştirilmeden saklandı):
1. Bu ham ilk mesaj: [`prompt.md`](prompt.md) → Bölüm 1
2. Bu mesajın sonucunda coding agent'a verdiğim ayrıntılı prompt: [`docs/prompts/00_first_prompt.md`](docs/prompts/00_first_prompt.md)

Sonraki geri bildirimlerim: [`docs/prompts/01_phase7_feedback.md`](docs/prompts/01_phase7_feedback.md).

## Karar

**Devam et ve üzerine ekle.**

Gerekçe — "Bundan bir iş çıkar mı?": Evet. İlk seviye triage ve tekrar eden olayların çözüm bilgisinin yeniden kullanılamaması, kurumların bugün para ve personel harcadığı, ölçülebilir bir acı. ServiceNow dahil sektör de agent destekli triage'a gidiyor. Pivot gerekmiyor, çünkü ürün (olay, SLA, KB, major incident) doğru problem alanında; eksik olan akıllı ve agent'ların erişebildiği katmandı. Öldürmek de gerekmiyor, çünkü klonun iskeleti bu katmanın oturacağı doğru zemin.

**Slop testi:** "Benimkinde olup diğerlerinde olmayan şey: **bileti açan, triyajlayan ve çözüm öneren taraf bir agent olabiliyor; her karar şemalı, güven skorlu, kaynak gösteren ve insana devredilebilir.**"
Kanıt: canlı demo adımları 2–4 (Agent Run Trace'te her kararın sağlayıcısı, güveni ve kaynakları görünür) ve kelime tabanlı baseline'ın 0.40 doğrulukta kaldığı eval seti.

**Kişisel hedefim — "ServiceNow klonuna RAG + JEV araştırması ekle. Alibaba page-agent'ı incele.":**
- **RAG — çalışıyor:** Incident Memory, gerçek embedding araması, alaka kapısı ve alıntı doğrulamalı çözüm üretiyor; kanıt yetersizse çekimser kalıp insana devrediyor.
- **Jev — araştırıldı, adapter hazır, canlıda kullanılmıyor:** Jev metin üretmeyen, tipli ve olasılıklı karar veren bir "System 1" modeli. Mimariyi bu ayrıma göre kurdum: sınıflandırma, yönlendirme, duplicate ve "bu KB parçası ilgili mi?" kararları System 1'de; çözüm metni System 2'de (LLM + RAG). Jev ücretli bir API ve ücretsiz katmanı yok. Ders demosu için ücretli bir bağımlılık eklemek yerine aynı tipli şemayı ücretsiz bir LLM'e (Gemini) şema kısıtlı olarak ürettiriyorum ve bunu her ekranda "gemini" olarak gösteriyorum. Jev'e geçiş tek bir ENV değişikliği (`DECISION_PROVIDER=jev`). Kabul ettiğim bedel: LLM'in şema içinde verdiği olasılıklar kalibre değil, Jev'inkiler kalibre. Ayrıntı: [`docs/research/RAG_JEV_PAGE_AGENT.md`](docs/research/RAG_JEV_PAGE_AGENT.md).
- **page-agent — incelendi ve entegre edildi:** Orijinal arayüzüyle çalışıyor. İnceleme sırasında kütüphanenin izin listesinin (`interactiveWhitelist`) aslında hiçbir şeyi kısıtlamadığını buldum ve gerçek kısıtlamayı ekledim. page-agent'ı insan operatörün arayüz köprüsü olarak konumluyorum; agent'ların asıl giriş yolu REST API ve MCP.
