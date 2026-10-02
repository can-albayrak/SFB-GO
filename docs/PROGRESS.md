# SFB:GO – Progress

Her oturumun sonunda güncellenir. Yeni oturum buradan devam eder.

**Şu anki aşama:** 7 – Harita blockout (AVM): yazıldı ve headless doğrulandı, **Can oynamadı**. Aşama 6 kapandı (2026-10-01). Modeller (aşama 8) Can'la birlikte. Görsel geçişin ilk turu (UI, atmosfer, birinci şahıs gövde) yapıldı. Aşama 5 kapandı; aşama 2'nin iki bilgisayar testi geçti (2026-10-01).
**Son güncelleme:** 2026-10-02

## Sıradaki oturum

**En yeni (2026-10-03 gece, evde, Can test edecek):**
- **Yeni eller:** hvarley'in "Rigged Low Poly FPS Hands" modeli (CC-BY). Eski PSX kolları ve IK kaldırıldı. İki önkol, modelin kendi tüfek tutuşuyla, her silahın kabza/kundak noktasına oturuyor; parmaklar hep gerçek tutuşta. Çift tabancada sol el aynalı sağ el. Bear'ın silahlarına (balyoz, pençe, testere, fırlatma bıçağı) bakılmadı: Can'ın kararıyla Bear kaldırılacak.
- **Tarama:** kamera artık tepmeyle kaymıyor (`recoil_view_share = 0`): nişangah sabit, mermiler desene göre tırmanıyor, eldeki silah yukarı/geri vuruyor.
- **Oyuncu gövdesi:** jonniemadeit'in "PSX Base Male" modeli (CC-BY, 1,8 m). İskeletsiz, kollar aşağıda; eldeki silah göğüs önünde duruyor (poz/rig sonra).
- **Exe:** Steam sürümü için GodotSteam şablonları (~460 MB) indirilecek, Can'ın onayı bekleniyor.

**Önceki (2026-10-02 akşam, evde):**
- **Silah tutuşları baştan:** her silahın sağ/sol el noktası gerçek kabza ve kundakta (yandan ölçekli görüntülerden okundu, `tools/apply_view_grips.py`). Tüfeklerde kollar ~20° dönüyor (sol omuz öne), sol el kundağı alttan kavrıyor. Omuzlar aşağı alındı (sol alttaki düz üst kol parçası gitti). Tabanca ve revolver tek el. Balyozda iki el sapta. Bıçak ve fırlatma bıçağı sıkı yumrukta, sap avuç içinden geçiyor. Revolverin dışarı sallanan silindiri düzeltildi (Blender ile yeniden işlendi).
- **Animasyonlar:** bıçak sağ üstten sol alta kesik (bütün kol hareket ediyor), balyoz/iki elli silahlar yukarıdan iniş; fırlatma bıçağı ilk karede elden çıkıyor, el ileri savruluyor, aşağı inip yeni bıçakla dönüyor.
- **Sniper (Hawk'ın iki tüfeği):** dürbünsüz nişangah yok, kalçadan çok dağınık (Heavy 9°, Marksman 6°), dürbün yavaş açılıyor (0,35 / 0,3 sn) ve tam açılana kadar isabet düşük.
- **Denge:** tüm tepmeler ×1,2; Railgun 4 mermi; Minigun 3° taban dağılma; bıçak elde iken %15 hızlı; slide sırasında +7° dağılma; eğimden aşağı slide hızlanıyor ve eğim boyunca sürüyor (sınıf hızının 1,6 katına kadar).
- **Ice Yard:** %20 büyük (67×67 m), kapalı ve karanlık hava.
- **Bakılacak:** tutuşlar oyunda nasıl (özellikle GL, Minigun, Railgun, SMG), bıçak/balyoz savurma hızı, Ice Yard karanlığı. Steam gerçek istemciyle hâlâ denenmedi.
- **Ana klasör (main) uyarısı:** `autoload/net.gd`'de commitlenmemiş, yarım kalmış eski bir Steam denemesi var (var olmayan `SteamNet`'e başvuruyor; yerini `SteamLink` aldı). Main'i güncellemeden önce bu değişiklik atılmalı (`git checkout -- autoload/net.gd`); `addons/godotsteam/` dokunulmadan kalabilir.

**Yeni (2026-10-02, ikinci bulut oturumu, Can test edecek):**
- **Gerçek kollar:** Can'ın PSX First Person Arms paketi; kutu kollar yerine rigli kollar, IK ile silahı tutuyor (silahta yumruk pozu, bıçakta bıçak pozu). Ekran görüntüleriyle (Xvfb + yazılım GL) tüfek, tabanca, SMG, bıçak, balyozda kontrol edildi. Bakılacak: tüfekte sol elin önden tutuşu (`HANDGUARD_ROLL`, `HANDGUARD_SHARE`), kolların boyu/yeri (`ARMS_OFFSET`, `ARMS_SCALE`), ateş ederken / bıçak savururken his. Eldivenli doku da pakette var (`private_assets/arms/arms_gloves_01.png`), istenirse geçilir.
- **Yeni harita Ice Yard** (lobide Mall'dan sonra): fy_iceworld'ün büyüğü, 56×56 m kar avlusu, ortada buz plazası, köşelerde nişancı yuvaları. 12 spawn, 5 pickup, 3 airdrop. map_test geçti (uçtan uca 11 sn). Oynanmadı.
- **Tüm silahlarda tepme %15 arttı** (`recoil_pattern` ×1,15).
- **Test kuralı (CLAUDE.md):** testler sadece ilgili kod değişince koşulur.

**Önceki (2026-10-02, bulut oturumu):**
- **Steam sürümü (App ID 480, Spacewar):** `builds/SFB-GO_steam_windows.zip` bu oturumda üretildi (git dışı; Can'a dosya olarak gönderildi). Yeniden üretmek: `py tools/steam/build_steam.py --godot "<Godot 4.7.2 exe yolu>"` (ilk seferde ~460 MB GodotSteam şablonu iner). Herkes Steam açıkken `SFB-GO.exe`'yi açar → sağdaki STEAM panelinde host "HOST ON STEAM", diğerleri "FIND STEAM GAMES" listesinden JOIN ya da lobide host'un INVITE ile attığı Steam davetini kabul eder. **Gerçek Steam'le hiç denenmedi** (bulutta Steam istemcisi yok): lobi kurma, listeleme, katılma, oyun içi senkron, ping ilk testte kontrol edilecek. Düz Godot editöründe Steam yok (menü söyler), IP ile oyun aynen çalışır.
- **Bıçak 3. slotta (CS gibi):** her sınıfta 3 tuşu bıçak, sol tık vurur (25), **arkadan vuruş tek atar** (999, CS kuralı ~60°). V hızlı bıçak arkadan öldürmez. Airdrop silahı artık **4** tuşunda. Test Range'de mankenin arkasından (spawn'ın ters tarafı) denenebilir.
- **Yeni silah modelleri (Can'ın zip'leri):** FN FAL = Assault Rifle, Remington M700 = Heavy Rifle, Remington 870 = Shotgun, MAC-11 = SMG, Glock-18 = Pistol ve Dual Pistols, Colt Python = Revolver. Uzunluklar eskilerle aynı tutuldu (ekrandaki boy aynı). Oyunda bakılacak: tutuş/eller, namlu alevi yeri, FAL/870/MAC'in koyu dokusu PS2 filtresiyle fazla karanlık mı.

**Durum:** Tek dal `main`. Aşama 7'nin kodu ve AVM blockout'u 2026-10-02'de iş bilgisayarında yazıldı (Godot 4.7.2 headless, geçici kopya). Bütün testler geçiyor ama kimse oynamadı.

0. **Aşama 7 – Can'ın oynama testi (evde):**
   - Lobide harita listesi: "Mall (4-10)" varsayılan, "Test Range" ikinci.
   - AVM'de tek başına tur: yürüyen merdivenler, iç merdivenler (market ve mağaza), çatı merdiveni, yangın merdiveni, balkon merdiveni, yükleme rampası. Takılma, havaya kalkma, kamera zıplaması var mı?
   - Test Range'de yeni merdiven alanı (x −36 ile −26, z −17 ile −28): kaldırım, 0,15 / 0,3 / 0,4 m tekli basamaklar, 2 m'lik merdiven, çıkılmaması gereken 0,6 m'lik blok. Basamak çıkma hissi doğal mı, kamera yumuşak mı?
   - Akış: bölge değiştirmek 5–10 sn mi, yemek katı koridorunda Hawk çok mu güçlü, çatı çok mu açık, spawn'lar adil mi, iki kişiyle (iki pencere) birbirini bulmak kolay mı?
   - Notlar "Denge notları"na; yerleşim değişiklikleri `tools/maps/build_mall_blockout.py`'de yapılıp sahne yeniden üretilir.
   - Testler geçince: aşama sonu bağımsız inceleme, aşama 7 kapanır (GDD'deki 10 kişi testi 4–6 kişiyle de sayılabilir, Can'ın kararı).
0. **Görsel geçiş (sürüyor):** Can'ın oyunda bakıp yorumlaması: menüler, HUD, ekran filtresi, atmosfer, kollar/bacaklar. Sonra karakter ve silah modelleri (Blender), yüzler.
1. ~~**Aşama 6 – Pickup'lar ve airdrop:**~~ yazıldı (aşağıda). Notlar: GDD'deki değerlerle (pickup 45 sn / 5–6 nokta, airdrop 3. dakikadan sonra her 2–3 dk, airdrop silahları). Host-authoritative: pickup/airdrop kararları sadece host. Airdrop silahlarının `.tres`'inde `kill_ammo_reward = false`. Test haritasına geçici pickup / airdrop noktaları; yeni testler `smoke_test` ve `net_test`'e.
2. **Paralelde (Can hazır olunca) Blender:** karakter yüzü denemesi (Avaturn GLB → sadece kafa, poligon azaltma, 512 px doku; ham dosyalar `private_assets/`), AVM adayı [Suburban Mall 1980](https://sketchfab.com/3d-models/suburban-mall-1980-edcfb6e9dc47439491ce865b8e9f54b3) kontrolü → `docs/ASSETS.md`.
3. **Can'da bekleyen:** Bear ve Volcano'nun ayrıntılı oynanışı.

**Doğrulama komutları:** `--import`, `res://tests/smoke_test.tscn`, `res://tests/movement_test.tscn` (basamaklar, merdivenler, AVM rampaları, çatıdan atlama), `res://tests/map_test.tscn` (her haritada spawn / pickup / airdrop noktaları, navmesh ile yürüyerek ulaşılabilirlik, yüksek katlara en az iki yol), `res://tests/net_test.tscn` (host önce, `--role=host` / `--role=client`, `+ --late`; lobi yolu artık AVM'de koşar). AVM sahnesini yeniden üretmek: `python tools/maps/build_mall_blockout.py` (`--preview KLASÖR` ile katların üstten PNG'si, Pillow gerekir). Büyük bir pull'dan sonra ana klasörde önce `--import` (yoksa eski `.godot` önbelleği yüzünden menü scripti derlenmez, butonlar çalışmaz).

**Henüz yazılmayan kararlar:** yüz seçimi (aşama 8, yüzler gelince), HUD/menü yeni tasarımı (aşama 9; tasarım taslağı "SFB:GO HUD ve Menü": HUD beğenildi, menüler sade nötr gri; GDD "Görsel referans").

**Notlar:** Dosya başına ~500 satır hedefi; `player.gd` 660 ve `hud.gd` 629 satır (bölünmesi gerekebilir).

## Aşamalar

Her aşamanın sonunda oynanabilir bir sürüm olur; bir aşama bitmeden diğerine geçilmez.

| # | Aşama | Durum |
| --- | --- | --- |
| 0 | Kurulum (Godot, MCP, repo, proje iskeleti) | ✅ Bitti |
| 1 | Temel his: Wolf ile hareket, hitscan ateş, test haritası (tek oyunculu) | ✅ Bitti |
| 2 | Ağ: host/join menüsü, hareket senkronu, hasar, ölme/doğma | ✅ Bitti (iki bilgisayar testi 2026-10-01) |
| 3 | Maç döngüsü: FFA kuralları, spawn seçimi/koruması, skor tablosu, kill feed, lag compensation | ✅ Bitti (oynama testi bekliyor) |
| 4 | Sınıf altyapısı: loadout menüsü, Resource tabanlı sınıf/silah/güç sistemi | ⏳ Devam ediyor |
| 5 | Sınıflar: Hawk, Bear, Cheetah, Volcano (sırayla, her biri ayrı test) | ✅ Bitti (2026-10-01) |
| 6 | Pickup'lar ve airdrop | ✅ Bitti (2026-10-01) |
| 7 | Harita blockout: alışveriş merkezi, 10 kişi testi | ⏳ Blockout yazıldı, headless doğrulandı; oynama testi bekliyor |
| 8 | Görsel geçiş: Blender modelleri, Mixamo animasyonları, ışık, post-process | ⏳ Atmosfer, ekran filtresi, birinci şahıs gövde (yer tutucu) yapıldı; modeller bekliyor |
| 9 | Cila: ses, anonslar, efektler, hit marker, grafik ayarları, 1050 Ti testi | ⏳ Menü/HUD yeni tasarımı ve grafik ayarları yapıldı |

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
- [x] **Can + arkadaşla gerçek test** (iki bilgisayar): bağlandı, sorun yok (2026-10-01)
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

## Aşama 6 – Pickup'lar ve airdrop

- [x] `PickupDef` (`data/pickups/`): Health +50 (sadece canı eksiğe), Speed ×1,3 8 sn, Double Jump 10 sn, 45 sn'de geri gelir. `Pickup` harita nesnesi (`Map/Pickups/...`): host kimin aldığına karar verir, herkes dönen ikon / ışık / geri sayım hologramı görür, geç katılana durum gönderilir
- [x] Boost'lar host saatinde (hız kontrolü) ve sahibinde (his); `Player.powerups` (StateSync) ile başkaları oyuncuyu boost renginde parlarken görür; ölünce biter. Double Jump: havada bir zıplama daha (`Movement.air_jumps`)
- [x] Airdrop silahları (`data/weapons/airdrop_roster.tres`): Railgun (999, 8 mermi, duvar ve oyuncu deler, ışın), Minigun (15 × 0,05 sn, 200 mermi, 0,6 sn ısınma), Rocket Launcher (200 merkez, 6 m, roket itmesi = rocket jump, kendine %40). Şarjör = tüm mermi, şarjör değiştirme yok, mermiyi host sayar
- [x] 3. slot (`Player.SPECIAL_SLOT`, tuş 3): `special_weapon` / `special_ammo` StateSync; alınca hemen elde, taşırken %15 yavaş, başında duvar arkasından görünen "▼ RAILGUN" işareti, mermi bitince silah yok olur, ölünce kalan mermisiyle yere düşer (`WeaponDrop`, 45 sn), üstünden geçen alır
- [x] `AirdropManager` (`Game/Airdrops`): ilk 180 sn, sonra 120–180 sn'de bir, haritadaki `AirdropPoints`'ten boş bir nokta; kasa 12 sn paraşütle iner, kırmızı ışık hüzmesi; E 3 sn basılı tutunca açılır (hasar, ölüm, uzaklaşma iptal eder), rastgele silah. HUD: "AIRDROP INCOMING", "CAN GOT THE RAILGUN", açma barı, boost süreleri, 3 silahlı sağ alt
- [x] Test Range (`test_range.tres`): 5 sn'de bir kasa, 4 sn düşüş, en fazla 3 aktif (kasa + yerdeki + taşınan); 3 pickup spawn'ın önünde, 3 airdrop noktası
- [x] Headless: smoke test 112/0 (her pickup, kasa açma, Railgun duvar arkası, mermi sayımı, Minigun ısınma, rocket jump, ölünce düşme + alma), ağ testi lobi 29 + 26 / geç katılma 28 + 27 (boost, airdrop silahı, kasa client'a ulaşıyor)
- [x] Can'ın oynama testi: "güzel, gayet iyi". Düzeltilen: kasanın içinden geçiliyordu (inince katı, dünya katmanı), dürbünde görüş kendiliğinden aşağı kayıyordu (yavaş silahlarda geri tepmenin geri inişi tüm atış aralığını bekliyordu; artık en fazla 0,2 sn)
- [x] Aşama sonu bağımsız kod incelemesi. Düzeltilenler: havada / haritadan düşerek ölen taşıyıcının silahı ulaşılamaz yerde kalıyordu (artık zemine iner, düşüşte kaybolur), Minigun HUD sayacı geri zıplıyordu ve sonda hayalet atışlar vardı (sahibin sayısı geri artmaz), maç yeniden başlayınca alınmış pickup'lar eksik kalıyordu, Double Jump yere inerken buffer'lı bunny hop'u yiyordu, maç sonu ekranında kasa açma barı doluyordu. Minigun ısınmasının host kontrolü bilinen sorun

## Aşama 7 – Harita blockout (AVM)

- [x] Basamak çıkma (`Movement._move_and_step`): duvara takılınca "yukarı, ileri, aşağı" denemesi, `MovementDef.step_height` 0,4 m (`standard.tres`). Kapsülün yuvarlak altı basamak kenarına değdiği için üst yüzey kısa bir ışınla kontrol edilir; en az 0,15 m ileri gidilir (kenarda asılı kalmaz); göz yüksekliği yükselme kadar indirilip yumuşakça geri gelir. Zemine yapışma (floor snap) da 0,4 m: merdiven inerken havalanma yok. Charge ve Dash da basamak çıkar.
- [x] Harita kuralı: **merdivenler görsel basamak + görünmez rampa çarpışması** (CS haritaları gibi); arka arkaya sığ basamakta kapsül iki kenar arasında titriyordu. Rampanın üst ucu bağlandığı döşemenin kenarına tam oturur: arada 0,1 m'lik dışbükey kenar kalırsa floor snap tutmaz, inen oyuncu havalanır.
- [x] Harita listesi: `MapDef` / `MapList` (`data/maps/map_list.tres`: Mall, Test Range), lobide "Mall (4-10)", `Net.MAP_LIST` (eski `MAP_NAMES` / `MAP_PATHS` kaldırıldı). Mankenler sadece Test Range'de.
- [x] AVM blockout (`scenes/maps/mall/mall.tscn`, `tools/maps/build_mall_blockout.py` ile üretilir, 290 kutu):
  - **Bina:** 64×48 m, zemin 0 m, üst kat 5 m, çatı 10 m.
  - **Avlu:** 20×14 m, iki kat boyunca açık; çatıda tavan penceresi (içine atlanır, airdrop düşer). Etrafında halka koridor, üst katta korkuluklu galeri. Avluda kuru fıskiye, iki kiosk, saksılar, iki yürüyen merdiven.
  - **Kuzey:** zemin ve üst katta 4'er dükkân; zemin dükkânların arkasında dar servis koridoru (Bear/Volcano).
  - **Güney:** zeminde 2 dükkân ve giriş koridoru; üst katta binayı boydan boya geçen yemek katı koridoru (Hawk), tezgâhlar ve masalar kırıcı siper.
  - **Batı:** zeminde market rafları ve kasalar, iç merdiven; üst katta depo salonu ve ofisler.
  - **Doğu:** iki katlı mağaza, iç merdiven, çatı merdiveni.
  - **Dışarısı:** doğuda otopark (arabalar, bariyerler, gişe) ve yemek katına çıkan balkon merdiveni; batıda yükleme rampası, konteynerler ve çatıya kadar çıkan yangın merdiveni; kuzey ve güney dış şeritler (bina etrafında tur).
  - **Çit:** site 110×64 m, 3 m çit; çit hattında 60 m'lik görünmez duvar (çatıdan bhop'la atlayan çiti aşıyordu; kanca da üstüne yetişemez).
  - **Noktalar:** 12 spawn (her bölge ve kat); 6 pickup (3 Health dar yerlerde, Speed avlu ve otoparkta, Double Jump çatıda); 4 airdrop noktası (avlunun tavan penceresi altı, otopark, çatı, yükleme alanı).
- [x] Headless testler:
  - `movement_test` 45/0.
  - `map_test` 143/0: en uzun yürüme Spawn3 → Spawn12 127 m = 19,2 sn; çatıya 2, üst kata 6 yol var ve her biri tek tek kaldırılınca bile oralara ulaşılıyor.
  - Smoke 113/0.
  - Ağ testi: lobi 30 + 26 (AVM'de), geç katılma 29 + 29.
- [x] İki bilinen sorun kapandı:
  - Oyundan airdrop silahıyla çıkan oyuncunun silahı artık yere düşer (ölmekle aynı). Ağ testi bunu kontrol ediyor; düzeltme olmadan test başarısız oluyordu.
  - Geç katılırken loadout ekranında Esc artık oyundan atmıyor: pause paneli açılır, RESUME loadout'a döner, LEAVE GAME çıkar.
- [ ] **Can'ın oynama testi** (yukarıdaki liste)
- [ ] Aşama sonu bağımsız kod incelemesi

## Tasarım geçişi (2026-10-01) — bitti

İş bilgisayarında yazıldı (Godot yoktu); evde Godot 4.7.2 headless ile doğrulandı, Can oynadı, aşama 5 ile kapandı. Kamera hissi, Settings ve vuruş hissi için ayrıca yorum gelmedi; oynadıkça ayarlanır.

- [x] Hareket hissi: coyote time (0,1 sn) + jump buffer (0,1 sn), slide'dan zıplamada hız korunur (kazanç yok), serbest hava ivmesi + havada da 1,3 tavanı, kademeli hız cezası (`WeaponDef.move_spread`, eğri, silah başına)
- [x] Kamera ve his: hızla FOV kayması, hafif head bob, iniş çökmesi, slide'da alçalma + yatma, hasar sarsıntısı; hepsi Settings'ten %0–100 (`data/camera/default.tres`)
- [x] Settings paneli (ana menü + Esc): FOV, hassasiyet, crosshair (renk/boy/boşluk/kalınlık/nokta/hit marker), kamera efektleri
- [x] Vuruş hissi: host onaylı X hit marker (gövde/bacak beyaz, kafa kırmızı), maçta da hasar sayıları (sadece vuranın ekranında), hit marker aç/kapa
- [x] Denge: AR 16/0,12 (0,72 sn), Burst 16/0,42 (0,84 sn), LMG 14/0,10 (0,70 sn), Marksman 0,6 sn aralık, Heavy Rifle bacak ×0,26 (öldürmez), Bear 6,3 m/s
- [x] Lobi: oyuncu listesi, hazır durumu, boş yüz yeri; host kill/süre/harita seçip Start der; geç katılma aynı yol. "Last host" ile tek tık bağlanma (`user://settings.cfg`)

## Görsel geçiş (2026-10-01, aşama 8/9'dan öne alındı)

- [x] `Style` autoload: palet, sistem fontları, Theme (varsayılan temaya birleştirilir); UI tabanı 1280×720 + canvas_items stretch
- [x] Ana menü, lobi (oyuncu tablosu + yüz yeri, loadout, maç ayarları), loadout menüsü (3 sütun + özet + DEPLOY), ayarlar, Esc paneli: tasarım taslağı "SFB:GO HUD ve Menü"
- [x] HUD: sol altta bevel can / güç barı + sınıf, sağ altta silah silüeti + mermi (diğer silah soluk), üstte süre | LEADER, kill feed, skor tablosu, ölüm ekranı (FLATLINED + geri sayım + loadout), maç sonu
- [x] Atmosfer: soğuk kapalı gökyüzü, mavimsi sis, prosedürel kirli beton dokusu (test range)
- [x] Ekran filtresi: grain, vignette, soğuk/yıkanmış renk, 5 bit renk + dither; Settings'te kapatma ve render ölçeği
- [x] Birinci şahıs: silahı tutan eldivenli kollar, aşağı bakınca ve kayarken görünen bacaklar (prosedürel)
- [ ] Can'ın oyunda değerlendirmesi
- [ ] HUD silah ikonları gerçek modellerden render (modeller gelince), menü arka planı AVM kamera turu (aşama 7/8)

## Bilinen sorunlar

- Bear ve Volcano ayrıntılı oynanmadı; gerçek iki bilgisayar testi henüz yok (sadece aynı PC'de iki pencere).
- Charge'ın host'taki çarpma penceresi istek gelince başlar ve host'un çizdiği (~100 ms geriden) konumu kullanır: charge'ın son ~100–150 ms'si hedeflere karşı denenmez; duvara erken çarpan charge'da pencere bitene kadar 1,3 m'ye giren yine stunlanır.
- Birinci şahıs kolları: el sadece yumruk pozunda (parmaklar silaha göre ayrı ayarlanmıyor), şarjör değiştirme / atış animasyonu yok; çift tabanca ve bazı silahlarda eller kısmen ekran dışında. Kollar bulutta OpenGL (Compatibility) ile görüntülendi, Mobile renderer'da ışık farklı olabilir.
- Steam sürümü gerçek Steam'le denenmedi. Bilinmeyenler: `SteamMultiplayerPeer`'in bağlanma sinyalleri ve peer id'leri bizim akışla uyumlu mu, unreliable paketler (hareket) Steam aktarımında akıcı mı. Steam lobisi herkese açık (App 480'de `sfb_go` etiketiyle filtrelenir; başka biri listeye düşmez ama lobi kimliğini bilen girebilir). Farklı sürümdeki oyuncular aynı lobiye girerse RPC hataları olur (sürüm kontrolü yok).
- Steam sürümünün `export_presets.cfg`'si yerel (git dışı); `build_steam.py` her çalıştığında kendi preset'ini yeniden yazar, diğerlerine dokunmaz.
- Elde bıçakla backstab host'ta lag compensation'lı pozla hesaplanır; kurbanın yönü 30 Hz senkronla gelen bakış yönü (hızlı dönen hedefte sınırda kararlar şaşabilir).
- PSX Weapon Pack ve PSX Revolver Pack'te lisans dosyası yok (ASSETS.md); kaynak/lisans Can'dan öğrenilecek.
- Silah modelleri (2026-10-02): Sketchfab'den 21 model oyunda (`assets/models/weapons/real/`); 7'si aynı gün Can'ın PSX paketleriyle değişti. Kalan yer tutucular: Claws (bıçak), Sticky Bomb ve launcher mermisi (frag modeli), mayın, Grapple, kalkan. Railgun'un dokusu yok (düz koyu metal). Roketatarın ön/arka yönü modelden tam anlaşılmıyor, oyunda bakılacak. Beretta modelinde sürgü geri çekili duruyor (modelin kendisi).
- Hız cezası ve shotgun'ın merkez yönü sahibinde seçilir, host gelen yönü izler (unscoped spread ile aynı model; hileli client sapmasız ateş edebilir).
- Hasar sayısı gerçekten düşen canı gösterir (kalan candan fazla vuruşta düşük sayı çıkar); kalkanın engellediği vuruşta marker/sayı yok.
- Adrenaline sahibinde host onayından önce başlar; host reddederse (stun, maç arası) 4 sn boyunca fazladan atışlar sessizce düşer.
- Yapışkan bomba oyuncuya yapışınca diğer client'larda kurbanın ~100 ms önünde görünebilir (host o oyuncunun anlık konumunu izliyor, client'lar oyuncuyu geriden çiziyor).
- Hız cezası dürbündeyken de geçerli (dürbünle yürürken Heavy/Marksman artık tam isabetli değil).
- Serbest hava kontrolü `standard.tres` ile tüm sınıflara geçerli (Wolf/Hawk/Bear da Quake tarzı air strafe yerine serbest yön değiştirme alıyor).
- Maç bitince lobiye dönülmez; eskisi gibi 10 sn sonra yeni maç başlar.
- Ölüm ekranındaki "öldürenin kalan canı" kill ödülünden önceki can.
- Aşama 6 notu: airdrop silahlarının `.tres`'inde `kill_ammo_reward = false` olmalı (varsayılan true).
- AVM blockout oynanmadı: akış, siper yoğunluğu ve görüş hatları sadece kâğıt üstünde (navmesh testi yürünebilirliği doğrular, oynanışı değil). Işık yok (ortam ışığı + güneş); iç mekân karanlık görünebilir (aşama 8: LightmapGI).
- Basamak çıkma: tek basamaktan inerken kenardan kısa bir düşüş olur (~0,1 sn, iniş çökmesi). Yavaş yürürken basamağa değince en az 0,15 m ileri atılır; eğilerek kaldırıma yürürken küçük bir sıçrama hissedilebilir.
- AVM'nin görünmez site duvarı mermi ve bombaları da durdurur (site dışında kimse yok); kanca da ona takılabilir (çit hattında, 40 m menzil içindeyse).
- `map_test` navmesh'i CSG'nin render mesh'inden çıkarır (Godot uyarısı: "had to parse RenderingServer meshes"); sadece testte, oyunda navmesh yok.
- Bear'ın yakın dövüş silahlarıyla Bear'a karşı TTK hedefin üstünde (1,5–2,4 sn); sadece hız cezası istendiği için hasarlara dokunulmadı.
- Decoy sadece görsel: vurulamaz, kurşun içinden geçer (GDD "hologram" diyor; istenirse hitbox eklenir).
- Bear'ın Claws'u hâlâ büyütülmüş bıçak; tekme görünmez (aşama 8).
- Cowboy: Musket ve Revolver Blender yer tutucusu (`build_placeholders.py -- . musket revolver`); karakter asker modeliyle aynı, şapka/palto yok. **Not (aşama 8): Smoke Break'te sigara içme animasyonu** (birinci şahıs elde sigara + duman, üçüncü şahısta ağza götürme). Şu an güç kullanınca görsel bir şey olmuyor, sadece HUD.
- Stun ve knockback client tarafında uygulanıyor; host sadece stunlu oyuncunun ateş/güç isteklerini reddediyor (hareketi değil).
- Shield hasar yönünü saldıranın konumundan hesaplıyor (bomba dahil), bu yüzden arkadan patlayan bomba önden sayılabilir.

- Silah modeli ve birinci şahıs kollar duvarlara girebiliyor (viewmodel ayrı render katmanı aşama 8/9'da).
- Birinci şahıs kollar/bacaklar kutu yer tutucu; silah sallanması ve şarjör animasyonu yok, eller silaha sabit. Bacaklar yan yürürken de ileri-geri adım atar.
- Dürbün katmanı ve ayarlar paneli 0×0 boyutta kalıyordu (dürbünde sadece zoom vardı): `set_anchors_and_offsets_preset` ile düzeldi. Ayarlarda listenin sonunda tekerlek oyuna dönüyordu: tekerlek artık fareyi yakalamaz.
- Aşama 6: Airdrop silah modelleri yer tutucu (Railgun = Heavy Rifle + mavi bobin, Minigun = LMG + namlu, Rocket = tüp). Minigun'un dönmesi başkalarına görünmüyor. Pickup alma host'un gördüğü konuma göre (~100 ms geriden). Speed pickup Adrenaline ile çarpılarak birleşir. Anons sesleri aşama 9.
- Minigun ısınması sadece sahibinde kontrol ediliyor (host ateş hızını kontrol ediyor ama ısınmayı değil; hileli client anında ateş edebilir, mermi takibi gibi bilinçli olarak ertelendi).
- Ekran filtresi HUD ve menüleri de etkiler (bilinçli: PS2 hissi); yazılar okunmazsa filtre ayarlardan kapatılır.
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

- 2026-10-02 (Can): Musket hasarı 95 → 75 (kafa 150), şarjör 1 → 3.
- 2026-10-02 (Can): AVM iç mekânı çok karanlıktı: her kata 5 × 4 tavan lambası (gölgesiz OmniLight, 1,5 enerji, 13 m menzil, soğuk floresan rengi), ortam ışığı 0,7 → 1,0 (`tools/maps/build_mall_blockout.py`, `LAMP_*`).

- 2026-10-02 (Can): Tabancanın tepmesi SMG ve LMG'den fazla geliyordu (mermi başına 0,9° vs ~0,45°). SMG ve LMG desenleri ~1,7× (mermi başına ~0,7–0,8°), tabanca 0,9 → 0,6°. Hawk Grapple menzili 40 → 28 m.
- 2026-10-02 (Can): Yeni sınıf **Cowboy** (GDD'de): Musket 95 (kafa 190), 1 mermi, 2,8 sn doldurma, dürbünsüz, `move_spread` 0,4; Revolver 45, 6 mermi; Smoke Break 18 sn bekleme, 6 sn, 5 can/sn, ateş hızı ×1,3, doldurma ×1,6. İlk tahmin; oynanınca ayarlanacak. GDD'deki "can yenilenmesi yok" kuralının tek istisnası Smoke Break.

- 2026-10-02 (Can): Bear çok zayıf. Can 175 → 200; Chainsaw hasar 7 → 11 (70 → 110 DPS), taşırken hız %75 → %85; Claws erişim 1,7 → 2,0 m; Sledgehammer erişim 2,3 → 2,6 m, aralık 1,1 → 0,95 sn; Charge bekleme 12 → 8 sn; Shield 12 → 10 sn. Can'la birlikte oynanıp tekrar bakılacak.
- 2026-10-02 (Can): Q bombaları ve fırlatma bıçağı "düzgün gitmiyor": artık sağ elden çıkıp nişangah noktasına gidiyor ve koşu hızını taşıyor (testte 10 m'ye nişanlı frag dururken 12,3 m'de, koşarken 17,4 m'de patladı; bıçak 15 m'de mankene isabet). Değer değişmedi, sadece fırlatma yolu.

- 2026-10-01 (Can, ilk test): Cheetah zor kontrol ediliyor, zıplarken akıyor, havada çok yön değişiyor. Serbest hava ivmesi 10 → 3 (`MovementDef.air_control_accel`, `standard.tres`, tüm sınıflar). Can: "daha iyi, gayet iyi".
- 2026-10-02 (Can): Fırlatma bıçağı küçük ve çok yaylı geliyordu: model ~1,6×, isabet yarıçapı 0,2 m (`projectile_radius`), hız 24 → 34 m/s, kaldırma 2 → 0,8, yerçekimi 14 → 7 (`throw_gravity`).
- 2026-10-01 (Can, ikinci tur): Dash 0,15 sn × 18 m/s → 0,25 sn × 22 m/s (2,7 → 5,5 m). Shotgun şarjörü 6 → 8. Grenade Launcher hasarı 95 → 81 (−%15). Mayın tetik yarıçapı 0,8 → 1,3 m, modeli ~1,7× büyüdü. Dürbünde hareket isabetsizliği: Heavy Rifle `move_spread` 3 → 6, Marksman 2 → 3,5 (CS gibi; dürbünde yürürken görüntü de bulanıklaşır).
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
| 2026-10-01 | görsel | İki PC testi geçti (aşama 2 bitti). Can'ın kararıyla görsel geçiş öne alındı: `Style` teması, taslağa göre ana menü / lobi / loadout / ayarlar / Esc / HUD / ölüm ekranı, soğuk atmosfer + kirli beton dokusu, PS2 ekran filtresi (ayarlardan kapanır, render ölçeği), birinci şahıs kollar ve bacaklar. `tests/ui_preview.tscn` ile ekran yakalama. Smoke 88/0, ağ testi 0 hata. |
| 2026-10-01 | görsel | Can'ın ikinci turu: dürbün maskesi/nişangahı görünmüyordu (boyut 0) → düzeldi + hareket ederken bulanıklık ve daha fazla isabetsizlik; ayarlarda tekerlek menüyü kapatıyordu → düzeldi; Dash uzadı, shotgun 8 mermi, GL −%15, mayın büyüdü; Test Range: güç bekleme süresi yok, sınırsız mermi (`data/match/test_range.tres`). Airdrop aşama 6'da. |
| 2026-10-01 | 6 | Aşama 6: pickup'lar (Health/Speed/Double Jump, parlama, geri sayım), airdrop (duyuru, hüzme, paraşüt, E ile açma), Railgun/Minigun/Rocket Launcher, 3. slot, ölünce düşen silah, Test Range 5 sn'de bir kasa. Smoke 112/0, ağ testi 0 hata. Can'ın testi bekliyor. |
| 2026-10-01 | 6 | Can'ın testi olumlu. Kasa katı oldu; dürbünde gecikmeli geri tepme inişi (görüş kendiliğinden aşağı kayma) düzeldi. |
| 2026-10-01 | 6 → 7 | Aşama 6 sonu bağımsız inceleme: 5 düzeltme (havada ölen taşıyıcının silahı zemine iner, Minigun sayacı, pickup'lar maç başında sıfırlanır, Double Jump bunny hop'u yemez, maç sonunda kasa açılmaz). **Aşama 6 kapandı.** |
| 2026-10-02 | 7 | Bıçak: büyük model, 0,2 m isabet yarıçapı, daha hızlı ve düz atış. Smoke 113/0. Yarın/bugün: aşama 7 (AVM) ve modeller. |
| 2026-10-02 | 7 | (iş bilgisayarı, Godot 4.7.2 headless, oynanmadı) Silah modeli adayları `ASSETS.md`'ye (Sketchfab, Falxxx PS1 serisi; söküm modeller arkadaş sürümünde serbest). Basamak çıkma + floor snap, merdiven = görsel basamak + rampa, harita listesi (`MapDef`), AVM blockout üreteci ve sahnesi, görünmez site duvarı. `movement_test` 45/0, `map_test` 143/0, smoke 113/0, ağ testi 0 hata. Çıkışta airdrop silahı düşer, geç katılmada Esc pause açar. Can'ın evde oynama testi bekliyor. |
| 2026-10-02 | 7 | Evde pull + doğrulama: import temiz, smoke 113/0, map 143/0, ağ testi (lobi + geç katılma) 0 hata. movement_test merdiven-iniş kontrolü kaldırımın kenarından düşmeyi de sayıyordu (bilinen ~0,1 sn düşüş, tek basamak testinde ayrıca var); hedef kaldırımın üstüne çekildi, 45/0. Oyun Can'ın denemesi için açıldı. |
| 2026-10-02 | 7 | Can'ın isteği: Bear güçlendirildi (yukarıda), fırlatmalar elden + nişangaha + koşu hızı taşıyor, Test Range'de her an sınıf değişimi ve Esc'te kalıcı "UNLIMITED ABILITIES" anahtarı (varsayılan kapalı). Smoke 113/0, movement 45/0, map 143/0, ağ testi 0 hata; fırlatma/sınıf değişimi ayrıca headless doğrulandı. |
| 2026-10-02 | 7 | Can'ın isteği: SMG/LMG tepmesi arttı, tabanca azaldı, Grapple 28 m. Yeni sınıf Cowboy (Musket, Revolver, Smoke Break: can yenileme + ateş/doldurma hızı; buff sistemine doldurma çarpanı ve host'ta can yenileme eklendi), yer tutucu modeller, GDD'ye eklendi, sigara animasyonu aşama 8 notu. Smoke 125/0 (Smoke Break testi dahil), movement 45/0, map 143/0, ağ testi 0 hata. Silah modelleri İndirilenler'de (ASSETS.md). |
| 2026-10-02 | 7 | Musket 75 hasar / 3 mermi. AVM'ye tavan lambaları (40 OmniLight) + ortam ışığı. Hata: Cheetah'ın hızında kapsülün yuvarlak altı 0,6 m'lik bloğun kenarına oturup iki basamakta üstüne çıkıyordu (movement_test oyuncunun kayıtlı sınıfıyla koştuğu için ortaya çıktı); basamak üstü artık ayaktan en fazla step_height yukarıda olabilir. movement_test her zaman Wolf ile başlar, blok kontrolü her sınıf için (50/0). Smoke 125/0, map 143/0, ağ testi 0 hata. |
| 2026-10-02 | 7/8 | Silah modelleri: 21 Sketchfab modeli `process_weapon_models.py` ile işlendi (yön, gerçek boy, el noktası, poligon ≤ 2500, doku ≤ 512, renk tonu) ve `apply_weapon_models.py` ile birinci/üçüncü şahıs sahnelerine bağlandı; Marksman Rifle kendi sahnesine (SVD) kavuştu. Krediler ASSETS.md'de (PSX Revolver Sketchfab Standard lisanslı). `private_assets/.gdignore`. Testler 125/0, 50/0, 143/0, ağ 0 hata. |
| 2026-10-02 | 7/8 | Birinci şahıs silahlar %20 büyüdü (`VIEW_SCALE`), çift tabanca ters duruyordu (çevrildi). Arkadaşlara taşınabilir sürüm: `builds/SFB-GO_v0.7.zip` (Godot exe + proje + import önbelleği + SFB-GO.bat; export şablonları kurulu olmadığı için gerçek export yerine). Smoke 125/0. |
| 2026-10-02 | 7/8 | (bulut, Godot 4.7.2 headless + pip bpy) Steam sürümü: `SteamLink` autoload (GodotSteam 4.22.1, App 480: lobi kur/bul/katıl, davet, join_requested), `Net.host_with_peer` / `join_with_peer`, Steam'de ping ile RTT, ana menüde STEAM paneli, lobide INVITE, `tools/steam/build_steam.py` (Windows + Linux export, export edilen Linux sürümü Steam'siz açılıyor). Bıçak 3. slot + backstab (999), airdrop 4. slot. Can'ın PSX paketlerinden 7 silah modeli. Smoke 137/0, movement 50/0, map 143/0, ağ testi lobi 30 + 26, geç katılma 29 + 29. Steam gerçek istemciyle denenmedi. |
| 2026-10-02 | 7/8 | (bulut) Rigli PSX kollar + `ArmsIK` (iki kemikli IK, yumruk tutuşu, bıçakta bıçak pozu), yeni harita Ice Yard (`build_iceworld.py`), tepme +%15, test kuralı (sadece ilgili testler), `ui_preview` range seçenekleri (sınıf/slot/harita/kamera). Smoke 137/0, map 202/0; movement ve ağ testi koşulmadı (değişiklik yok). |
| 2026-10-02 | 7/8 | Evde `claude/epic-pascal-u74jyd` dalı çekildi (fast-forward, 6 commit) + doğrulama: import temiz, smoke 137/0, movement 50/0, map 202/0, ağ testi lobi 30 + 26, geç katılma 29 + 29. GodotSteam eklentisi olmadan çalıştırıldı (Steam paneli devre dışı). Oyun Can'ın denemesi için açıldı. |
| 2026-10-02 | 7/8 | (evde, Godot 4.7.2 + Blender 5.2) Can'ın listesi: silah tutuşları (`RightHand`/`LeftHand` dönüşlü işaretler, `arms_twist`, omuzlar aşağı, tabanca/revolver tek el, `apply_view_grips.py`), revolver silindiri, bıçak/balyoz savurma anahtarları, fırlatma bıçağı animasyonu, sniper (nişangah yok, `scope_in_time`, kalça dağılması), tepme ×1,2, Railgun 4, Minigun dağılma, bıçakta +%15 hız, eğimde slide + slide dağılması, Ice Yard %20 büyük ve karanlık. `ui_preview`'e `--primary --special --hud=off --fire`. Smoke 143/0, movement 54/0, map 202/0, ağ testi lobi 30 + 26, geç katılma 29 + 29. |
| 2026-10-03 | 7/8 | (evde) Yeni FPS elleri (her önkol tutuş noktasına oturur, IK yok; `apply_view_grips.py` yeni ellere göre, kundakta −25° dönüş, bıçakta `BLADE_TURN`), gölge tarafı için wrap + backlight. Tepme kamerayı kaydırmıyor, silah modeli vuruyor (`CameraFeelDef` recoil grubu). Oyuncu gövdesi PSX Base Male. Eski `fp_arms`, `soldier.glb`, `arms_ik.gd` silindi. Smoke 143/0, movement 54/0, map 202/0, ağ testi 30 + 26, 29 + 29. |
