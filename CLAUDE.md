# SFB:GO

Arkadaşlar arası, en fazla 10 kişilik, sınıf tabanlı FPS. Godot 4 + GDScript.

## Her oturumun başında

1. `docs/PROGRESS.md` oku → hangi aşamadayız, ne kaldı.
2. Çalışılacak sistemle ilgili `docs/ARCHITECTURE.md` bölümünü oku.
3. Tasarım sorusu olursa `docs/GDD.md`. Görsel referans: `docs/visual-reference.png`.

## Her oturumun sonunda

1. `docs/PROGRESS.md` güncelle: işaretlenen maddeler, bilinen sorunlar, oturum günlüğüne bir satır.
2. Mimari değiştiyse `docs/ARCHITECTURE.md` güncelle.
3. Anlamlı bir mesajla commit. **Commit mesajlarına ve PR açıklamalarına `Co-Authored-By`, Claude/Anthropic/model adı veya "Generated with" eki ekleme.**

## Kullanıcı (Can)

- Türkçe konuşur; cevaplar Türkçe. Oyun içi metinler ve kod İngilizce.
- Direkt ve iteratif çalışır, çıktıyı inceleyip net değişiklik ister.
- **Her zaman tam, kopyala-yapıştır hazır kod ister, kısmi diff değil.** Dosya düzenlerken dosyaya doğrudan yaz; sohbette kod gösterirken tam halini göster.
- Dürüst uyarılar ister, gereksiz vaaz istemez.

## Kesin kurallar

- **Server-authoritative:** Hasar, ölüm, skor, pickup, airdrop, spawn kararlarını sadece host verir. Client asla kendi canını veya skorunu değiştirmez.
- **Denge değerleri koda gömülmez**, `data/*.tres` dosyalarına gider.
- **Statik tipli GDScript.**
- Bir aşamayı bitirmeden sonrakine geçme. Her aşama sonunda oynanabilir sürüm.
- Kapsam dışı özellik ekleme (GDD'de yoksa önce sor).
- Değişiklikten sonra projeyi Godot MCP ile çalıştırıp hata çıktısını kontrol et. MCP yoksa (örn. bulut oturumu) Godot 4.7 headless ile doğrula: `godot --headless --path . --import` ve `godot --headless --path . --quit-after 300`, hata çıktısını oku.
- **Testleri sadece büyük değişiklikte koş (Can, token tasarrufu).** Sayı/denge ayarı (recoil, hasar, hız, boyut, `.tres` değerleri), görsel/ses/UI ince ayarı, doküman: **test yok**, sadece headless açılış kontrolü yeter. Test şu durumlarda:
  - `smoke_test`: yeni sınıf / silah / güç / pickup eklendi ya da bunların kodunda yapısal değişiklik (yeni mekanik, RPC imzası).
  - `movement_test`: `movement.gd` mantığı veya merdiven/basamak geometrisi değiştiyse.
  - `map_test`: yeni harita ya da harita üreteci değiştiyse.
  - `net_test`: ağ altyapısı (`net.gd`, StateSync yapısı, `game.gd` spawn akışı) değiştiyse.
  - Çıktıdan sadece özet ve FAIL / ERROR satırlarını oku.

## Bağlam tasarrufu

- Uzun log veya dosyaları sohbete yapıştırma; gerekeni oku.
- Subagent sadece aşama sonu kod incelemesi ve geniş aramalar için. Paralel kod yazdırma yok (aynı dosyalara dokunurlar).
- Aşama değişince yeni oturum önerilir; bu dosya ve `docs/` bağlamı taşır.
