# Assumptions and verified constraints

## Faz 0

- **Mevcut veri tabanı:** Uygulama yapılandırması development, test ve production için SQLite3 kullanıyor. Planlama sırasında farklı bir veritabanı varsayılmayacak; yeni vektör depolama tercihi RAG fazında, deploy kalıcılığı ve maliyet araştırıldıktan sonra yapılmalı.
- **Çalışma ortamı:** Bu oturumda Windows host Ruby 3.3.12'de Rails bağımlılığı yoktu. Mevcut repo bundle'ı olan WSL Ubuntu Ruby 3.3.8 kullanılarak testler çalıştırıldı; Windows bağımlılık kurulumu denenmedi.
- **Deploy/health:** Repodaki tanım Docker + Render'dır; deploy tetikleyicisi bilinmiyor. Mevcut health route `/up`; kullanıcı prompt'undaki `/healthz` henüz uygulamada yok.
- **Baseline:** Canlı site 503 verdi ve repoda SentinelOps ekran görüntüsü bulunamadı. Başlangıç ekranı veya canlı davranış hakkında doğrulanmamış görüntü/çıktı iddiası yapılmayacak.
- **Jev/LLM/embedding:** Şu an provider entegrasyonu veya anahtarları doğrulanmadı. Bir sağlayıcı kullanıldığı iddia edilmeyecek; adapter/payload kararı resmi doküman ve gerçek erişim doğrulanmadan alınmamalı.
- **Kapsam onayı:** İlk prompt Faz 0 raporuyla durmayı istiyor. Faz 1+ uygulama değişiklikleri kullanıcı onayı gelmeden başlatılmayacak.
- **Jev entegrasyonu:** Resmi Jev API/payload sözleşmesi doğrulanana kadar adapter unavailable döndürür. JSON provider için genel OpenAI-compatible HTTPS chat completions seçildi; bunun sağlayıcıya özel uyumluluğu gerçek credentials ile canlı smoke testte doğrulanmalıdır.

## Açık doğrulama işleri

- Render Dashboard'dan deploy tetikleyicisi, kalıcı disk ve son deploy durumunu kontrol et.
- Canlı servis erişilebilir olduğunda başlangıç ekranını çek ve mevcut matcher için canlı örnek akışını kaydet.
- Ödevde belirtilen "geçen haftanın son commit'i" hash'ini proje sahibiyle teyit et.
