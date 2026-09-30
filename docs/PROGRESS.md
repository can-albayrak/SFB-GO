# SFB:GO – Progress

Her oturumun sonunda güncellenir. Yeni oturum buradan devam eder.

**Şu anki aşama:** 0 – Kurulum
**Son güncelleme:** 2026-09-30

## Aşamalar

Her aşamanın sonunda oynanabilir bir sürüm olur; bir aşama bitmeden diğerine geçilmez.

| # | Aşama | Önerilen model | Durum |
| --- | --- | --- | --- |
| 0 | Kurulum (Godot, MCP, repo, proje iskeleti) | Opus | ⏳ Devam ediyor |
| 1 | Temel his: Wolf ile hareket, hitscan ateş, test haritası (tek oyunculu) | Opus → Sonnet | Bekliyor |
| 2 | Ağ: host/join menüsü, hareket senkronu, hasar, ölme/doğma | Opus | Bekliyor |
| 3 | Maç döngüsü: FFA kuralları, spawn seçimi/koruması, skor tablosu, kill feed, lag compensation | Opus → Sonnet | Bekliyor |
| 4 | Sınıf altyapısı: loadout menüsü, Resource tabanlı sınıf/silah/güç sistemi | Opus | Bekliyor |
| 5 | Sınıflar: Hawk, Bear, Cheetah, Volcano (sırayla, her biri ayrı test) | Sonnet | Bekliyor |
| 6 | Pickup'lar ve airdrop | Sonnet | Bekliyor |
| 7 | Harita blockout: alışveriş merkezi, 10 kişi testi | Sonnet | Bekliyor |
| 8 | Görsel geçiş: Blender modelleri, Mixamo animasyonları, ışık, post-process | Sonnet | Bekliyor |
| 9 | Cila: ses, anonslar, efektler, hit marker, grafik ayarları, 1050 Ti testi | Sonnet | Bekliyor |

Her aşama sonunda: bağımsız bir agent ile kod incelemesi → düzeltmeler → commit → gerekirse Release.

## Aşama 0 – Kurulum

- [x] Godot 4.4+ kuruldu (4.7.2, `Desktop\godot\`)
- [x] Godot'ta boş proje oluşturuldu (Mobile renderer, Jolt fizik, 60 Hz) bu klasörde
- [x] Godot MCP eklentisi: gerekmiyor, `@coding-solo/godot-mcp` Godot'u dışarıdan çalıştırıyor
- [x] Claude Code'a Godot MCP eklendi (`.mcp.json`)
- [ ] Blender + Blender connector kuruldu (aşama 8'e kadar ertelenebilir)
- [ ] GitHub'da private repo açıldı, ilk commit yapıldı (git henüz kurulu değil)
- [x] Klasör yapısı (`docs/ARCHITECTURE.md`) oluşturuldu, boş klasörlerde `.gitkeep`
- [x] Autoload'lar boş halde eklendi
- [x] Fizik katmanları isimlendirildi, tuş atamaları (Input Map) tanımlandı

## Bilinen sorunlar

- `Player` altındaki `Input` node'u, Godot'un global `Input` singleton'ıyla aynı adı taşıyor. Node adı `PlayerInput` olacak (aşama 1'de).

## Denge notları

Oynanış testlerinden çıkan "şu çok güçlü / çok zayıf" notları buraya.

_Henüz yok._

## Oturum günlüğü

| Tarih | Aşama | Ne yapıldı |
| --- | --- | --- |
| 2026-09-30 | – | Tasarım tamamlandı, dokümanlar hazırlandı |
| 2026-09-30 | 0 | MCP bağlandı, proje iskeleti kuruldu (project.godot, autoload'lar, klasörler, Input Map, katmanlar); çalıştı, hata yok. Kalan: git + GitHub repo |
