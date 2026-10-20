# Faz 0 baseline

## Kaynak revizyonu

- İnceleme anındaki branch: `main`, çalışma ağacı keşif öncesinde temizdi.
- Gözlenen HEAD: `40cb27a7948fa514cebf5854dda0ffe2d22cea11` (`Align project documentation and add logo`, 2026-10-19).
- Bu hash'in ders/ödev açısından geçen haftanın son commit'i olduğu doğrulanmamıştır.

## Canlı ekran / sağlık

- URL: https://sentinel-ops-k0km.onrender.com
- Bu oturumdaki GET kontrolü HTTP **503** döndürdü. Uygulama ekranı ve canlı demo bu nedenle doğrulanamadı.
- Repodaki `docs/images/g2-servicenow-review-page-9.png` G2 değerlendirme ekran görüntüsüdür; SentinelOps baseline ekran görüntüsü değildir.
- Uygulama ekran görüntüsü veya canlı bilet örneği bu dizine eklenmedi; elde olmayan kanıt varmış gibi gösterilmedi.

## Mevcut matcher: kaynak ve örnek test beklentileri

`app/models/incident.rb` içindeki matcher, kelime ve alan puanları kullanan deterministik bir algoritmadır; LLM, embedding veya RAG çalıştırmaz.

| Test örneği | Koddaki davranış / testin doğruladığı çıktı |
|---|---|
| SAP S/4HANA batch pool exhaustion, geçmiş çözülmüş kayıt ile yeni gelen kayıt | Aynı servisteki benzer metin için geçmiş kayıt önerilir; test skorun en az `%80` olduğunu ve önerilen çözümde `SM50 work process havuzu` bulunduğunu doğrular. |
| Global VPN Gateway / AnyConnect IP pool exhaustion | Benzer geçmiş kayıt önerilir; tek tıkla uygulama mevcut bileti `resolved` yapar ve `INC000875` kaynak numarasını/notunu çözüm notuna ekler. |
| HR Portal S3 upload hatası ile SAP Material Ledger olayı | Test, benzer eşleşme çıkmadığını doğrular. |

Bu üç davranış `test/models/incident_test.rb` içinde tanımlıdır ve WSL Ubuntu'da tüm Minitest suite'iyle çalıştırılmıştır. Skor değerleri testte ayrıca yazdırılmıyor; burada belirtilen değerler testin assertion eşiğidir, bağımsız canlı ölçüm değildir.

## Çalıştırılan test

`wsl.exe -e bash -lc 'cd /mnt/c/Users/korkm/Desktop/ruby/sentinel_ops && ruby -v && bundle exec rails test'`

Sonuç: Ruby `3.3.8`; **22 runs, 111 assertions, 0 failures, 0 errors, 0 skips**.
