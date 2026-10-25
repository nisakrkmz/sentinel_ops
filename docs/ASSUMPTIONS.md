# Assumptions and verified constraints

## Faz 0

- **Mevcut veri tabanı:** Uygulama yapılandırması development, test ve production için SQLite3 kullanıyor. Planlama sırasında farklı bir veritabanı varsayılmayacak; yeni vektör depolama tercihi RAG fazında, deploy kalıcılığı ve maliyet araştırıldıktan sonra yapılmalı.
- **Çalışma ortamı:** Bu oturumda Windows host Ruby 3.3.12'de Rails bağımlılığı yoktu. Mevcut repo bundle'ı olan WSL Ubuntu Ruby 3.3.8 kullanılarak testler çalıştırıldı; Windows bağımlılık kurulumu denenmedi.
- **Deploy/health:** Repodaki tanım Docker + Render'dır; deploy tetikleyicisi bilinmiyor. Mevcut health route `/up`; kullanıcı prompt'undaki `/healthz` henüz uygulamada yok.
- **Baseline:** Canlı site 503 verdi ve repoda SentinelOps ekran görüntüsü bulunamadı. Başlangıç ekranı veya canlı davranış hakkında doğrulanmamış görüntü/çıktı iddiası yapılmayacak.
- **Jev/LLM/embedding:** Şu an provider entegrasyonu veya anahtarları doğrulanmadı. Bir sağlayıcı kullanıldığı iddia edilmeyecek; adapter/payload kararı resmi doküman ve gerçek erişim doğrulanmadan alınmamalı.
- **Kapsam onayı:** İlk prompt Faz 0 raporuyla durmayı istiyor. Faz 1+ uygulama değişiklikleri kullanıcı onayı gelmeden başlatılmayacak.
- **Jev entegrasyonu:** Resmi Jev API/payload sözleşmesi doğrulanana kadar adapter unavailable döndürür. JSON provider için genel OpenAI-compatible HTTPS chat completions seçildi; bunun sağlayıcıya özel uyumluluğu gerçek credentials ile canlı smoke testte doğrulanmalıdır.
- **Faz 3 vector store:** Deploy'da mevcut SQLite kullanımı ve küçük KB korpusu nedeniyle embedding vektörleri SQLite JSON alanlarında tutulup Ruby cosine similarity ile sıralanır; pgvector/ek servis eklenmedi. Bu tercih yalnızca küçük demo korpusu için uygundur. Render tanımında kalıcı disk yok, bu nedenle production'da DB ve embedding kalıcılığı garanti edilmez.
- **Faz 3 providers:** Embedding ve JSON chat provider'ları HTTPS OpenAI-compatible endpoint adapter'larıdır; API anahtarı veya provider erişimi bu oturumda doğrulanmadı. Indexleme/eval gerçek ENV olmadan `not_run` kalır. Jev protokolü resmi sözleşme doğrulanana kadar kullanılmaz.
- **Faz 6 Page Agent:** npm registry kontrolünde `page-agent@1.12.4` güncel sürümdü ve yayımlı IIFE demo bundle'ı (MIT lisansıyla) repoda sabitlenerek vendored kullanılıyor. `autoInit=false` ile demo endpoint/bootstrap devre dışı bırakılır; ayrı bir sunucu proxy'si olmadan provider/anahtar istemciye verilmez. `PAGE_AGENT_ALLOWED_MODELS`, seçilen tek modeli içeren sunucu allowlist'idir. Copilot yalnızca `data-agent-id` kontrollerini kullanır ve state-changing UI eylemleri için insan onayı zorunludur; mevcut UI'da atama aksiyonu olmadığı için atama copilot kapsamına dahil değildir.

## Açık doğrulama işleri

- Render Dashboard'dan deploy tetikleyicisi, kalıcı disk ve son deploy durumunu kontrol et.
- Canlı servis erişilebilir olduğunda başlangıç ekranını çek ve mevcut matcher için canlı örnek akışını kaydet.
- Ödevde belirtilen "geçen haftanın son commit'i" hash'ini proje sahibiyle teyit et.

## Faz 7 öncesi düzeltmeler (2026-10-25)

- **Jev:** Resmî sözleşme docs.typesafe.ai/api üzerinden doğrulandı (`POST https://api.typesafe.ai/v1/systemone`, `model`/`state`/`questions`, `choice`/`score`/`noul`). Adapter bu sözleşmeyle yazıldı; Jev anahtarı olmadığı için canlı Jev çağrısı yapılmadı. Jev metin üretmediğinden triage `rationale` alanı Jev'in tipli cevaplarından deterministik olarak derlenir; bu bir LLM gerekçesi değildir.
- **Giriş:** `NISA_PASSWORD` kaldırıldı. Ek gem yerine Ruby stdlib OpenSSL PBKDF2-HMAC-SHA256 (210.000 iterasyon, kullanıcı başına tuz) seçildi; WSL'de sistem gem dizinine yazma izni olmadığı için `bcrypt` kurulamadı ve ek bağımlılık gerekmedi. Herkese açık demo instance için demo hesabı bilinçli olarak giriş ekranında gösterilir; `DEMO_OPERATOR_ENABLED=false` ile kapatılır. Render diski kalıcı olmadığından kayıtlı hesaplar deploy'da silinir.
- **Gemini kotası:** `gemini-2.5-flash` ücretsiz katmanı 20 istekte 429 döndürdü; `gemini-flash-lite-latest` önerildi. `reasoning_effort: "none"` bu modelde HTTP 400 verdiği için yalnızca ENV ile ayarlanırsa gönderilir.
- **needs_human + RAG:** Devir brief'inin "benzer olaylar + alıntılar" içermesi için triage `needs_human` dese de Incident Memory çalışır; politika yine devreder.
- **Page Agent:** page-agent `interactiveWhitelist` yalnızca ekler; gerçek kısıtlama blacklist ile sağlandı. Turbo hover prefetch, sentetik tıklamalarla yarıştığı ve ana sayfa GET'i SLA kontrolüyle yazma yaptığı için kapatıldı.
