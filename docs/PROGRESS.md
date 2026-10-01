# SFB:GO – Progress

Her oturumun sonunda güncellenir. Yeni oturum buradan devam eder.

**Şu anki aşama:** 6 – Pickup'lar ve airdrop (başlanmadı). Aşama 5 kapandı (2026-10-01). Aşama 2'nin gerçek iki bilgisayar testi hâlâ bekliyor.
**Son güncelleme:** 2026-10-01

## Sıradaki oturum

**Durum:** Tek dal `main`. Aşama 5 kapandı: Godot'ta headless doğrulandı, Can oynadı (Cheetah, hareket, lobi iki pencere, Hawk parlaması), aşama sonu bağımsız inceleme yapıldı ve bulgular düzeltildi. Smoke test 88/0, ağ testi lobi + geç katılma 0 hata.

1. **Aşama 6 – Pickup'lar ve airdrop:** GDD'deki değerlerle (pickup 45 sn / 5–6 nokta, airdrop 3. dakikadan sonra her 2–3 dk, airdrop silahları). Host-authoritative: pickup/airdrop kararları sadece host. Airdrop silahlarının `.tres`'inde `kill_ammo_reward = false`. Test haritasına geçici pickup / airdrop noktaları; yeni testler `smoke_test` ve `net_test`'e.
2. **Paralelde (Can hazır olunca) Blender:** karakter yüzü denemesi (Avaturn GLB → sadece kafa, poligon azaltma, 512 px doku; ham dosyalar `private_assets/`), AVM adayı [Suburban Mall 1980](https://sketchfab.com/3d-models/suburban-mall-1980-edcfb6e9dc47439491ce865b8e9f54b3) kontrolü → `docs/ASSETS.md`.
3. **Can'da bekleyen:** gerçek iki bilgisayar testi (Tailscale), Bear ve Volcano'nun ayrıntılı oynanışı.

**Doğrulama komutları:** `--import`, `res://tests/smoke_test.tscn`, `res://tests/net_test.tscn` (host önce, `--role=host` / `--role=client`, `+ --late`). Büyük bir pull'dan sonra ana klasörde önce `--import` (yoksa eski `.godot` önbelleği yüzünden menü scripti derlenmez, butonlar çalışmaz).

**Henüz yazılmayan kararlar:** yüz seçimi (aşama 8, yüzler gelince), HUD/menü yeni tasarımı (aşama 9; tasarım taslağı "SFB:GO HUD ve Menü": HUD beğenildi, menüler sade nötr gri; GDD "Görsel referans").

**Notlar:** Harita blockout'u aşama 7 (4–6 kişi ölçeği GDD'de). Dosya başına ~500–560 satır yeterli; `player.gd` 567.

## Aşamalar

Her aşamanın sonunda oynanabilir bir sürüm olur; bir aşama bitmeden diğerine geçilmez.

| # | Aşama | Durum |
| --- | --- | --- |
| 0 | Kurulum (Godot, MCP, repo, proje iskeleti) | ✅ Bitti |
| 1 | Temel his: Wolf ile hareket, hitscan ateş, test haritası (tek oyunculu) | ✅ Bitti |
| 2 | Ağ: host/join menüsü, hareket senkronu, hasar, ölme/doğma | ⏳ Devam ediyor |
| 3 | Maç döngüsü: FFA kuralları, spawn seçimi/koruması, skor tablosu, kill feed, lag compensation | ✅ Bitti (oynama testi bekliyor) |
| 4 | Sınıf altyapısı: loadout menüsü, Resource tabanlı sınıf/silah/güç sistemi | ⏳ Devam ediyor |
| 5 | Sınıflar: Hawk, Bear, Cheetah, Volcano (sırayla, her biri ayrı test) | ✅ Bitti (2026-10-01) |
| 6 | Pickup'lar ve airdrop | ⏭️ Sıradaki |
| 7 | Harita blockout: alışveriş merkezi, 10 kişi testi | Bekliyor |
| 8 | Görsel geçiş: Blender modelleri, Mixamo animasyonları, ışık, post-process | Bekliyor |
| 9 | Cila: ses, anonslar, efektler, hit marker, grafik ayarları, 1050 Ti testi | Bekliyor |

Her aşama sonunda: bağımsız bir agent ile kod incelemesi → düzeltmeler → commit → gerekirse Release.

## Aşama 0 – Kurulum

- [x] Godot 4.4+ kuruldu (4.7.2, `Desktop\godot\`)
- [x] Godot'ta boş proje oluşturuldu (Mobile renderer, Jolt fizik, 60 Hz) bu klasörde
- [x] Godot MCP eklentisi: gerekmiyor, `@coding-solo/godot-mcp` Godot'u dışarıdan çalıştırıyor
- [x] Godot MCP eklendi (`.mcp.json`)
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
- [x] Aşama sonu kod incelemesi. Düzeltilenler: host Burst Rifle serisinin 2/3 mermisini reddediyordu (artık tetik aralığı seriye bölünüyor, testte 9/9), loadout değiştirerek sınırsız bomba + can doldurma istismarı (bekleme oyuncuda taşınıyor, sadece yaralanmamışsa can dolar, maç arası değişim yok), çıkan oyuncunun bombasıyla hayalet kill, ince duvarın arkasında bomba doğması, maç arası bombanın yeni maçta patlaması, eski silahla uçuştaki atış (silah id kontrolü), bozuk ayar dosyası

- [x] Hareket revizyonu: CS 1.6 zıplama (yerçekimi 20,3, zıplama 7,3, hava ivmesi 10); Shift = sprint (x1,25, yavaş yürüme kaldırıldı); Ctrl = eğil, koşarken basınca slide; test range'de T = anında respawn (ölüyken de)

## Aşama 5 – Sınıflar

- [x] Tuning: AR/Burst/LMG recoil x1,6; slide daha uzun ve hızlı (boost 1,35, sürtünme 0,35, 1,1 sn, tavan base x1,55)
- [x] Slide sadece düz ileri (W) giderken başlar. Dürbün HUD: gerçek keskin nişancı dürbünü (siyah maske, daire lens, duplex nişangah). Dürbün sistemi (WeaponDef `scope_*`): sağ tık zoom, sens zoom'a bölünür, sallanma (eğilince yarı), dürbünde yavaşlama + sprint yok, dürbünsüz atışta yayılma konisi, dürbün HUD'u (`ScopeOverlay`)
- [x] Hawk (80 can): Heavy Rifle (250 hasar = her yerden tek atış, 1,5 sn kurma, 5 mermi), Marksman Rifle (50 hasar: kafa 1 / gövde 2 / bacak 3 atış); yedek tabanca
- [x] Grapple (15 sn, 40 m, 12 m/s çekme; ıska cooldown yemez; zıplayınca bırakır; herkes ipi görür) ve Decoy (15 sn, 8 sn hologram, sadece görsel)
- [x] Headless test: sınıf/silah/güç yükleniyor, zoom/FOV, grapple yukarı çekiyor, decoy + ip düğümleri oluşuyor
- [x] Can'ın Hawk testi: dürbün parlaması küçültüldü ve kısıldı (0,06 → 0,04, %60)
- [x] Bear (175 can, hız 6,0): Sledgehammer (72 hasar, 1,1 sn, geniş alan), Claws (28 hasar, 0,25 sn), Chainsaw (sürekli 7 hasar/0,1 sn, %75 hız); ana silah olarak yakın dövüş (`MeleeWeapon._fire`, `uses_ammo=false`)
- [x] Bear güçleri: Shield (12 sn, 3 sn, önden ~75° içinden gelen hasarı host engeller, herkes paneli görür), Charge (12 sn, 13 m/s x 0,55 sn, çarptığı rakibi 2 sn stunlar: host eylemleri reddeder, client girdiyi kilitler)
- [x] Yedek: 3 Throwing Knife (35 hasar, kafa 70, kavisli host-simüle `ThrownKnife`, duvara saplanır, üstünden geçince toplanır, isabet/ıska 8 sn sonra envantere döner); V = Tekme (8 hasar, 9 m/s geri itme)
- [x] Headless test: sınıf yükleniyor, bıçak fırlat/saplan/topla, charge hareketi, shield/stun RPC, üç silahın mankene hasarı
- [ ] Can'ın ayrıntılı Bear oynanışı (aşama Can'ın kararıyla kapatıldı; sorun çıkarsa düzeltilir)
- [x] **Cheetah** (70 can, 7,6 m/s): SMG (8 hasar / 0,075 sn, koşarken isabetli), Dual Pistols (sol/sağ tık ayrı, ortak 16'lık şarjör, 1,2 sn şarjör), yedek tabanca, V bıçak; Dash (5 sn, havada da), Adrenaline (15 sn bekleme, 4 sn +%25 hız / +%30 ateş hızı, host da uygular)
- [x] **Volcano** (110 can, 6,2 m/s): Shotgun (8 pellet sabit desen, host her pelleti izler, 7→20 m düşüş, hedef başına toplu hasar), Grenade Launcher (host-simüle, çarpınca patlar, kendine de hasar), yedek tabanca; Sticky Bomb (duvara/oyuncuya yapışır), Landmine (üstüne basanı patlatır, oyuncu başına 1)
- [x] Godot'ta açılış + headless doğrulama: `--import` (3 hata düzeltildi), smoke test 83/0, iki instance ağ testi (lobi ve geç katılma) 0 hata
- [x] Can'ın testi: Cheetah (hava ivmesi 10 → 3, Dual Pistols 0,2 sn, SMG recoil ×1,5), lobi iki pencerede sorunsuz. Volcano ayrıntılı oynanmadı
- [x] Aşama sonu kod incelemesi (bağımsız agent, `4b950ce..main`). Düzeltilenler: silah değiştirince ikinci silahın atışlarını host reddediyordu (ateş bütçesi artık slot başına), host'un reddettiği fırlatma bıçağı o hayat boyunca kayboluyordu (artık geri verilir), düşük canlı sınıftan geçerek can doldurma (artık "bu hayatta yaralandı mı" bakılır), Most Knife Kills Bear'ın çekiç/pençe/testere/tekme kill'lerini sayıyordu, fırlatma bıçağını saymıyordu (`WeaponDef.counts_as_knife`), loadout değişince kalkan kalıyordu, mayın düşerken patlayabiliyordu (artık yere oturunca kurulur), stun grapple/charge/dash'i durdurmuyordu, Start'tan hemen sonra katılan oyuncusuz kalabiliyordu (host Game hazır olunca alır), ölünce STUNNED yazısı ve grapple ipi kalıyordu, client host'un hayat sayacını ileri itebiliyordu. Smoke test'e 5 kontrol eklendi (88/0)

## Tasarım geçişi (2026-10-01) — bitti

İş bilgisayarında yazıldı (Godot yoktu); evde Godot 4.7.2 headless ile doğrulandı, Can oynadı, aşama 5 ile kapandı. Kamera hissi, Settings ve vuruş hissi için ayrıca yorum gelmedi; oynadıkça ayarlanır.

- [x] Hareket hissi: coyote time (0,1 sn) + jump buffer (0,1 sn), slide'dan zıplamada hız korunur (kazanç yok), serbest hava ivmesi + havada da 1,3 tavanı, kademeli hız cezası (`WeaponDef.move_spread`, eğri, silah başına)
- [x] Kamera ve his: hızla FOV kayması, hafif head bob, iniş çökmesi, slide'da alçalma + yatma, hasar sarsıntısı; hepsi Settings'ten %0–100 (`data/camera/default.tres`)
- [x] Settings paneli (ana menü + Esc): FOV, hassasiyet, crosshair (renk/boy/boşluk/kalınlık/nokta/hit marker), kamera efektleri
- [x] Vuruş hissi: host onaylı X hit marker (gövde/bacak beyaz, kafa kırmızı), maçta da hasar sayıları (sadece vuranın ekranında), hit marker aç/kapa
- [x] Denge: AR 16/0,12 (0,72 sn), Burst 16/0,42 (0,84 sn), LMG 14/0,10 (0,70 sn), Marksman 0,6 sn aralık, Heavy Rifle bacak ×0,26 (öldürmez), Bear 6,3 m/s
- [x] Lobi: oyuncu listesi, hazır durumu, boş yüz yeri; host kill/süre/harita seçip Start der; geç katılma aynı yol. "Last host" ile tek tık bağlanma (`user://settings.cfg`)

## Bilinen sorunlar

- Bear ve Volcano ayrıntılı oynanmadı; gerçek iki bilgisayar testi henüz yok (sadece aynı PC'de iki pencere).
- Charge'ın host'taki çarpma penceresi istek gelince başlar ve host'un çizdiği (~100 ms geriden) konumu kullanır: charge'ın son ~100–150 ms'si hedeflere karşı denenmez; duvara erken çarpan charge'da pencere bitene kadar 1,3 m'ye giren yine stunlanır.
- Placeholder modeller: SMG = küçültülmüş AR, Dual Pistols = iki tabanca, Grenade Launcher = gerilmiş shotgun + silindir, mayın = silindir (aşama 8).
- Hız cezası ve shotgun'ın merkez yönü sahibinde seçilir, host gelen yönü izler (unscoped spread ile aynı model; hileli client sapmasız ateş edebilir).
- Hasar sayısı gerçekten düşen canı gösterir (kalan candan fazla vuruşta düşük sayı çıkar); kalkanın engellediği vuruşta marker/sayı yok.
- Adrenaline sahibinde host onayından önce başlar; host reddederse (stun, maç arası) 4 sn boyunca fazladan atışlar sessizce düşer.
- Yapışkan bomba oyuncuya yapışınca diğer client'larda kurbanın ~100 ms önünde görünebilir (host o oyuncunun anlık konumunu izliyor, client'lar oyuncuyu geriden çiziyor).
- Hız cezası dürbündeyken de geçerli (dürbünle yürürken Heavy/Marksman artık tam isabetli değil).
- Serbest hava kontrolü `standard.tres` ile tüm sınıflara geçerli (Wolf/Hawk/Bear da Quake tarzı air strafe yerine serbest yön değiştirme alıyor).
- Maç bitince lobiye dönülmez; eskisi gibi 10 sn sonra yeni maç başlar.
- Ölüm ekranındaki "öldürenin kalan canı" kill ödülünden önceki can.
- Aşama 6 notu: airdrop silahlarının `.tres`'inde `kill_ammo_reward = false` olmalı (varsayılan true).
- Geç katılma loadout ekranında Esc oyundan çıkar (henüz oyuncu yok, pause menüsü yok).
- Tek harita hâlâ test_range (mankenli). Mankensiz maç haritası aşama 7'de (mall).
- Bear'ın yakın dövüş silahlarıyla Bear'a karşı TTK hedefin üstünde (1,5–2,4 sn); sadece hız cezası istendiği için hasarlara dokunulmadı.
- Decoy sadece görsel: vurulamaz, kurşun içinden geçer (GDD "hologram" diyor; istenirse hitbox eklenir).
- Marksman Rifle şimdilik Burst Rifle modelini kullanıyor (yer tutucu, aşama 8).
- Bear'ın Sledgehammer/Claws/Chainsaw modelleri bıçak modelinin büyütülmüş hali; tekme görünmez (aşama 8).
- Stun ve knockback client tarafında uygulanıyor; host sadece stunlu oyuncunun ateş/güç isteklerini reddediyor (hareketi değil).
- Shield hasar yönünü saldıranın konumundan hesaplıyor (bomba dahil), bu yüzden arkadan patlayan bomba önden sayılabilir.

- Silah modeli duvarlara girebiliyor (viewmodel ayrı render katmanı aşama 8/9'da).
- Uzak oyuncu modeli animasyonsuz, eğilince y'de basılır; elindeki silah artık doğru model (`held_slot`) ama tutuş pozu yok (aşama 8).
- Lag compensation 400 ms'den yüksek gecikmede tam telafi etmez (bilinçli üst sınır).
- Bıçak savurma ve bomba atma başkalarına animasyon olarak görünmüyor (aşama 8).

- Anonslar (Double Kill vb.) yok: aşama 9 (ses).
- Host mermi/şarjör takibi yapmıyor: hileli client şarjör değiştirmeden ateş edebilir (arkadaş arası, bilinçli olarak ertelendi).

## Araçlar

- MCP: `godot` (çalışıyor), `blender` (`uvx blender-mcp`; Blender'da BlenderMCP → Connect gerekli), `meshy` (`MESHY_API_KEY` Windows kullanıcı ortam değişkeninden, repoda yok). Hepsi `.mcp.json`'da.
- Yer tutucu modeller: `tools/blender/build_placeholders.py` (Blender 5.2 headless, MCP gerekmez) → `assets/models/characters/soldier.glb`, `assets/models/weapons/{assault_rifle,pistol,heavy_rifle,shotgun}.glb`. Değiştirmek için scripti düzenle, yeniden çalıştır:
  `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/build_placeholders.py -- .`
- Meshy şimdilik kullanılmıyor (Can'ın kararı). Detaylı modeller aşama 8'de.

## Denge notları

Oynanış testlerinden çıkan "şu çok güçlü / çok zayıf" notları buraya.

- 2026-10-01 (Can, ilk test): Cheetah zor kontrol ediliyor, zıplarken akıyor, havada çok yön değişiyor. Serbest hava ivmesi 10 → 3 (`MovementDef.air_control_accel`, `standard.tres`, tüm sınıflar). Can: "daha iyi, gayet iyi".
- 2026-10-01 (Can): Dual Pistols ateş aralığı 0,3 → 0,2 sn (tabanca başına; Cheetah'a TTK ~0,8 sn). SMG recoil deseni ×1,5.

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
| 2026-09-30 | 4 | CS tarzı zıplama, Shift sprint / Ctrl slide, test range'de T ile respawn. Godot'ta hatasız açıldı; Can'ın his testi bekliyor. |
| 2026-09-30 | 5 | Recoil/slide tuning, dürbün sistemi, Hawk (Heavy/Marksman Rifle, Grapple, Decoy). Headless testte doğrulandı; Can'ın testi bekliyor. |
| 2026-09-30 | 5 | Bear: yakın dövüş ana silahlar, Shield, Charge, fırlatma bıçakları, tekme. Headless testte doğrulandı; Can'ın testi bekliyor. |
| 2026-10-01 | – | Sadece tasarım (kod yok): GDD'ye "Hareket hissi" bölümü ve harita pürüzsüzlük kuralları eklendi (kademeli hız cezası, slide sonrası hız korunur, serbest hava ivmesi, coyote time + jump buffer). Uygulama sonraki hareket tuning oturumunda. |
| 2026-10-01 | – | Sadece tasarım (kod yok): GDD'ye "Vuruş hissi" bölümü eklendi (X hit marker, kafa kırmızı, maçta hasar sayıları, mankenler sadece test range'de, flinch, 2000'ler ses kimliği). Uygulama aşama 3/9'da. |
| 2026-10-01 | – | Sadece tasarım: karakter yüzleri kararı (tüm kafalar açık, fotoğraf tabanlı yüzler oyunla gelir, menüden seçilir, ID ile senkron). Eve gidince: `private_assets/` klasörü + `.gitignore`, Avaturn GLB'den kafa çıkarma denemesi (Blender), 2 yüzle test. |
| 2026-10-01 | 5 | `cloud/design-pass` (iş bilgisayarı, Godot yok, **çalıştırılmadı**): hareket hissi, kamera hissi + Settings paneli, vuruş hissi, denge (.tres), Cheetah, Volcano, lobi + last host. gdparse + statik kontrol + bağımsız inceleme. Can'ın toplu testi ve Godot'ta doğrulama bekliyor. |
| 2026-10-01 | – | Sadece tasarım: harita ölçeği 4–6 oyuncuya göre (GDD: bina ~64×48 m, uçtan uca 15–20 sn, 10–12 spawn, 3 airdrop). `docs/ASSETS.md`: AVM prop/doku ihtiyaç listesi ve lisans takibi. Eksik bulundu: Hawk namlu parlaması (GDD dengeleyici) kodda yok. |
| 2026-10-01 | – | AVM adayı bulundu: Suburban Mall 1980 (Sketchfab, CC-BY) → ASSETS.md "Adaylar". Evdeki oturum planı PROGRESS başına yazıldı (test + Blender: yüz modeli ve AVM kontrolü). |
| 2026-10-01 | – | Sadece tasarım: maç varsayılanı 20 kill / 10 dk (`default.tres`), kill ödülü, airdrop silah detayları, pickup 45 sn / 5–6 nokta, şirket devleti AVM'si, Hawk parlaması, mayın + Volcano yarı öz-hasar, lobide yüz + sınıf seçimi. GDD'ye işlendi; kodu evdeki oturumda. |
| 2026-10-01 | 5 | (çalıştırılmadı) Kill ödülü (+20 can, +15 mermi), ölümcül mayın + yanıp sönen ışık, Volcano yarı öz-hasar, Hawk dürbün parlaması, lobide ve geç katılmada sınıf seçimi. `player.gd` 992 → 527 satır: NetSync / Requests / Status / Effects bileşenlerine bölündü (ayrı commit, sorun çıkarsa tek başına geri alınabilir). |
| 2026-10-01 | – | Sadece tasarım: HUD/menü taslağı (ana menü, HUD, lobi, ölüm + loadout). Tema "lanetli PS2" (gündüz, parlak, fast-food, tel çit, yapıştırma yüzler); devlet teması kaldırıldı. Uygulama aşama 9. |
| 2026-10-01 | 5 | (çalıştırılmadı) Geç katılana parlama/kalkan (StateSync `scope_glint`, `shield_up`), başkalarının elinde doğru silah (`held_slot` + WeaponDef `world_model`), `tests/smoke_test.tscn` otomatik testi. Evde devir planı bu dosyanın başında. |
| 2026-10-01 | 5 | Evde Godot doğrulaması: import'ta 3 hata düzeltildi (lobi `request_ready` çakışması, roster preload döngüsü, çıkan oyuncuda lag comp hatası). Smoke test 83/0. Yeni `tests/net_test.tscn` (iki process, gerçek ENet): lobi ve geç katılma modlarında 0 hata. Tasarım geçişi diff'i elle incelendi. `cloud/design-pass` main'e merge edildi, dal silindi; tek dal main. Sırada Can'ın oynama testi. |
| 2026-10-01 | 5 | Can'ın ilk testi: ana klasörde eski `.godot` önbelleği yüzünden menü butonları çalışmıyordu (`--import` ile düzeldi). Cheetah/hava kontrolü fazla: `air_control_accel` 3 eklendi. |
| 2026-10-01 | 5 | Hava ivmesi onaylandı. Dual Pistols daha hızlı (0,2 sn), SMG recoil ×1,5. |
| 2026-10-01 | 5 → 6 | Parlama küçültüldü/kısıldı. Aşama sonu bağımsız inceleme: 11 bulgu düzeltildi (slot başına ateş bütçesi, bıçak iadesi, can doldurma açığı, knife ödülü, kalkan/loadout, mayın kurulması, stun, Start sonrası katılma, ölüm sonrası kalıntılar, hayat sayacı), Charge penceresi bilinen sorun. Smoke 88/0, ağ testi 0 hata. **Aşama 5 kapandı.** Sırada aşama 6. |
