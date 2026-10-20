# prompt.md — Bu haftanın promptları

Bu dosya, ödevdeki "İlk prompt'un (olduğu gibi)" ifadesinin iki olası yorumunu da karşılamak için hazırlandı. Aşağıdaki iki prompt da değiştirilmeden saklanmıştır.

| # | Prompt | Kime verildi | Amaç |
|---|---|---|---|
| 1 | Ham ilk mesajım (aşağıda) | Claude (sohbet arayüzü, Sonnet 5.5) | Durum analizi + coding agent için prompt hazırlatmak |
| 2 | [`docs/prompts/00_first_prompt.md`](docs/prompts/00_first_prompt.md) | Coding agent | Geliştirmeyi yapmak |

Süreç: Prompt 1 → Claude'un çıktıları (durum analizi, `AGENT_PROMPT.md`, `CHALLENGE_LOG.md` taslağı, `AGENTS.md` taslağı) → Prompt 2 olarak coding agent'a verildi.

---

## 1. Ham ilk mesajım (olduğu gibi, yazım hataları dahil)

**Ekler:** `odev.docx` (hocanın ödev metni) ve projenin canlı deploy ekran görüntüsü.

> Ruby dersinde geliştirmeye başladığımız proje üzerinde yeni geliştirmeler yapmak üzere bu haftanın ödevini tamamlamam gerekiyor. Planlı şekilde gitmek istiyorum. Ne kadar zamanımı aldı, projemdeki yeni güncellemeler neler olmalı gibi bilgileri düzenli olarak tutmak istiyorum. Benim projem SentinelOps isminde, ServiceNow firmasının Incident Managament modülünü ele aldığım bir proje. Aslında kurumsal yapıların işletim sistemi tarzında bir adlandırmadan bahsedilen oldukça güçlü bir proje olabilir burası. Benim ilk ödev olarak atanan ödevde çok daha basit ve klasik kaldığımı anladım hocamın yorumlamasından. Ayrıca şuan insandan-insana şeklinde bir akış var içeride fakat çok daha güçlü olmasını istiyorum. Sana ödevi ve projemin canlı deployda şuanki görüntüsünü veriyorum ona göre durum analizi yapmanı ve agent ile geliştirmeye tekrar başlamayı istiyorum, bunun için de comprehensive bir prompt istiyorum senden. odev dokümanında ismim de var, Nisa. Oradan da hocamın bana tavsiyelerini uygulamak istiyorum.

**Not:** Bu mesaj, bu hafta yazdığım ilk prompt'tur. Projeye yön veren kararlar (devam et kararı, insandan-insana akıştan agent-first akışa geçiş isteği, hocanın "klasik kaldı" yorumunu esas alma) bu mesajdaki niyetimden çıkmıştır.

---

## 2. Coding agent'a verilen prompt

Tam metin: [`docs/prompts/00_first_prompt.md`](docs/prompts/00_first_prompt.md) (kaynağı: `AGENT_PROMPT.md`).

Agent'a verilmeden önce [DOLDUR: değiştirdin mi? Değiştirdiysen ne değişti, yoksa "Değiştirilmeden verildi" yaz.]

---

## 3. Dürüstlük notu (kim neyi belirledi?)

- **Benim belirlediğim:** proje, hedef (daha güçlü, agent'lı akış), hocanın geri bildirimini uygulama kararı, "devam et" yönü [DOLDUR: kendi eklemelerini ve itirazlarını yaz].
- **Claude'un hazırladığı:** durum analizi, faz planı, `AGENT_PROMPT.md` ve şablonlar. Claude, Jev ve page-agent hakkında web araştırması yaptı.
- **Benim onayladığım/değiştirdiğim:** [DOLDUR]
- Planlama oturumunun süresi: Claude yanıt süreleri ölçülmedi. [DOLDUR: mesaj saatlerinden hesapla]
