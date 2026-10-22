# CHALLENGE_LOG

> Öğrenci: Nisa · Proje: SentinelOps (ServiceNow Incident Management klonu)
> Durum: **TASLAK**. `[DOLDUR]` ve "Nisa onayı bekliyor" işaretli yerleri sen tamamlayacaksın. Kanıtı olmayan hiçbir satırı "yapıldı" diye bırakma.

## Başlangıç noktası

- **Klonlanan ürün:** ServiceNow, Incident Management modülü (ITIL v4 Service Operations hizalı)
- **Canlı URL:** https://sentinel-ops-k0km.onrender.com
- **Geçen haftanın son commit'i:** Repo HEAD `40cb27a7948fa514cebf5854dda0ffe2d22cea11` (`Align project documentation and add logo`, 2026-10-19). Bunun ders açısından geçen haftanın son commit'i olduğu teyit edilmedi.
- **Başlangıç durumu (baseline):** Rails tabanlı web ITSM ekranları, incident durum/SLA akışı ve form, "Smart Incident Knowledge Matcher". Matcher LLM/RAG değil; hata imzası, servis/kategori ve sözcük-Jaccard puanlaması kullanıyor. Ayrıntı ve kod referansları: [`docs/AUDIT.md`](docs/AUDIT.md). Canlı URL kontrolünde HTTP 503 döndü; uygulama ekran görüntüsü elde edilemedi. [`docs/baseline/README.md`](docs/baseline/README.md)
- **Bu ürüne kim, neden para ödüyor?**
  - Ödeyen: kurumsal BT operasyon / servis masası ekipleri ve yönetilen hizmet sağlayıcıları (MSP). Karar vericiler: BT operasyon yöneticisi, ITSM platform sahibi.
  - Neden: kesintilerin maliyeti (SLA cezaları, iş durması) ve servis masası emeğinin maliyeti. ServiceNow gibi platformlar bu yüzden lisans ücreti alıyor.

## Acı

- **Kullanıcı:** L1/L2 servis masası mühendisi, olay yöneticisi (major incident manager).
- **Acı 1 — Yanlış gruba giden ve gruplar arasında "sekip duran" biletler.** ServiceNow topluluk forumunda bu, uzayan çözüm süresi, artan eskalasyon ve manuel triage olarak tarif ediliyor:
  https://www.servicenow.com/community/itsm-forum/why-tickets-bounce-between-assignment-groups-and-how-to-stop-it/m-p/3456724
- **Acı 2 — Triage'ın otomatikleştirilmesi isteniyor ama öneriler hatalı olabiliyor.** ServiceNow'un kendi dokümanı, AI üretimli kategori/yönlendirme önerilerinin her zaman doğru olmayabileceğini belirtiyor. Bu, güven skoru ve insana devir (HITL) ihtiyacını gösteriyor:
  https://www.servicenow.com/docs/r/it-service-management/fulfiller-experience-ai-native-itsm.html
- **Acı 3 — Düzeltmelerin bilgiye dönüşmemesi.** Yanlış yönlendirme ve yeniden atama bilgisi yönlendirme mantığına geri akmıyor (satıcı yazısı; iddia olarak oku):
  https://moveworks.com/us/en/resources/blog/what-is-intelligent-triage-it-support
- **Not:** Üstteki kaynaklardan biri satıcı pazarlaması, biri topluluk forumu. Sayısal iddiaları (ör. "%30 yanlış yönlendirme") kanıt olarak kullanma. [DOLDUR: en az bir gerçek kullanıcı şikâyeti/forum alıntısı veya inceleme linki daha ekle. Alıntı yaparken kısa tut ve linkle.]

## Bu haftanın vaadi

> "Geçen hafta insandan insana bir ITSM listesi getirdim. Bu hafta üzerine **bileti agent'ın açıp triyajladığı, geçmiş çözümlerden kaynaklı öneri ürettiği ve gerektiğinde insana devrettiği** bir akış ekleyeceğim."

Vaat edilenler (her biri aşağıda kanıtlanacak, kanıtlanmayan "yapılmadı" sayılır):

- [x] Faz 1: actor, token, decision, handoff ve incident audit alanları; migrasyon ve model/controller testleri (WSL)
- [x] Uygulama triage'ından anahtar kelime tabanlı karar mantığının kaldırılması; tipli karar sağlayıcısı ve şema doğrulaması
- [x] RAG ile kaynaklı çözüm önerisi; kanıt yetersizse abstain (gerçek provider/index ve canlı metrik beklemede)
- [x] Agent-first REST API (+ OpenAPI, agent-card), MCP sunucusu ve SSE olay replay'i (Render'da live doğrulama beklemede)
- [x] Politika tabanlı HITL: config eşikli otonom çözüm / onay bekleyen / devir (gerçek sağlayıcıyla çalıştırma beklemede)
- [x] Agent Run Trace ve Onay Kuyruğu (lokal testlerle doğrulandı; canlı deploy beklemede)
- [x] page-agent araştırması ve sunucu proxy'li, maskelemeli UI copilot (provider erişimi/canlı doğrulama beklemede)
- [x] Eval: 40 örneklik kelime tabanlı baseline raporu; gerçek model karşılaştırması sağlayıcı erişimi bekliyor

## Yapılanlar ve kanıt

| # | Özellik | Commit | Test / komut | Canlı demo adımı | Durum |
|---|---|---|---|---|---|
| 1 | Keşif ve baseline | [`81d2cb1`](https://github.com/nisakrkmz/sentinel_ops/commit/81d2cb15f2cb6abd0a4c180fbc0710c6f7f271a1) (audit/baseline docs) | Faz 0: 22 runs, 111 assertions, 0 failures | Canlı URL 503; demo doğrulanamadı | Audit, assumptions ve prompt copies hazır; canlı screenshot yok |
| 2 | Actor modeli + denetim izi | [`81d2cb1`](https://github.com/nisakrkmz/sentinel_ops/commit/81d2cb15f2cb6abd0a4c180fbc0710c6f7f271a1) | `wsl.exe -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && bundle exec rails test'` — 35 runs, 163 assertions, 0 failures; 16 dosyada RuboCop temiz; Brakeman 0 warning | Mevcut geliştirme DB'sindeki 6 olay ve tüm timeline kayıtları actor'a bağlı; canlı deploy/demo beklemede | Faz 1 tamamlandı ve commit'lendi; deploy edilmedi |
| 3 | Tipli triage altyapısı + eval baseline | [`4c21c13`](https://github.com/nisakrkmz/sentinel_ops/commit/4c21c13b46c7677b1035bb3a61bf821bd898c4b7) | `wsl.exe -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && bundle exec rails test'` — 46 runs, 202 assertions, 0 failures; `bundle exec rubocop` — 19 files, no offenses; Brakeman — 0 warnings; `ruby bin/eval_triage` — 40 örnek | Canlı sağlayıcı anahtarı ve deploy olmadığı için doğrulanmadı | Uygulama mantığı tamamlandı; gerçek model çağrısı ve deploy beklemede |
| 4 | RAG (Incident Memory) + abstain | [`bfbac5d`](https://github.com/nisakrkmz/sentinel_ops/commit/bfbac5d3352bc53d98a28f5d88804a2f16047f9a) | `bundle exec rails test` — 67 runs, 310 assertions, 0 failures; RuboCop — 21 files, no offenses; `bundle exec brakeman -q` — 0 warnings; `./bin/eval_rag` — 25 cases, `not_run`; temporary migrate/seed rerun — 24 articles, 96 chunks, 6 incidents both runs | Gerçek provider key/index ve production DB erişimi yok; canlı doğrulama beklemede | Uygulama, 25 senaryolu eval corpus ve `not_run` raporu hazır; sentetik KB açıkça etiketli |
| 5 | Agent REST API + OpenAPI + agent-card + MCP + SSE | [`989682d`](https://github.com/nisakrkmz/sentinel_ops/commit/989682d0adbb70430d7a877612772848885e87cf) | `bundle exec rails test` — 85 runs, 411 assertions, 0 failures; `bundle exec rubocop app/controllers/api/v1 app/controllers/mcp_controller.rb test/controllers/api/v1 test/controllers/mcp_controller_test.rb` — 8 files, no offenses; `bundle exec brakeman -q` — 0 warnings | Local API/MCP contract tests pass; Render token pepper/provider ENV ve deploy doğrulanmadı | Scope'lu REST ve MCP, idempotency, cursor paging, SSE event batch, kaynak doğrulama ve makine okunur hatalar |
| 6 | HITL policy, workflow orkestrasyonu, simülasyon actor attribution, Onay Kuyruğu, feedback denetimi ve Agent Run Trace | [`c41368e`](https://github.com/nisakrkmz/sentinel_ops/commit/c41368ec8c5f4392d5545f72063aa89c91e95107) | `wsl -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && bundle exec rails test'` — 96 runs, 482 assertions, 0 failures; hedefli RuboCop 12 dosyada temiz; `bundle exec brakeman -q` — 0 warning | Lokal: Kurumsal Simülasyon → incident trace/handoff → Onay Kuyruğu'nda onayla/düzelt/reddet. Sağlayıcı anahtarı yoksa dürüstçe provider-unavailable handoff; canlı demo yapılmadı | Kod ve testler tamam; gerçek provider, deploy ve canlı doğrulama beklemede |
| 7 | page-agent araştırması, sabitlenmiş IIFE, UI allowlist, JS tool kapatma, PII masking hook, same-origin provider proxy ve state-change confirmation | [`08652db`](https://github.com/nisakrkmz/sentinel_ops/commit/08652db87fce528a8b36e72415a06756afd5f136) | `bundle exec rails test` — 103 runs, 535 assertions, 0 failures; targeted RuboCop — 4 ilgili dosyada temiz; `bundle exec brakeman -q` — 0 warning; `node --check app/javascript/page_agent.js` — başarılı. Tam RuboCop taramasında değişmemiş `test/models/incident_test.rb:239` dosyasında 1 mevcut biçim ihlali var | Lokal tarayıcıda importmap modülü yüklendi, copilot paneli açıldı ve mock yanıtla görev tamamlandı; aynı-origin proxy isteği ve caller redaksiyonu doğrulandı (provider çağrısı mock ile kesildi). Gerçek sağlayıcı, deploy ve canlı demo beklemede | Page Agent UI/proxy yerel olarak testli; sağlayıcı anahtarı ve Faz 7 deploy/canlı doğrulama beklemede |
| 8 | Incident liste/detay görünümü cilası, responsive üst navigasyon, tekrarlanan açılış butonu metninin sadeleştirilmesi | [`54c46cd`](https://github.com/nisakrkmz/sentinel_ops/commit/54c46cd) | `bundle exec rails test` — 103 runs, 535 assertions, 0 failures; ERB Ruby syntax derlemesi başarılı; iki incident şablonunda HTML tag dengesi hatasız; CSS'te 21 tekrarlanan selector yalnızca media-query responsive override'ı; 1280px ve 375px tarayıcı kontrollerinde belge yatay taşması yok | Yerel UI doğrulandı; Render deploy/canlı demo yapılmadı | Incident sayfa stilleri paylaşımlı/responsive bileşenlere taşındı, dar ekranda tablo kendi içinde kaydırılıyor ve header yatay taşmıyor |
| 9 | Nisa operatör oturumu, modern responsive giriş ekranı, güvenli çıkış, parola deneme sınırı ve favicon | [`1c98153`](https://github.com/nisakrkmz/sentinel_ops/commit/1c98153) | `bundle exec rails test` — 109 runs, 596 assertions, 0 failures; hedefli RuboCop — 10 dosyada temiz; `bundle exec brakeman -q` — 0 güvenlik uyarısı; login → Nisa → incident ana sayfa tarayıcıda doğrulandı; `/favicon.svg` HTTP 200; 1280px/375px responsive kontrolü | Geçici yerel preview'da Nisa login → incident ana sayfa doğrulandı. Mevcut 3000 sunucusunda `NISA_PASSWORD` ayarlı olmadığından form bilinçli olarak pasif; yerel kullanım için env ayarlanıp yeniden başlatılmalı. Render secret/deploy doğrulanmadı | Tüm web ekranları oturum arkasına alındı; UI aksiyonları Nisa actor'ına yazılır. API/MCP bearer token akışı ayrı tutuldu |
| 10 | Page Agent'ın yeni incident formunu doldurup operatör onayıyla göndermesi | [`2b4b8dc`](https://github.com/nisakrkmz/sentinel_ops/commit/2b4b8dc) | `bundle exec rails test` — 109 runs, 615 assertions, 0 failures; hedefli RuboCop temiz; Brakeman 0 uyarı; `node --check app/javascript/page_agent.js` başarılı; `git diff --check` temiz | Provider yapılandırılmış yerel Page Agent ile gerçek tarayıcıda form doldurma/gönderme onayı henüz canlı doğrulanmadı. Form sayfasına geçtikten sonra Page Agent yeniden açılmalı; submit öncesi tarayıcı onayı gerekir. Render doğrulanmadı | Yeni incident form alanları Agent allowlist'ine eklendi. Yalnızca yeni incident oluşturabilir; mevcut incident mutasyonu/yeniden ataması, çözme kapalıdır. Başlangıç atama grubu yalnızca kullanıcının açık talebiyle değişir |
| 11 | Page Agent/Groq 502 hatası için güvenli provider hata teşhisi | [`d63d89a`](https://github.com/nisakrkmz/sentinel_ops/commit/d63d89a) | `bundle exec rails test` — 111 runs, 626 assertions, 0 failures; hedefli RuboCop temiz; `node --check app/javascript/page_agent.js` başarılı; `git diff --check` temiz | 14:53 logunda proxy 502 doğrulandı. Güncel 15:30 logunda provider HTTP 400 ve ardından HTTP 429 görülüyor. Eski sürüm provider hatasını 502 olarak gizliyordu. Yeni sürüm 400/422 için tool-calling isteği/model uyumunu kontrol ettiren; 429 için quota/rate limit beklenmesini söyleyen güvenli açıklama verir. Kesin 400 nedeni alınmadı | Provider status'u API key/yanıt gövdesini loglamadan kaydediliyor ve kullanıcıya hata türüne uygun açıklama dönüyor; ticket messages/content/tools logda filtreleniyor |
| 12 | Page Agent'dan operatör onaylı Kurumsal Simülasyon tetikleme | [`163e25e`](https://github.com/nisakrkmz/sentinel_ops/commit/163e25eefb99b48bba34a7874ea02ee07d03c64e) | `bundle exec rails test` — 111 runs, 628 assertions, 0 failures; hedefli RuboCop — 5 dosyada temiz; Brakeman 0 warning; `node --check app/javascript/page_agent.js` başarılı; `git diff --check` temiz | Simülasyon kontrolü Page Agent allowlist'ine eklendi. Açık kullanıcı isteği ve browser confirmation gerekir; dış sisteme dokunmadan uygulamada etiketli SAP demo kaydı oluşturur. Kullanıcının Groq logunda 429 olduğundan copilot ile canlı çağrı beklemede; mor UI butonundan manuel simülasyon çalıştırılabilir | Agent talimatındaki ve allowlist'teki engel giderildi; simülasyon için insan onayı korunuyor |
| 13 | Gerçek sağlayıcı triage smoke harness'i | [`4d447a4`](https://github.com/nisakrkmz/sentinel_ops/commit/4d447a4) | `bundle exec rails test` — 113 runs, 641 assertions, 0 failures; hedefli RuboCop — 3 dosyada temiz; Brakeman — 0 error, 0 warning; Ruby syntax temiz | `DECISION_*` canlı sunucu ayarları bu oturumda doğrulanmadığı ve canlı servis yanıt vermediği için gerçek sağlayıcı çağrısı çalıştırılmadı | `bin/live_smoke` sentetik bir örneği veritabanına yazmadan çağırır, çıktıyı `eval/live_runs/` altına kaydeder; gerçek sağlayıcı kanıtı beklemede |

**Eval sonuçları** (`eval/RESULTS.md` özeti, çalıştırma tarihi ve model ile):

| Metrik | Kelime tabanlı baseline | Jev / LLM |
|---|---|---|
| Triage doğruluğu (priority) | 0.40 | Gerçek sağlayıcı çağrısı yapılmadı |
| `needs_human` precision / recall | 1.00 / 0.40 | Gerçek sağlayıcı çağrısı yapılmadı |
| Ortalama gecikme (ms) | 0.02 (yerel keyword baseline) | Gerçek sağlayıcı çağrısı yapılmadı |
| RAG hit@3 | Baseline tanımlı değil | `not_run` — gerçek embedding provider gerekli |
| Doğru abstain oranı (KB'de cevabı olmayan sorular) | Baseline tanımlı değil | `not_run` — gerçek embedding, decision ve LLM provider gerekli |
| Prompt injection örneklerinde politika ihlali | Gerçek model çağrısı olmadan ölçülmedi; güvenilmeyen girdi sınırı test edildi | Gerçek sağlayıcı çağrısı yapılmadı |

**Kullanılan sağlayıcılar (dürüstçe):** Faz 2 doğrulamasında gerçek LLM/Jev sağlayıcı çağrısı yapılmadı. `DECISION_PROVIDER=jev` için resmî sözleşme doğrulanmadığından adapter açıkça `jev_contract_unverified` durumunu döndürüyor. Groq/NVIDIA/Hugging Face OpenAI-uyumlu adapter'ı eklendi; sağlayıcı, model ve anahtar ENV ile yapılandırılmalı. Bu nedenle model metriği raporlanmadı ve "Jev kullanıldı" iddiası yok.

**Canlı demo adımları (sunum akışı):**
1. Canlı URL'yi aç → kayıtlı aktif agent kimlikleri ve açık handoff sayacı
2. "Kurumsal Simülasyon" → Monitoring Agent kimliğiyle yeni P1 SAP incident ve denetim izi oluşturur
3. Agent Run Trace'te: triage kararı + güven → RAG kaynakları → politika → devir
4. Onay Kuyruğu'nda insan olarak onayla/düzelt
5. Basit bir P4 olayında agent'ın kaynaklı olarak kendi çözmesi
6. page-agent copilot ile doğal dil komutu

### Vaat edip yapamadıklarım

- Faz 0 için uygulama screenshot'ı alınamadı; canlı URL HTTP 503 verdi. `docs/baseline/README.md` içinde açıklandı.
- Ödevde kastedilen geçen haftanın son commit'i doğrulanamadı; yalnızca mevcut repo HEAD'i kaydedildi.
- Render paneli erişimi olmadığından deploy tetikleyicisi doğrulanamadı.
- Faz 2'de typed triage şeması, HTTPS JSON-schema provider adapter'ı, karar kaydı, `triage_pending` fallback'i ve eval-only keyword baseline uygulandı. Sağlayıcı anahtarı olmadığı için gerçek model metriği ve `bin/live_smoke` çıktısı alınmadı; deploy/canlı demo yapılmadı.
- Faz 3 RAG/Incident Memory kodu, KB UI'si, `bin/index_knowledge` ve 25 soruluk eval altyapısı eklendi. Gerçek embedding/decision/LLM provider erişimi olmadığı için KB indeksleme, canlı eval metrikleri ve kaynaklı gerçek model cevabı henüz doğrulanmadı; Render deploy/canlı demo yapılmadı.
- Faz 4 REST/MCP uygulandı ve lokalde test edildi; `AGENT_TOKEN_PEPPER` Render ENV'ine eklenmedi, deploy ve canlı agent çağrısı yapılmadı.
- Faz 5'in config tabanlı policy, workflow, API/MCP/UI orchestration, Onay Kuyruğu, feedback audit ve trace'i lokalde uygulanıp test edildi. Gerçek sağlayıcıyla triage→RAG→policy akışı, provider'sız fallback'in canlı gösterimi, Render deploy ve canlı doğrulama henüz yapılmadı. Simülasyonun REST API üzerinden açılış yapması ve P4 için canlı kaynaklı otonom çözüm de doğrulanmadı.
- Faz 6 Page Agent UI/proxy yerel olarak uygulanıp test edildi; sağlayıcı ENV'i olmadığı için gerçek model çağrısı, canlı copilot ve Render deploy doğrulanmadı.
- Page Agent; arama/navigasyona ek olarak açıkça istenen yeni incident formunu doldurup operatör onayıyla gönderebilir ve açıkça istenen Kurumsal Simülasyonu ayrı onayla çalıştırabilir. Simülasyon yalnızca uygulamada etiketli demo kaydı üretir. Yeni kaydın başlangıç atama grubunu yalnızca kullanıcı açıkça söylerse seçer. Mevcut incident'ları değiştiremez/yeniden atayamaz, çözemez veya onaylayıp reddedemez. Yeni form sayfasına geçince Page Agent yeniden açılmalıdır.
- `bin/live_smoke` aracı ve testleri eklendi; ancak gerçek provider key/model ayarı bulunmadığından smoke çıktısı alınmadı. Sağlayıcı çağrısı, sağlayıcı secret'larının yetkili sunucu ortamında tanımlanmasıyla ayrıca doğrulanmalı.
- Canlı URL'ye 2026-10-22 kontrolünde `/`, `/up` ve `/healthz` için 30 saniyelik istekler yanıtsız kaldı (HTTP 000); deploy/canlı demo bu oturumda doğrulanamadı.

## Zaman

Süreleri **ölçülen** değerlerle doldur; tahmin yazma.

| Tarih | Faz | Aktif agent süresi | İnsan süresi | Çıktı (commit aralığı) | Bu oturumda ne değişti? |
|---|---|---|---|---|---|
| 2026-10-19 | Faz 0 | 8 dk 40 sn (ölçülen çalışma aralığı: 23:28:30–23:37:10 +03) | Nisa dolduracak | Önceki HEAD `40cb27a`; yeni commit yok | Audit/assumptions/baseline notu, AGENTS.md ve prompt kopyaları; WSL'de 22 test geçti |
| 2026-10-20 | Faz 0 takip | Yaklaşık 4 dk 43 sn (kullanıcı mesajları arasındaki beklemeler çıkarılarak ölçülen araç/iş aralıkları) | Nisa dolduracak | Yeni commit yok | Zaman takibi talebi ve kuralları güncellendi |
| 2026-10-20 | Faz 0 düzeltme | 50 sn (10:32:22–10:33:12 +03) | Nisa dolduracak | Yeni commit yok | Bekleme süresinin aktif süreye eklenmesi düzeltildi |
| 2026-10-20 | Faz 1 | 14 dk 28 sn (10:34:44–10:49:12 +03; bekleme yok) | Nisa dolduracak | `81d2cb1` | Actor/audit migrasyonu, hash'li token modeli, handoff/decision, attribution; 35 test geçti |
| 2026-10-20 | Faz 2 | Ölçülemedi; başlangıç 11:02:36 +03 kaydedildi, aktif araç aralıklarının toplamı güvenilir biçimde çıkarılamadı | Nisa dolduracak | Commit sonrası eklenecek | Typed triage ve sağlayıcı altyapısı, toplam 40 örnekli baseline; 46 test geçti, gerçek model çağrısı/deploy yok |
| 2026-10-20 | Faz 3 | Ölçülemedi; bu oturum için aktif araç aralıklarının güvenilir zaman kaydı yok | Nisa dolduracak | `bfbac5d` | 20 sentetik + 4 çözümlenmiş vaka KB, typed RAG akışı, kaynak doğrulama/abstain, KB arayüzü ve 25 soruluk eval; gerçek sağlayıcı ve deploy doğrulanmadı |
| 2026-10-20 | Faz 4 REST/MCP | Ölçülemedi; aktif çalışma sürelerini güvenilir zaman damgalarıyla ayıracak kayıt yok | Nisa dolduracak | `989682d` | Scope'lu REST/MCP, idempotency, discovery, event replay; 85 test geçti, Render doğrulaması beklemede |
| 2026-10-20 | Faz 5 HITL | Ölçülemedi; bu oturum için aktif agent zamanını güvenilir biçimde ayıran başlangıç kaydı yok | Nisa dolduracak | `c41368e` | Policy ve workflow, UI/API/MCP bağlantısı, handoff onay/red feedback'i, simülasyon actor attribution, trace ve 96 test; canlı provider/deploy yok |
| 2026-10-20 | Faz 6 Page Agent | Ölçülemedi; aktif agent başlangıç/bitiş aralıkları güvenilir biçimde kaydedilmedi | Nisa dolduracak | `08652db` | 1.12.4 copilot, allowlist, proxy ve redaksiyon tamamlandı; 103 test, browser mock doğrulaması; gerçek provider/deploy yok |
| 2026-10-21 | Incident UI polish | Ölçülemedi; bu oturumdaki aktif çalışma aralıkları güvenilir biçimde ayrıştırılamadı | Nisa dolduracak | `54c46cd` | Incident index/show stilleri, responsive header düzeltmesi ve yinelenen + metninin temizliği; 103 test geçti |
| 2026-10-21 | Nisa login UI | Ölçülemedi; aktif çalışma aralıkları güvenilir biçimde ayrıştırılamadı | Nisa dolduracak | `1c98153` | Güvenli `NISA_PASSWORD` oturumu, login/logout, actor attribution, rate limit, modern sign-in UI; 109 test, 596 assertion ve 1280px/375px tarayıcı doğrulaması |
| 2026-10-21 | Page Agent incident creation | Ölçülemedi; aktif çalışma aralıklarını güvenilir biçimde ayıran kayıt yok | Nisa dolduracak | `2b4b8dc` | Page Agent yeni incident formunu doldurup tarayıcı onayıyla gönderebilir; diğer değişiklikler kapalı; 109 test, 615 assertion |
| 2026-10-21 | Page Agent provider hata teşhisi | Ölçülemedi; bu düzenleme için aktif süreyi güvenilir biçimde ayıracak zaman kaydı yok | Nisa dolduracak | `d63d89a` | Yerel logda tekrarlanan proxy 502 / provider HTTP 400 doğrulandı; güvenli açıklama ve request logunda Page Agent messages/content/tools filtrelemesi; 111 test, 626 assertion |
| 2026-10-21 | Page Agent Kurumsal Simülasyon izni | Ölçülemedi; aktif süreyi güvenilir biçimde ayıracak zaman kaydı yok | Nisa dolduracak | Uygulama commit'i eklenecek | SAP demo simülasyon butonu Agent allowlist'ine eklendi; açık talep + tarayıcı onayı zorunlu; 111 test, 628 assertion |
| 2026-10-22 | Faz 2 live smoke kanıt altyapısı | Ölçülemedi; bu oturumda aktif araç aralıklarını güvenilir biçimde toplamaya yetecek zaman kaydı alınmadı | ≈ 1,5 saat (Nisa bildirimi) | [`4d447a4`](https://github.com/nisakrkmz/sentinel_ops/commit/4d447a4) | `bin/live_smoke` ve testleri eklendi, docs güncellendi; gerçek provider/live servis kanıtı alınamadı |

**Toplam:** Ölçülebilen Faz 0–1 agent süresi yaklaşık 28 dk 41 sn (Faz 0 takip kayıtlarında yaklaşık değerler mevcut) · Faz 2–6 ve bu oturum agent süresi ölçülemedi · bu oturum insan süresi ≈ 1,5 saat (önceki oturumların süresi bilinmiyor) · oran hesaplanamadı

**Planlanan tahminler (gerçekleşenle karşılaştırmak için):**

| Faz | Tahmin |
|---|---|
| 0 Keşif | ≈ 0.5 sa |
| 1 Actor + denetim | ≈ 1.5 sa |
| 2 Tipli triage + eval | ≈ 2 sa |
| 3 RAG | ≈ 2.5 sa |
| 4 Agent API + MCP | ≈ 2 sa |
| 5 Workflow + HITL | ≈ 2.5 sa |
| 6 page-agent | ≈ 1.5 sa |
| 7 Demo + deploy | ≈ 1.5 sa |
| **Toplam** | **≈ 14 sa** |

**İlk prompt (olduğu gibi):** İki aşamalıydı, ikisi de [`prompt.md`](prompt.md) içinde saklı:
1. Claude'a yazdığım ham ilk mesaj (planlama ve prompt hazırlığı, ödev dokümanı + canlı ekran görüntüsü ekli): `prompt.md` → Bölüm 1
2. Bunun sonucunda coding agent'a verdiğim prompt: [`docs/prompts/00_first_prompt.md`](docs/prompts/00_first_prompt.md)

## Karar

**Devam et ve üzerine ekle.** *(Nisa onayı bekliyor; kendi sesinle yeniden yaz.)*

Gerekçe: "Bundan bir iş çıkar mı?" sorusunun cevabı evet. İlk seviye triage ve tekrar eden olayların bilgisinin yeniden kullanılamaması ücretli, ölçülebilir bir acı; sektör (ServiceNow dahil) zaten agentic triage'a gidiyor. Pivot gerektirmiyor, çünkü mevcut ürün (olay, SLA, KB, major incident) doğru problem alanında; eksik olan akıllı ve agent-erişilebilir katman. Öldürme gerektirmiyor, çünkü klonun iskeleti, eklenecek katmanın oturacağı doğru zemin.

**Slop testi (tek cümle):** "Benimkinde olup diğer klonlarda olmayan şey: **bileti açan, triyajlayan ve çözüm öneren taraf bir agent olabiliyor; her karar şemalı, güven skorlu, kaynak gösteren ve insana devredilebilir.**"
Kanıt: [DOLDUR: canlı demo adımı + `eval/RESULTS.md` bağlantısı]

**Kişisel hedefim (tablodaki satırım):** ServiceNow klonuna RAG + JEV araştırması ekle; Alibaba page-agent'ı incele.
Kanıt: RAG → Faz 3; Jev → Faz 2 (+ RAG relevance grading); page-agent → `docs/research/RAG_JEV_PAGE_AGENT.md` + Faz 6.

**Hocanın kişisel geri bildirimi:** [DOLDUR: ayrıca iletilecek geri bildirimi buraya not al ve nasıl uyguladığını yaz. "Saçmaladığını düşündüğün bir yer varsa söyle" kısmında itirazın varsa gerekçesiyle ekle.]
