# Faz 0 — Repo audit

Baseline snapshot tarihi: 2026-10-19. Bu dosya Faz 0 öncesi kaynak kodu ve yapılandırma durumunu kaydeder; Faz 1 değişiklikleri için README ve CHALLENGE_LOG'daki sonraki kanıta bakın. Canlı URL ve test durumu ayrı ayrı kontrol edildi.

## Stack ve çalıştırma

- Ruby `3.3.8` (`.ruby-version`) ve Rails `8.1.4` (`Gemfile`).
- SQLite3, development/test DB'leri `storage/development.sqlite3` ve `storage/test.sqlite3`; production dosyası `DATABASE_PATH` üzerinden seçilir (`config/database.yml`).
- Rails Minitest (`test/`, `test/test_helper.rb`), zaman testlerinde ActiveSupport `travel_to`.
- Bağımlılık kurma: `bundle install`.
- Yerel hazırlık: `bin/rails db:prepare`, `bin/rails db:seed`.
- Sunucu: `bin/rails server -b 0.0.0.0 -p 3000`.
- Test: `bin/rails test`. WSL Ubuntu / Ruby 3.3.8'de çalıştırıldı: **22 runs, 111 assertions, 0 failures, 0 errors, 0 skips**.
- Windows host Ruby 3.3.12'de `bundle exec rails test` çalışmadı; mevcut Windows bundle'da Rails executable yoktu. WSL'de repo bundle'ı mevcut olduğundan test orada başarıyla doğrulandı.
- CI `.github/workflows/ci.yml`: Brakeman, bundler-audit, RuboCop ve `bundle exec rails db:test:prepare test`.

## Mevcut veri modeli ve davranış

- `incidents`: ServiceNow uyumlu alanlar (numara, açıklama, caller, servis, öncelik, durum, grup/atanan, SLA, kök neden ve çözüm notları) ile geriye dönük uyumluluk sütunları.
- `timeline_events`: incident'e bağlı olay geçmişi; modelde bilet yaratma ve SLA ihlali gibi olaylar yazılır.
- Seed, 4 çözülmüş geçmiş kayıt ve 2 açık demo kaydı oluşturur (`db/seeds.rb`); yeni actor/token/decision/handoff/RAG tabloları yok.
- Web rotaları incident CRUD-benzeri ekranlar ve durum/SLA/knowledge aksiyonlarıdır (`config/routes.rb`). Makine API'si, MCP, OpenAPI veya agent-card rotaları yoktur.
- `/up` Rails sağlık rotasıdır. `/healthz` uygulama rotası değildir.
- `simulate` denetleyicide sabit senaryolardan doğrudan incident üretir; API çağrısı ya da model kararı çalıştırmaz (`app/controllers/incidents_controller.rb:139`).

## "Smart Incident Knowledge Matcher" doğrulaması

Ekrandaki isim gerçek bir LLM/RAG özelliğini temsil etmiyor. Uygulama davranışı `app/models/incident.rb:256` ve `:361`–`:395` içindeki deterministik puanlamadır:

1. Aynı `error_signature` varsa 98 puan.
2. Servis eşleşmesine 35, kategori eşleşmesine 10 puan.
3. Başlık/açıklama token kümeleri için Jaccard örtüşmesine en çok 55 puan; toplam 99'da sınırlı.
4. 35 puanın altı atılır; kalanlar puana göre sıralanır.

Token çıkarımı ASCII `[a-z0-9_]` karakterleriyle 3+ uzunluktaki sözcükleri kullanır ve küçük bir stop-word listesi çıkarır. Bu, anlamsal embedding/retrieval veya kaynak doğrulaması değildir.

`app/controllers/incidents_controller.rb:63` benzer kayıtları detay sayfasına yükler. `app/views/incidents/show.html.erb:181` skor ve geçmiş çözüm notlarını gösterir; `apply_knowledge` / `apply_knowledge_from!` geçmiş notu kaynak numarasıyla yeni bilete kopyalayıp doğrudan çözüme geçirir. Çözümü uygulama aksiyonu mevcut davranışta simülasyon etiketi taşımıyor.

Mevcut testler (`test/models/incident_test.rb:223`, `:255`, `:283`) SAP örneğinde en az %80 benzerlik, VPN geçmiş çözümünün uygulanması ve alakasız eşleşme çıkmamasını sınar. Bu testler geçti. Örnek test kurulumları ve doğrulanmış beklentiler `docs/baseline/README.md` içinde; canlı çıktının ekran görüntüsü alınamadı.

## Deploy zinciri

- `render.yaml`: Frankfurt bölgesinde free `web`, Dockerfile tabanlı servis. Environment girdileri: `RAILS_MASTER_KEY`, `WEB_CONCURRENCY=1`, `RAILS_MAX_THREADS=3`, `DATABASE_PATH=/rails/storage/production.sqlite3`.
- `Dockerfile`: Ruby `3.3.8` imajı; start komutu `bundle exec rails server`.
- `bin/docker-entrypoint`: son iki argüman `rails server` ise start öncesi `bundle exec rails db:prepare` ve `bundle exec rails db:seed` çalıştırır.
- `render.yaml` deploy tetikleyicisini belirtmez; Render paneli erişimi olmadığı için otomatik/manual tetikleyici doğrulanamadı.
- Persistent disk tanımı yok; üretim SQLite dosyasının deploy'lar arasında korunması bu dosyalardan garanti edilemiyor.

## Baseline ve doğrulama sınırları

- İnceleme sırasındaki `main` HEAD: `40cb27a7948fa514cebf5854dda0ffe2d22cea11` (`Align project documentation and add logo`, 2026-10-19). Bunun ödevdeki "geçen hafta son commit'i" olduğu ayrıca doğrulanmadı.
- Public canlı URL `https://sentinel-ops-k0km.onrender.com` inceleme isteğinde HTTP 503 döndürdü. Canlı ekran, demo ve deploy sağlığı doğrulanamadı.
- Repoda bulunan `docs/images/g2-servicenow-review-page-9.png`, baseline uygulama ekranı değil G2 inceleme görselidir. Bu oturumda uygulama ekran görüntüsü alınmadı; varmış gibi kaydedilmedi.
- Ayrıntılar ve kanıt boşlukları: `docs/baseline/README.md`.
