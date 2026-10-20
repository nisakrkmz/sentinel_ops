# CHALLENGE_LOG

> Öğrenci: Nisanur · Proje: SentinelOps (ServiceNow Incident Management klonu)
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
- [ ] Anahtar kelime tabanlı karar mantığının kaldırılması; triage'ın tipli, güven skorlu karar (Jev / LLM) ile yapılması
- [ ] RAG ile kaynaklı çözüm önerisi; kanıt yetersizse abstain
- [ ] Agent-first API (+ OpenAPI, agent-card) ve MCP sunucusu
- [ ] Politika tabanlı HITL: otonom çözüm / onay bekleyen / devir
- [ ] Canlı Agent Run Trace ve Onay Kuyruğu
- [ ] page-agent araştırması ve sunucu proxy'li, maskelemeli entegrasyon
- [ ] Eval: kelime tabanlı baseline'a karşı sayısal karşılaştırma

## Yapılanlar ve kanıt

| # | Özellik | Commit | Test / komut | Canlı demo adımı | Durum |
|---|---|---|---|---|---|
| 1 | Keşif ve baseline | [`81d2cb1`](https://github.com/nisakrkmz/sentinel_ops/commit/81d2cb15f2cb6abd0a4c180fbc0710c6f7f271a1) (audit/baseline docs) | Faz 0: 22 runs, 111 assertions, 0 failures | Canlı URL 503; demo doğrulanamadı | Audit, assumptions ve prompt copies hazır; canlı screenshot yok |
| 2 | Actor modeli + denetim izi | [`81d2cb1`](https://github.com/nisakrkmz/sentinel_ops/commit/81d2cb15f2cb6abd0a4c180fbc0710c6f7f271a1) | `wsl.exe -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && bundle exec rails test'` — 35 runs, 163 assertions, 0 failures; 16 dosyada RuboCop temiz; Brakeman 0 warning | Mevcut geliştirme DB'sindeki 6 olay ve tüm timeline kayıtları actor'a bağlı; canlı deploy/demo beklemede | Faz 1 tamamlandı ve commit'lendi; deploy edilmedi |
| 3 | Tipli triage (Jev/LLM) + eval | [link] | `bin/eval_triage` | [adım] | ☐ |
| 4 | RAG (Incident Memory) + abstain | [link] | `[test komutu]` | [adım] | ☐ |
| 5 | Agent API + OpenAPI + MCP | [link] | `[test komutu]` | [adım] | ☐ |
| 6 | Politika motoru + HITL + Run Trace | [link] | `[test komutu]` | [adım] | ☐ |
| 7 | page-agent copilot | [link] | — | [adım] | ☐ |

**Eval sonuçları** (`eval/RESULTS.md` özeti, çalıştırma tarihi ve model ile):

| Metrik | Kelime tabanlı baseline | Jev / LLM |
|---|---|---|
| Triage doğruluğu (priority) | [DOLDUR] | [DOLDUR] |
| `needs_human` precision / recall | [DOLDUR] | [DOLDUR] |
| RAG hit@3 | [DOLDUR] | [DOLDUR] |
| Doğru abstain oranı (KB'de cevabı olmayan sorular) | [DOLDUR] | [DOLDUR] |
| Prompt injection örneklerinde politika ihlali | [DOLDUR] | [DOLDUR] |

**Kullanılan sağlayıcılar (dürüstçe):** [DOLDUR: Jev'e gerçekten erişildi mi? Erişildiyse hangi yol. Erişilmediyse "System-1 tarzı kararlar JSON-schema kısıtlı <model> ile üretildi, Jev kullanılmadı" yaz.]

**Canlı demo adımları (sunum akışı):**
1. Canlı URL'yi aç → "Agent'lar: N aktif · Onay bekleyen: N" göstergesi
2. "Kurumsal Simülasyon" → Monitoring Agent API üzerinden P1 SAP olayı açar
3. Agent Run Trace'te: triage kararı + güven → RAG kaynakları → politika → devir
4. Onay Kuyruğu'nda insan olarak onayla/düzelt
5. Basit bir P4 olayında agent'ın kaynaklı olarak kendi çözmesi
6. page-agent copilot ile doğal dil komutu

### Vaat edip yapamadıklarım

- Faz 0 için uygulama screenshot'ı alınamadı; canlı URL HTTP 503 verdi. `docs/baseline/README.md` içinde açıklandı.
- Ödevde kastedilen geçen haftanın son commit'i doğrulanamadı; yalnızca mevcut repo HEAD'i kaydedildi.
- Render paneli erişimi olmadığından deploy tetikleyicisi doğrulanamadı.
- Faz 2 ve sonrası başlamadı; Faz 1 tamamlandı, sonraki fazlar ayrı ilerletilecek.

## Zaman

Süreleri **ölçülen** değerlerle doldur; tahmin yazma.

| Tarih | Faz | Aktif agent süresi | İnsan süresi | Çıktı (commit aralığı) | Bu oturumda ne değişti? |
|---|---|---|---|---|---|
| 2026-10-19 | Faz 0 | 8 dk 40 sn (ölçülen çalışma aralığı: 23:28:30–23:37:10 +03) | Nisa dolduracak | Önceki HEAD `40cb27a`; yeni commit yok | Audit/assumptions/baseline notu, AGENTS.md ve prompt kopyaları; WSL'de 22 test geçti |
| 2026-10-20 | Faz 0 takip | Yaklaşık 4 dk 43 sn (kullanıcı mesajları arasındaki beklemeler çıkarılarak ölçülen araç/iş aralıkları) | Nisa dolduracak | Yeni commit yok | Zaman takibi talebi ve kuralları güncellendi |
| 2026-10-20 | Faz 0 düzeltme | 50 sn (10:32:22–10:33:12 +03) | Nisa dolduracak | Yeni commit yok | Bekleme süresinin aktif süreye eklenmesi düzeltildi |
| 2026-10-20 | Faz 1 | 14 dk 28 sn (10:34:44–10:49:12 +03; bekleme yok) | Nisa dolduracak | `81d2cb1` | Actor/audit migrasyonu, hash'li token modeli, handoff/decision, attribution; 35 test geçti |

**Toplam:** agent yaklaşık 28 dk 41 sn · insan süresi Nisa dolduracak · oran insan süresi girilince hesaplanacak

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
