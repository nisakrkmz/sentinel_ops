# AGENTS.md — SentinelOps

> Bu dosya, repoda çalışan her coding agent için tek doğruluk kaynağıdır. Değerler repodan doğrulanmıştır; bilmediğin şeyi tahmin yazma.

## Proje

SentinelOps, ServiceNow Incident Management modülünü ITIL v4 Service Operations çizgisinde klonlayan bir ITSM uygulaması. Bu hafta hedef: **agent-first** olay yönetimi (agent bilet açar, triyajlar, kaynaklı çözüm önerir, gerektiğinde insana devreder).

- Canlı URL: https://sentinel-ops-k0km.onrender.com
- Dil/çatı: Ruby 3.3.8, Rails 8.1.4
- Veritabanı: SQLite3 (`storage/`; production yolu `DATABASE_PATH` ile değiştirilebilir)
- Test çatısı: Rails Minitest (`test/`; `travel_to` ile zaman testleri)
- Uygulama kodu bu depo kökündedir. Hafta 1 geliştirme günlüğü `docs/history/WEEK1_DEV_LOG.md`; ödev kanıtı `CHALLENGE_LOG.md`; bu dosya proje talimatlarının kaynağıdır.

## Komutlar

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server -b 0.0.0.0 -p 3000
bin/rails test
ruby bin/eval_triage  # keyword baseline; gerçek provider kıyası için EVAL_LIVE=1
bin/live_smoke        # gerçek triage çağrısı; DECISION_* gerekir, JSON eval/live_runs/ içine yazılır
bin/index_knowledge  # onaylı KB parçalarını embedding modeliyle indeksle
bin/eval_rag         # gerçek RAG değerlendirmesi için EVAL_RAG_LIVE=1
```

## Deploy (Render)

- Servis türü ve yapılandırma dosyası: Render `web`, Docker; `render.yaml` → `Dockerfile`, ücretsiz plan, Frankfurt.
- Deploy tetikleyicisi: Render panelinde Settings → Deploy → **Auto-Deploy** (önerilen: *After CI Checks Pass*). 25 Ekim 2026'da `main`'e push deploy tetiklemedi; deploy panelden **Manual Deploy → Deploy latest commit** ile yapıldı. Push sonrası Events sekmesinde deploy başlamadıysa elle tetikle.
- Son canlı sürüm: `7df9099` (25 Ekim 2026), `/healthz` ile doğrulandı.
- Build komutu: `Dockerfile` ile imaj oluşturma. Start komutu: `bundle exec rails server` (Dockerfile `CMD`; varsayılan port 80).
- Başlangıçta `bin/docker-entrypoint`, server komutuyla başlatıldığında `bundle exec rails db:prepare` ve `bundle exec rails db:seed` çalıştırır; `EMBEDDING_PROVIDER` tanımlıysa arka planda `bin/index_knowledge` ile KB indeksini yeniden kurar (disk kalıcı olmadığı için her açılışta gerekir; başarısız olursa açılışı bozmaz).
- Sağlık kontrolü: `/healthz` (public JSON: DB durumu, sağlayıcıların yapılandırılıp yapılandırılmadığı ve model adı, KB indeks sayısı; anahtar/endpoint içermez) ve Rails'in `/up` rotası.
- Not: Render ücretsiz katmanında servis boşta uyuyabilir. Sunumdan önce canlı URL'yi aç ve ısıt.
- Render tanımında kalıcı disk yok; production SQLite kalıcılığı garanti edilmemiştir. Canlı doğrulama için her fazdan sonra deploy'u bekle ve demo adımlarını çalıştır.

## Ortam değişkenleri (anahtarlar yalnızca sunucuda)

| Değişken | Amaç | Zorunlu |
|---|---|---|
| `RAILS_MASTER_KEY` | Rails production credentials çözme | Evet |
| `WEB_CONCURRENCY` | Puma worker sayısı | Render'da `1` |
| `RAILS_MAX_THREADS` | Rails/Puma thread sayısı | Render'da `3` |
| `DATABASE_PATH` | Production SQLite dosya yolu | Render'da `/rails/storage/production.sqlite3` |
| `DEMO_OPERATOR_ENABLED` | `false` ise demo hesabı seed edilmez ve giriş ekranında gösterilmez | Hayır (varsayılan açık) |
| `AGENT_TOKEN_PEPPER` | API token HMAC digest'i için secret pepper | Token issue/auth işlemleri kullanılırsa |
| `DECISION_PROVIDER` | `jev` \| `groq` \| `nvidia` \| `huggingface` \| `gemini` | Triage provider kullanılırsa |
| `JEV_API_KEY` | TypeSafe Jev anahtarı (`DECISION_PROVIDER=jev`) | Jev seçilirse |
| `JEV_MODEL` / `JEV_BASE_URL` | Varsayılan `jev-latest` / `https://api.typesafe.ai/v1/systemone` | Hayır |
| `DECISION_REASONING_EFFORT` / `LLM_REASONING_EFFORT` | Ayarlanırsa `reasoning_effort` olarak gönderilir; Gemini'de `none` HTTP 400 verir, boş bırak | Hayır |
| `DECISION_API_KEY` | Schema-constrained triage provider key'i | LLM JSON provider seçilirse |
| `DECISION_MODEL` | Triage model adı | LLM JSON provider seçilirse |
| `DECISION_BASE_URL` | HTTPS OpenAI-compatible chat-completions endpoint'i | LLM JSON provider seçilirse |
| `LLM_PROVIDER` | `groq` \| `nvidia` \| `huggingface` \| `gemini` | Kaynaklı resolution üretimi |
| `LLM_API_KEY` | System 2 JSON chat anahtarı | Resolution sağlayıcısı seçilirse |
| `LLM_MODEL` | System 2 model adı | Resolution sağlayıcısı seçilirse |
| `LLM_BASE_URL` | HTTPS OpenAI-compatible chat-completions endpoint'i | Resolution sağlayıcısı seçilirse |
| `EMBEDDING_PROVIDER` | `groq` \| `nvidia` \| `huggingface` \| `gemini` | Semantik KB araması |
| `EMBEDDING_API_KEY` | Embedding sağlayıcısı anahtarı | Embedding sağlayıcısı seçilirse |
| `EMBEDDING_MODEL` | Çok dilli embedding model adı | Embedding sağlayıcısı seçilirse |
| `EMBEDDING_BASE_URL` | HTTPS OpenAI-compatible embeddings endpoint'i | Embedding sağlayıcısı seçilirse |
| `PAGE_AGENT_API_KEY` | Page Agent proxy'sinin sağlayıcı anahtarı; yalnızca sunucu | Page Agent copilot etkinleştirilirse |
| `PAGE_AGENT_BASE_URL` | HTTPS OpenAI-compatible chat-completions API base URL'i | Page Agent copilot etkinleştirilirse |
| `PAGE_AGENT_MODEL` | Page Agent için seçili model | Allowlist içinde olmalı |
| `PAGE_AGENT_ALLOWED_MODELS` | Virgülle ayrılmış model allowlist'i | Page Agent copilot etkinleştirilirse |
| API rate limit | `config/api.yml` — token başına 120 req/60 sn, 1–100 page size | Varsayılan açık |

Web arayüzü DB'ye bağlı hesaplar kullanır (`users` tablosu, PBKDF2-SHA256 hash; `/signup` kayıt, `/login` e-posta + şifre). Her `User` bir `human` actor'a bağlıdır. Seed, `config/demo_operator.yml` içindeki herkese açık demo hesabını oluşturur ve giriş ekranında gösterir. Render'ın diski kalıcı olmadığından kayıtlı hesaplar her deploy'da sıfırlanır; demo hesabı her açılışta yeniden oluşur. REST API ve MCP kendi bearer-token kimlik doğrulamasını kullanır.

Gemini ücretsiz katmanında `gemini-2.5-flash` günlük ~20 istekle sınırlı (2026-10-25'te 429 ile doğrulandı). Demo için `DECISION_MODEL`, `LLM_MODEL`, `PAGE_AGENT_MODEL` = `gemini-flash-lite-latest` kullan ve `PAGE_AGENT_ALLOWED_MODELS` içine ekle.

`DECISION_PROVIDER`/`DECISION_*`, LLM/embedding sağlayıcıları ve page-agent proxy değişkenleri şu an `render.yaml` içinde tanımlı değildir. Page Agent, bu dört ENV birlikte ayarlı ve seçilen model allowlist içinde ise etkinleşir; aksi halde UI copilot'ı beklemede gösterir, proxy 503 döndürür. Jev adapter'ı resmî `POST /v1/systemone` sözleşmesini kullanır (`app/services/jev/client.rb`); `JEV_API_KEY` yoksa karar `jev_not_configured` ile beklemede kalır. Token/provider işlemlerini deploy'da etkinleştirmeden önce gereken değerleri Render server environment'a ekle. Sağlayıcı anahtarları repoya, loglara, istemci koduna veya hata mesajlarına **asla** yazılmaz.

## Agent REST API ve MCP

- REST base `/api/v1`; OpenAPI `/api/v1/openapi.json`; A2A tarzı discovery `/.well-known/agent-card.json`; açıklama `/llms.txt`.
- MCP JSON-RPC 2.0 endpoint'i `/mcp`; desteklenen tools `open_incident`, `search_kb`, `get_incident`, `propose_resolution`, `resolve_incident`, `handoff_to_human`.
- Her REST işlemi ve MCP tool'u ilgili `incidents:*`, `kb:read`, `handoff:create` veya `events:read` scope'unu doğrular. Token oluşturulurken actor scope'larının ötesine geçilemez.
- `POST /api/v1/incidents` ile MCP `open_incident` aynı idempotency key ve normalized payload digest'ini kullanır. Aynı key/farklı payload `409`/tool error verir; tekrar triage çalıştırılmaz.
- API yanıtları `config/api.yml` ile yapılandırılan token başına rate limit başlıkları taşır. Sayaçlar process içi cache'dedir; birden çok instance'a geçilirse paylaşımlı cache ayarlanmalıdır.
- `GET /api/v1/events` son `Last-Event-ID` sonrasındaki timeline kayıtlarını `text/event-stream` batch olarak döndürür; client otomatik reconnect ederek cursor'ı ilerletir.
- API token plaintext'i yalnızca issue edildiği an elde edilir; hash'i saklanır. Public token issue endpoint'i yoktur.

## HITL ve agent workflow

- UI, `/api/v1` ve MCP incident açılışları `AgentWorkflow::Runner` kullanır. Sağlayıcı yoksa başarısız/pending triage audit edilir ve açık handoff üretilir; uydurma triage veya çözüm yoktur.
- HITL eşikleri yalnızca `config/hitl_policy.yml` içindedir. P1/P2, major incident ve kritik servisler otomatik çözülmez. P3/P4 otomatik çözüm için çözüm confidence eşiği, doğrulanmış KB citation'ı ve cited root-cause chunk'ı zorunludur.
- `/handoffs` insan onay kuyruğudur. Onay/red/düzeltme actor'ı ve feedback'i `decisions` ile audit edilir. Çözümün doğrulaması verilirse KB adayı oluşturulur; KB'ye doğrudan yazılmaz.
- Incident detail'deki Agent Run Trace, triage/RAG/policy/human review kararlarını gösterir. Simülasyon incident'leri `origin=simulation` ve SİMÜLASYON UI etiketi taşır; gerçek dış altyapı aksiyonu yapmaz.
- Faz 5 regresyon testi: `bin/rails test`; hedefli Ruby lint için değişen dosyaları `bundle exec rubocop` ile çalıştır.

## Page Agent copilot

- `page-agent@1.12.4` IIFE bundle'ı `public/vendor/page-agent-1.12.4.js` içinde MIT lisansı ve sürüm sabitlemesiyle vendored. Layout, `?autoInit=false` kullanır; vendor demo endpoint'ini başlatma.
- Feature sadece `PAGE_AGENT_API_KEY`, `PAGE_AGENT_BASE_URL`, `PAGE_AGENT_MODEL`, `PAGE_AGENT_ALLOWED_MODELS` sunucu ENV'leri geçerliyse etkinleşir. `PAGE_AGENT_MODEL`, allowlist içinde olmalı; tüm endpoint'ler TLS/HTTPS kullanmalı.
- Browser çağrıları `/page-agent/v1/chat/completions` same-origin proxy'sine gider. Proxy provider key'i ekler; istemciden gelen Authorization başlığını kullanmaz. Rate limit IP başına 30/dk, istek 64 KiB, completion 1,200 token, okuma timeout'u 8 sn. Rate-limit cache'i process-local'dir.
- Copilot yalnızca `data-agent-id` interaktif kontrollerine izin verir: her adımdan önce diğer tüm etkileşimli elemanlar `interactiveBlacklist`e konur (page-agent'ın whitelist'i tek başına kısıtlamaz, sadece ekler). `execute_javascript` aracı kapalıdır. `data-agent-private` değerleri, DB'deki caller adları, email ve telefonlar LLM'e gönderilmeden maskelenir.
- Copilot read/search/navigation içindir. Submit, resolution, assignment, claim, approve ve reject agent etkileşim allowlist'inde değildir; state-changing UI formları, Copilot görevi çalışırken insan onayı ister (insan kendisi tıklarken diyalog çıkmaz). Sağ alttaki `layouts/_copilot` başlatıcısı page-agent'ın orijinal panelini ve imleç maskesini açar (kullanıcı tercihi: orijinal görünüm korunur, özel sohbet paneli yazılmaz). Turbo render'ında `#page-agent-runtime_*` elemanları yeni body'ye taşınır; görev Turbo geçişlerinde sürer, adımlar süren Turbo ziyaretini bekler, agent'ın sentetik link tıklamaları `Turbo.visit`e yönlendirilir, tam sayfa yenilemesinde görev en fazla 2 kez devam eder. Turbo hover prefetch kapalıdır.
- Provider ENV yoksa UI "Provider beklemede" gösterir; credential paylaşmak için sohbete yapıştırma, yalnızca secret manager/Render server ENV kullan.
- Kaynak ve limitler: [`docs/research/RAG_JEV_PAGE_AGENT.md`](docs/research/RAG_JEV_PAGE_AGENT.md).

## Proje durumu

- Geçen haftanın (Hafta 1) son commit'i: [`40cb27a`](https://github.com/nisakrkmz/sentinel_ops/tree/40cb27a7948fa514cebf5854dda0ffe2d22cea11) (Nisa tarafından doğrulandı).
- Stack, veri modeli ve deploy bulguları `docs/AUDIT.md`; varsayımlar `docs/ASSUMPTIONS.md`; araştırma `docs/research/RAG_JEV_PAGE_AGENT.md`.
- Testler WSL Ubuntu / Ruby 3.3.8 üzerinde çalışır (`wsl.exe -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && bin/rails test'`). Windows host Ruby'sinde Rails gem'leri kurulu değil. WSL'de sistem gem dizinine yazma izni yok; yeni gem eklemek `bundle install` gerektirir, bundan kaçın.
- Render'da `AGENT_TOKEN_PEPPER` tanımlı değilse API/MCP token işlemleri canlıda etkin sayılmamalıdır.
- Triage/RAG/Page Agent sağlayıcıları HTTPS OpenAI-compatible endpoint'lerdir; canlıda Google Gemini kullanılır. Jev adapter'ı hazırdır ama ücretli olduğu için canlı demoda kullanılmaz (bilinçli karar, `CHALLENGE_LOG.md` → Karar).
- Faz 3 KB veri modeli yapılandırılmış 4-chunk makaleler ve SQLite JSON embedding'leri kullanır. 4 seed resolved incident + 20 açıkça `synthetic_seed` olarak işaretli makale vardır. Embed sağlayıcısı yoksa arama/çözüm önerisi disabled/pending kalır.
- `bin/index_knowledge` onaylı makaleleri mevcut embedding provider/model ile indeksler; `--force` tüm vektörleri yeniler. `bin/eval_rag` varsayılan olarak canlı model ölçümü yapmaz; gerçek çağrı için `EVAL_RAG_LIVE=1` gerekir.
- `bin/live_smoke` tek bir sentetik incident örneğini gerçek triage sağlayıcısına gönderir, veritabanına incident yazmaz ve sonucu API anahtarı/ticket metni olmadan `eval/live_runs/` altına JSON olarak kaydeder. Sağlayıcı yapılandırılmamışsa hata kodlu kayıt üretip non-zero ile çıkar.
- `/healthz` (sağlayıcı ve KB indeks durumu) ve `/up` mevcuttur.
- Testler `.env` dosyasını yüklemez (`config/application.rb`); birim testleri gerçek sağlayıcıya gitmez. Lokal tarayıcı doğrulaması için WSL'de sunucu + Windows Chrome headless CDP kullanıldı.

## Mimari kuralları

1. **Karar türüne göre model:** sınıflandırma/yönlendirme/skorlama → System 1 (Jev veya şema kısıtlı LLM); metin üretimi → System 2 + RAG.
2. **Karar mantığında anahtar kelime/regex yok.** Yalnızca `eval/baselines/` içinde, karşılaştırma için.
3. Her model kararı `decisions` tablosuna yazılır (sağlayıcı, model, prompt sürümü, girdi özeti, çıktı, güven, gecikme, kaynaklar).
4. Bilet metni **güvenilmeyen girdi**dir; içindeki talimatlar hiçbir aksiyonu tetiklemez.
5. Politika (HITL eşikleri) `config/` altında tablo olarak durur, kod içine gömülmez.
6. Simüle edilen aksiyonlar UI'da "SİMÜLASYON" etiketi taşır.
7. Sağlayıcı yoksa dürüst "devre dışı/beklemede" durumu; sahte cevap yok.

## Kod ve commit kuralları

- Küçük commit'ler, Conventional Commits, İngilizce mesaj.
- Yeni davranış = yeni test. Testi gevşeterek geçirme.
- Mevcut ekranlar ve seed verisi geriye uyumlu kalır.
- UI dili: mevcut karışık TR/EN ITSM terminolojisini koru; yeni bölümler aynı tasarım dilinde.

## Oturum protokolü (zaman takibi)

1. Aktif çalışma başlangıcını ilk iş/araç çağrısında kaydet.
2. `CHALLENGE_LOG.md` → **Zaman** bölümü sade tutulur (Nisa'nın tercihi): faz faz tablo yok, yalnızca toplam insan süresi ve toplam agent süresi. Agent süresine yalnızca aktif çalışılan aralıkları ekle; kullanıcı bekleme sürelerini çıkar; ölçülemeyen oturumları "ölçülemedi" diye belirt, tahmin etme.
3. Kullanıcı insan süresini kendisi verir; tahmin etme.
4. Kredi/token/maliyet takibi istenmiyor; bunları `CHALLENGE_LOG.md`'a ekleme.
5. `CHALLENGE_LOG.md` yalnızca ödevin istediği altı başlığı içerir (Başlangıç noktası, Acı, Bu haftanın vaadi, Yapılanlar ve kanıt, Zaman, Karar). Yeni kanıtı commit linki ve test komutuyla "Yapılanlar ve kanıt"a ekle; yapamadığını aynı bölümdeki "Vaat edip yapamadıklarım" altına yaz.
6. Kullanıcıdan yeni geliştirme geri bildirimi gelirse `docs/prompts/` altına numaralı dosya olarak ekle (`01_...md`).

## Tanım: bitti

Test yeşil · commit'lenmiş · deploy edilmiş · canlıda doğrulanmış · CHALLENGE_LOG'a kanıtıyla işlenmiş. Bunlardan biri eksikse bitmedi.
