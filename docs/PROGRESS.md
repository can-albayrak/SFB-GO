# SFB:GO – Progress

Her oturumun sonunda güncellenir. Yeni oturum buradan devam eder.

**Şu anki aşama:** 4 – Sınıf altyapısı (aşama 2 iki bilgisayar testi ve aşama 3 oynama testi hâlâ bekliyor)
**Son güncelleme:** 2026-09-30

## Aşamalar

Her aşamanın sonunda oynanabilir bir sürüm olur; bir aşama bitmeden diğerine geçilmez.

| # | Aşama | Önerilen model | Durum |
| --- | --- | --- | --- |
| 0 | Kurulum (Godot, MCP, repo, proje iskeleti) | Opus | ✅ Bitti |
| 1 | Temel his: Wolf ile hareket, hitscan ateş, test haritası (tek oyunculu) | Opus → Sonnet | ✅ Bitti |
| 2 | Ağ: host/join menüsü, hareket senkronu, hasar, ölme/doğma | Opus | ⏳ Devam ediyor |
| 3 | Maç döngüsü: FFA kuralları, spawn seçimi/koruması, skor tablosu, kill feed, lag compensation | Opus → Sonnet | ✅ Bitti (oynama testi bekliyor) |
| 4 | Sınıf altyapısı: loadout menüsü, Resource tabanlı sınıf/silah/güç sistemi | Opus | ⏳ Devam ediyor |
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
- [x] GitHub private repo: github.com/can-albayrak/SFB-GO
- [x] Klasör yapısı (`docs/ARCHITECTURE.md`) oluşturuldu, boş klasörlerde `.gitkeep`
- [x] Autoload'lar boş halde eklendi
- [x] Fizik katmanları isimlendirildi, tuş atamaları (Input Map) tanımlandı

## Aşama 1 – Temel his

- [x] Veri sistemi: `ClassDef`, `WeaponDef`, `AbilityDef`; `wolf.tres`, `assault_rifle.tres`, `pistol.tres`
- [x] Hareket: Quake tarzı ivme/sürtünme, air strafe, zamanlı bhop (1,3x tavan), crouch, crouch-jump, slide
- [x] Bakış: CS uyumlu hassasiyet ve FOV, physics interpolation + top-level kamera
- [x] Hitscan ateş: Assault Rifle (otomatik) + Pistol (yarı otomatik), 1/2 ile geçiş, R şarjör, sabit recoil deseni
- [x] Kafa 2x / bacak 0,75x hitbox'lar
- [x] Test haritası: hasar sayısı gösteren mankenler, parkur, bhop pisti
- [x] HUD: crosshair, hit marker (kırmızı = kill), can, mermi, hız göstergesi
- [x] Ana menü → Test Range
- [x] Can'ın his testi: hareket iyi; hasar fazla bulundu → AR 25→20, tabanca 26→22
- [x] Aşama sonu kod incelemesi. Düzeltilenler: eğilince hitbox'lar, tepeye bakıp spreyde görüş taşması, AR'da kısa tık, yüksek FPS'te recoil titremesi, efektlerin bir frame orijinde görünmesi, hareket değerleri `.tres`'e taşındı

## Aşama 2 – Ağ

- [x] `Net`: ENet host/join (port 7777), isim kaydı, host çıkınca menüye dönüş, offline test range
- [x] Ana menü: isim, Host Game, IP + Join, Test Range; komut satırı `--host` / `--join=IP` / `--name=X`
- [x] `game.tscn`: harita yükleme, MultiplayerSpawner ile oyuncu spawn, geç katılma, ayrılanın silinmesi
- [x] Hareket senkronu: sahip → host → diğerleri 30 Hz, 100 ms interpolasyon, uzak oyuncu gövde modeli
- [x] Host-authoritative ateş: client istek atar, host doğrular + raycast + hasar, hit onayı sadece atana
- [x] Can / ölüm `StateSync` ile host'tan; ölüm ekranı ("KILLED BY X"), 3 sn sonra rastgele noktada doğma
- [x] Esc paneli: Resume / Leave Game
- [x] Headless 2 instance testi: bağlanma, spawn, hareket senkronu, host'un client'ı öldürmesi, yeniden doğma
- [ ] **Can + arkadaşla gerçek test** (iki bilgisayar, Tailscale)
- [x] Aşama sonu kod incelemesi. Düzeltilenler: host hız kontrolü (ışınlanma reddi, testte doğrulandı), jitter'da kaybolan atışlar (bütçe tabanlı ateş hızı), geç katılanda can/manken durumu, geç katılmada paket sırası, respawn süresi `data/match/default.tres`'e

## Aşama 3 – Maç döngüsü

- [x] FFA kuralları: host menüde kill hedefi + dakika seçer; hedef/süre dolunca kazanan, 10 sn sonuç ekranı, otomatik yeni maç
- [x] Maç sonu ödülleri: Most Deaths, Longest Headshot, Most Self-Kills (knife ödülü aşama 4'te)
- [x] Doğma: düşmanlara en uzak nokta; 2 sn koruma, ateş edince biter (yanıp sönen model, HUD yazısı)
- [x] Tab skor tablosu, sağ üst kill feed (HS işareti, seni ilgilendirenler sarı), üstte süre + lider skoru
- [x] Lider tacı (başkalarının ekranında)
- [x] Ölüm ekranı: öldüren, silah, öldürenin kalan canı
- [x] Lag compensation: RTT kadar geri sarma (A/B testte doğrulandı)
- [x] Headless 2 instance testi: koruma, skor senkronu, 5 kill'de bitiş, ödüller, yeniden başlama, taç (0 hata)
- [ ] **Can'ın oynayarak testi** (özellikle skor tablosu/kill feed/sonuç ekranı görünümü)
- [x] Aşama sonu kod incelemesi. Düzeltilenler: 0 kill/beraberlikte rastgele kazanan (artık DRAW), korumalı hedefte sahte hit marker, çıkan oyuncunun geçmişinde lag comp hatası, önceki hayata geri sarma, sonuç ekranında katılanın bozuk ekranı, eski respawn zamanlayıcıları, oturumlar arası kural/süre sızıntısı, maç arasında düşme ölümü

## Aşama 4 – Sınıf altyapısı

- [x] Hareket CS 1.6ya yaklaştırıldı: koşu 6,6 m/s, ivme 11, sürtünme 7, durma 2,5
- [x] Mermi izi: namludan uçan kısa parlak çizgi (280 m/s) + namlu alevi (yerel ve uzak)
- [x] Loadout sistemi: roster, `PackedInt32Array` loadout, host doğrulaması, StateSync ile yayılım, doğuşta / ilk 3 sn içinde anında uygulama, `user://settings.cfg` kaydı
- [x] Loadout menüsü: sınıf → silah → güç → DEPLOY; B ile aç/kapa, ölünce kendiliğinden açılır, "Next spawn: ..." yazısı
- [x] V ile bıçak (25 hasar, 1,5 m, 0,8 sn), knife ödülü
- [x] Q güç altyapısı (sahibinde bekleme, host doğrulaması, HUD göstergesi)
- [x] Wolf tam kit: Assault Rifle, Burst Rifle (3lü seri), LMG (100 mermi, %85 hız); Frag Grenade, Flashbang
- [x] Host-simüle bombalar (MultiplayerSpawner + Sync), frag alan hasarı, flash bakış açısına göre körleme
- [x] Modeller: bıçak, Burst Rifle, LMG, frag, flashbang (Blender scripti)
- [x] Headless testler: loadout anında/ertelenmiş, bıçak 25, frag ~70 yakında, flash 3,2 sn, ağda loadout senkronu (0 hata)
- [ ] **Can'ın oynayarak testi**
- [ ] Aşama sonu kod incelemesi

## Bilinen sorunlar

- Silah modeli duvarlara girebiliyor (viewmodel ayrı render katmanı aşama 8/9'da).
- Uzak oyuncunun elindeki silah hep AR (silah değişimi senkronlanmıyor); tracer gözden çıkar. Model animasyonsuz, eğilince y'de basılır (aşama 8).
- Lag compensation 400 ms'den yüksek gecikmede tam telafi etmez (bilinçli üst sınır).
- Uzak oyuncunun elindeki model hep AR; bıçak savurma ve bomba atma başkalarına animasyon olarak görünmüyor (aşama 8).
- Loadout değişimi (ilk 3 sn) güç bekleme süresini sıfırlıyor: kötüye kullanılabilir, gerekirse bekleme oyuncu nesnesine taşınacak.
- Anonslar (Double Kill vb.) yok: aşama 9 (ses).
- Host mermi/şarjör takibi yapmıyor: hileli client şarjör değiştirmeden ateş edebilir (arkadaş arası, bilinçli olarak ertelendi).

## Araçlar

- MCP: `godot` (çalışıyor), `blender` (`uvx blender-mcp`; Blender'da BlenderMCP → Connect gerekli), `meshy` (`MESHY_API_KEY` Windows kullanıcı ortam değişkeninden, repoda yok). Hepsi `.mcp.json`'da.
- Yer tutucu modeller: `tools/blender/build_placeholders.py` (Blender 5.2 headless, MCP gerekmez) → `assets/models/characters/soldier.glb`, `assets/models/weapons/{assault_rifle,pistol,heavy_rifle,shotgun}.glb`. Değiştirmek için scripti düzenle, yeniden çalıştır:
  `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/build_placeholders.py -- .`
- Meshy şimdilik kullanılmıyor (Can'ın kararı). Detaylı modeller aşama 8'de.

## Denge notları

Oynanış testlerinden çıkan "şu çok güçlü / çok zayıf" notları buraya.

_Henüz yok._

## Oturum günlüğü

| Tarih | Aşama | Ne yapıldı |
| --- | --- | --- |
| 2026-09-30 | – | Tasarım tamamlandı, dokümanlar hazırlandı |
| 2026-09-30 | 0 | MCP bağlandı, proje iskeleti kuruldu (project.godot, autoload'lar, klasörler, Input Map, katmanlar); çalıştı, hata yok. Kalan: git + GitHub repo |
| 2026-09-30 | 0→1 | Git + GitHub bağlandı, aşama 0 bitti. Aşama 1 ilk sürüm: hareket, AR + tabanca, mankenli test haritası, HUD. Headless testte hasar/kafa çarpanı doğrulandı. Sırada his testi. |
| 2026-09-30 | 1→2 | His testi olumlu, hasar düşürüldü. Kod incelemesi düzeltmeleri. Aşama 2 ilk sürüm: host/join, hareket senkronu, host-authoritative hasar, ölüm/doğma; headless iki instance testinde doğrulandı. Sırada gerçek iki bilgisayar testi. |
| 2026-09-30 | 2 | Aşama 2 kod incelemesi + düzeltmeler. Blender MCP (uv kuruldu) ve Meshy MCP `.mcp.json`'a eklendi; Can API anahtarını kendi ortamına girip uygulamayı yeniden başlatacak. Sırada: yer tutucu modeller, gerçek ağ testi, sonra aşama 3. |
| 2026-09-30 | 2→3 | Meshy'den vazgeçildi; yer tutucu asker + 4 silah Blender scriptiyle üretildi ve oyuna bağlandı. Aşama 3 ilk sürüm: FFA kuralları, ödüller, en uzak doğma + koruma, skor tablosu, kill feed, taç, lag compensation. Headless testlerde doğrulandı. |
| 2026-09-30 | 3→4 | Aşama 3 incelemesi + düzeltmeler. Hareket hızlandı/sürtünme arttı, yeni mermi izi + namlu alevi. Aşama 4 ilk sürüm: loadout sistemi ve menüsü, bıçak, Q güç altyapısı, Wolf tam kit (Burst Rifle, LMG, frag, flash), host-simüle bombalar. Headless testlerde doğrulandı. |
