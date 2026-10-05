# SFB:GO – Architecture

Kod yapısının ve kuralların referansı. Tasarım için `GDD.md`, durum için `PROGRESS.md`.

## Temel kararlar

| Konu | Karar |
| --- | --- |
| Motor | Godot 4.4+ (en son stable 4.x) |
| Dil | GDScript, **statik tipli** (`var hp: int`, `func f() -> void`) |
| Renderer | Mobile (Vulkan) |
| Fizik | Jolt Physics (dahili), physics tick 60 Hz |
| Ağ | `ENetMultiplayerPeer` (IP) veya `SteamMultiplayerPeer` (GodotSteam, App ID 480), listen server, host = peer 1 |
| Otorite | Server-authoritative oyun durumu, client-side hareket |
| Veri | Sınıf/silah/güç değerleri `Resource` (`.tres`) dosyalarında |

## Klasör yapısı

```
sfb-go/
├── project.godot
├── CLAUDE.md
├── .mcp.json                # Godot MCP ayarı
├── docs/                    # GDD, ARCHITECTURE, PROGRESS, ASSETS (.gdignore: Godot import etmez)
├── addons/                  # Godot eklentileri (şimdilik boş)
├── autoload/                # Global singleton'lar
│   ├── events.gd            # Sinyal otobüsü
│   ├── net.gd               # Bağlantı, oyuncu kaydı
│   ├── match.gd             # Maç durumu, skor, spawn (sadece host karar verir)
│   ├── settings.gd          # Kullanıcı ayarları (user://settings.cfg), `changed` sinyali
│   ├── style.gd             # Görünüm: renk paleti, sistem fontları, Theme (varsayılan temaya birleştirilir), ScreenFx
│   └── steam_link.gd        # Steam lobileri + SteamMultiplayerPeer (sadece GodotSteam'li sürümde etkin)
├── data/
│   ├── classes/             # ClassDef .tres (wolf, hawk, cheetah, volcano, cowboy, hound, ghost, trickster, phantom; bear dosyası duruyor) + roster.tres
│   ├── camera/              # CameraFeelDef .tres (default.tres: FOV kayması, head bob, iniş, slide, sarsıntı)
│   ├── maps/                # MapDef .tres (mall, test_range) + map_list.tres (lobi sırası, ilki varsayılan)
│   ├── movement/            # MovementDef .tres (standard.tres: ivme, zıplama, bhop, slide, coyote, basamak)
│   ├── weapons/             # WeaponDef .tres
│   └── abilities/           # AbilityDef .tres
├── scripts/
│   ├── defs/                # class_def.gd, class_roster.gd, weapon_def.gd, ability_def.gd, grenade_def.gd, movement_def.gd, match_def.gd, camera_feel_def.gd, map_def.gd, map_list.gd
│   ├── game/                # game.gd (maç sahnesi: harita, spawn, respawn), lag_compensator.gd
│   ├── player/              # player.gd + bileşenler (player_net_sync, player_requests, player_status, player_effects), movement.gd, camera_feel.gd, first_person_legs.gd, first_person_arms.gd, player_input.gd, player_command.gd, hitbox.gd, loadout.gd, soldier_rig.gd + soldier_animations.gd + soldier_mesh.gd + spine_aim_modifier.gd (üçüncü şahıs animasyonlu gövde), corpse.gd
│   ├── maps/                # target_dummy.gd vb. harita scriptleri
│   ├── weapons/             # weapon.gd (taban), hitscan_weapon.gd, shotgun_weapon.gd, dual_pistols_weapon.gd, launcher_weapon.gd, melee_weapon.gd, throwing_knife_weapon.gd
│   ├── abilities/           # ability.gd (taban), grenade_ability.gd, grenade.gd (bomba/mermi), grapple, decoy, shield, charge, dash, adrenaline
│   ├── pickups/             # pickup.gd, airdrop_manager.gd, airdrop_crate.gd, weapon_drop.gd, airdrop_weapons.gd
│   └── ui/                  # hud.gd (+ hud_bar.gd, hud_weapon_icon.gd), crosshair.gd, damage_number.gd, scoreboard.gd, kill_feed.gd, main_menu.gd, lobby.gd, loadout_menu.gd, settings_panel.gd, screen_fx.gd
├── scenes/
│   ├── main.tscn            # Giriş noktası: ana menü (isim, Host, Join, Last host, Test Range, Settings)
│   ├── lobby.tscn           # Lobi (UI kodla kurulur: scripts/ui/lobby.gd)
│   ├── game.tscn            # Maç sahnesi: Map + HUD + Players + PlayerSpawner
│   ├── player/player.tscn
│   ├── weapons/             # Silah başına sahne (görsel + script)
│   ├── projectiles/
│   ├── pickups/
│   ├── ui/
│   └── maps/
│       ├── test_range.tscn  # Test haritası + hedef mankenleri
│       ├── mall/mall.tscn   # AVM blockout (tools/maps/build_mall_blockout.py üretir)
│       └── ice_yard/ice_yard.tscn # Ice Yard (fy_iceworld tarzı, tools/maps/build_iceworld.py üretir)
├── tests/                   # Headless otomatik testler (komutlar dosyaların başında)
│   ├── smoke_test.tscn      # Tek process: her sınıf/silah/güç mankene, kill ödülü, UI panelleri
│   ├── movement_test.tscn   # Gerçek Movement: basamaklar, merdivenler, AVM rampaları, çatıdan atlama
│   ├── map_test.tscn        # Her harita: spawn/pickup/airdrop noktaları, navmesh ile ulaşılabilirlik, yüksek katlara 2+ yol
│   ├── net_test.tscn        # İki process, gerçek ENet: --role=host / --role=client (+ --late)
│   ├── anim_preview.tscn    # Test Range'de sahte uzak oyuncular: koşu, yan adım, geri + yukarı/aşağı bakış, çömelme, zıplama, ateş, ölüm (--focus=, --shots=)
│   └── ui_preview.tscn      # Sahte veriyle tek ekran (--screen=lobby|loadout|range|death|scoreboard|down|walk|slide); range: --class --slot --map --at --yaw --pitch; --write-movie ile kare yakalanır (bulutta: xvfb-run + --rendering-driver opengl3)
├── tools/                   # .gdignore; oyun dışı araçlar
│   ├── blender/build_placeholders.py   # Yer tutucu modelleri üretir (Blender headless → .glb)
│   ├── blender/process_weapon_models.py # private_assets/weapons/*.glb → assets/models/weapons/real/<id>.glb (yön, ölçek, el noktası, poligon, doku 512, muzzles.json)
│   ├── apply_weapon_models.py          # real/ modelleri silah sahnelerine ve WeaponDef'lere bağlar (ölçek, namlu, üçüncü şahıs)
│   ├── steam/build_steam.py            # Steam sürümü: GodotSteam şablonlarını indirir, export, steam_api + steam_appid.txt, zip
│   └── maps/build_mall_blockout.py     # AVM blockout sahnesini üretir (Python; --preview ile kat PNG'leri)
└── assets/
    ├── models/              # characters/fp_hands (birinci şahıs eller), characters/psx_man (eski statik gövde, sahnede yok), characters/mixamo/*.fbx (Mixamo, mesh'siz iskelet + animasyon), weapons/*.glb yer tutucular, weapons/real/*.glb indirilen modeller (Blender'da +Y ileri = Godot -Z)
    ├── textures/
    ├── audio/
    └── shaders/             # ps2_screen.gdshader + ps2_screen.tres (ekran filtresi değerleri)
```

## Autoload'lar

| İsim | Görev | Kim yazar |
| --- | --- | --- |
| `Events` | Global sinyaller (`player_killed`, `match_ended`, `airdrop_incoming`...). Sistemler birbirini doğrudan çağırmaz, buradan haberleşir. | Herkes emit eder |
| `Net` | Host/join, peer listesi, oyuncu isimleri, bağlantı kopması | Host + client |
| `Match` | Skor, kill hedefi, süre, spawn seçimi, pickup/airdrop zamanlayıcıları | **Sadece host** değiştirir, client'lara RPC ile yayar |
| `Settings` | İsim, son host, FOV, hassasiyet, crosshair + hit marker, kamera efekti ölçekleri, grafik (ekran filtresi, render ölçeği). `SettingsPanel` ana menü ve Esc menüsünden açılır. | Yerel |
| `SteamLink` | Steam (GodotSteam, App ID 480): başlatma, lobi kur / ara / katıl, davet, `join_requested`. Steam API'si `Engine.get_singleton("Steam")` + `call()` ile çağrılır, böylece GodotSteam'siz editörde de derlenir (`available = false`). Lobi kurulunca / katılınca `SteamMultiplayerPeer` yaratıp `Net.host_with_peer` / `Net.join_with_peer`'e verir. | Yerel |
| `Style` | UI görünümü (GDD "Görsel referans"): palet sabitleri (`Style.PANEL`, `Style.TEXT`...), sistem fontları (Arimo/Arial, Cousine/Courier New; dosya gömülmez), Theme + varyasyonlar (`TitleLabel`, `HeaderLabel`, `MonoLabel`, `DimLabel`, `HudLabel`, `HudSmallLabel`, `RowButton`, `FrameButton`, `PrimaryButton`, `HeaderPanel`, `InsetPanel`). Theme motorun varsayılan temasına birleştirilir (CanvasLayer altındaki HUD dahil her Control alır). Root'a `ScreenFx` ekler. | Yerel |

## Ağ modeli

**Prensip:** Her oyuncu kendi hareketini kendisi hesaplar (akıcı his için), ama **hasar, ölüm, skor, pickup, airdrop ve spawn kararlarını sadece host verir.**

### Otorite

- Her `Player` node'unun multiplayer authority'si kendi peer id'si → hareket ve input o client'ta.
- `health`, `kills`, `deaths`, `is_alive`, aktif buff'lar → host'ta tutulur, client'lara yayılır. Client bunları asla kendi değiştirmez.
- Oyuncular `MultiplayerSpawner` ile spawn edilir (host spawn eder, herkeste çoğalır).

### Oturum akışı (aşama 2)

- `scenes/game.tscn` (`/root/Game`, `scripts/game/game.gd`): maç sahnesi. `Net.map_path` haritasını `Map` adıyla yükler (her peer'da aynı yol), `HUD`, `Players` ve `PlayerSpawner` içerir. Haritalar sadece geometri + `SpawnPoints` (Marker3D) + harita nesneleri (mankenler).
- **Host:** `Net.host_game()` → ENet server (port 7777) → `lobby.tscn` (komut satırı `--host`: `use_lobby = false`, doğrudan `game.tscn`). **Client:** `Net.join_game()` → bağlanınca adres `Settings.last_host`'a kaydedilir, `_request_register(name)` → host lobi açıksa `_welcome_lobby()` (client `lobby.tscn` yükler), maç sürüyorsa `_welcome(map_path)` → client `game.tscn` yükler → `Game._request_spawn()`.
- **Lobi (`Net.in_lobby`):** oyuncu listesi, isim, hazır durumu (`_request_ready` → host `ready_peers` → `_on_lobby_synced` herkese), boş yüz yeri (aşama 8). Host kill/dakika/harita seçer (`server_set_lobby_settings`, `Net.MAP_LIST` = `data/maps/map_list.tres`, indeks) ve Start der: `server_start_match` → `Match.configure` → host `game.tscn` yükler, kendi `Game`'i hazır olunca lobideki her peer'a mevcut `_welcome`'ı gönderir. Yani lobiden gelenler geç katılanla aynı yoldan girer; `Game` ve `Match` lobiden habersizdir.
- Host, sahnesi yüklenmiş peer'ları `Net.ingame_peers`'te tutar. Oyun RPC'leri sadece bunlara gider (`Net.broadcast(node, method, args)`), yüklenmekte olan client "node not found" almaz. Hareket yayını (`Net.state_peers`) katılımdan 0,5 sn sonra başlar; unreliable paketler reliable spawn paketlerini geçmesin diye. Geç katılana mankenlerin canı `sync_to_peer` ile gönderilir.
- Maç kuralları `Match.rules` (`MatchDef`, `data/match/default.tres`): kill hedefi, süre, respawn, spawn koruması, sonuç ekranı süresi. Host lobide kill/dakika seçer (`Match.configure`). Test Range `Match.configure_test_range()` → `data/match/test_range.tres`: limit yok, `infinite_ammo` (Weapon şarjör düşmez), `loadout_swap_anytime` (loadout seçimi her an anında uygulanır). Güç bekleme süresi Esc panelindeki "UNLIMITED ABILITIES" anahtarına bağlı (`Settings.practice_unlimited_abilities`, kaydedilir, varsayılan kapalı; açıkken `rules.ability_cooldowns = false`, `Ability.get_cooldown()` 0).

### Maç döngüsü (aşama 3, `autoload/match.gd`)

- Durum host'ta: `kills`, `deaths`, `state` (PLAYING/ENDED), `time_left`. Her değişiklik `Net.broadcast` ile; katılana `_sync_full` snapshot. Süre her peer'da yerelde geri sayar.
- Akış: `Player._die` → `died(killer, weapon, headshot)` → `Game._on_player_died` (mesafe hesaplar) → `Match.server_register_kill` → `_on_kill` herkese → `Events.kill_registered` (kill feed) + `scores_changed` (skor tablosu, taç).
- Bitiş: kill hedefi veya süre → `_on_match_ended(winner, awards)` → `end_screen_time` (10 sn) sonra `_on_match_started` → `Events.match_started` → host herkesi yeniden doğurur. ENDED'da hasar yok.
- Ödüller (host hesaplar): Most Deaths, Longest Headshot, Most Self-Kills, Most Knife Kills (sadece `WeaponDef.counts_as_knife` silahlar: V bıçağı ve fırlatma bıçakları; `take_hit`'in `is_melee` argümanı bu bayrak).
- Doğma noktası: canlı düşmanlara en yakın mesafesi en büyük olan nokta (`Game._pick_spawn_point`).
- Spawn koruması: `Player.is_protected` (host'ta, StateSync ile yayılır), `rules.spawn_protection` sn veya ateş edince biter; korumalıyken hasar yok, başkalarına model yanıp söner.
- Taç: `Match.get_leader()` (tek başına lider, ≥1 kill) → `Player.set_leader`; kendinde çizilmez.
- Ölüm ekranı: öldüren, silah ve öldürenin kalan canı (`_announce_death(killer_id, weapon_name, killer_health)`).
- Spawn: `spawner.spawn_function` + `{id, position, yaw}` verisi. `Player.StateSync` (MultiplayerSynchronizer, authority 1, `public_visibility = false`) spawn görünürlüğünü belirler: host yeni peer için `set_visibility_for()` açınca mevcut oyuncular o peer'da da doğar (geç katılma).
- **Test Range** = `OfflineMultiplayerPeer` ile aynı kod: biz peer 1'iz, `is_server()` true.
- Host çıkarsa client'lar `server_disconnected` → ana menü ("Host left the game").
- **Steam (`SteamLink`):** `host_lobby` → `createLobby` (public, `sfb_go = 1` etiketi; App 480'i herkes paylaşıyor) → `lobby_created` → `SteamMultiplayerPeer.create_host(0)` → `Net.host_with_peer` (lobi ekranı, ENet ile aynı yol). Client: `find_lobbies` (etiket filtresi, dünya geneli) → menüde liste; `join_lobby`, Steam daveti / arkadaş listesinde "Join Game" (`join_requested`, maçtaysa önce `Net.leave`) → `lobby_joined` → `create_client(lobi sahibi, 0)` → `Net.join_with_peer`. `Net.leave` lobiden de çıkar. Lobi ekranında INVITE = Steam davet penceresi. Steam başlatılmadan `SteamMultiplayerPeer` yaratılmaz (GodotSteam çöküyor).
- **RTT:** `Net.get_rtt(peer)`: ENet'te ENet istatistiği; diğer aktarımlarda (Steam) host her saniye `_ping` → `_pong` ile ölçer (yumuşatılmış). Lag compensation bunu kullanır.
- **Steam sürümü (`tools/steam/build_steam.py`):** GodotSteam 4.22.1'in Godot 4.7.2 şablonları (`private_assets/godotsteam/`, git dışı) özel şablon olarak `export_presets.cfg`'e "Windows Steam" / "Linux Steam" preset'i yazılır (dosya yerel, diğer preset'lere dokunulmaz), export + `steam_api64.dll` / `libsteam_api.so` + `steam_appid.txt` (480) → `builds/SFB-GO_steam_<platform>.zip`. Düz Godot editöründe Steam yok; menü "Steam needs the Steam build" der.
- Komut satırı (test için): `-- --name=X --host` / `-- --join=IP`.

### Senkronizasyon

| Veri | Yöntem | Sıklık |
| --- | --- | --- |
| Oyuncu pozisyonu, bakış yönü, crouch, `life` | Sahibi `_submit_state` → host `_relay_state` → diğerleri `_receive_state`; `unreliable_ordered` RPC, sahibin saat damgasıyla | 30 Hz |
| Diğer oyuncuların görüntüsü | Snapshot tamponu, ~100 ms geriden interpolasyon (`Player._interpolate_remote`) | Her frame |
| Ateş etme | Sahibi `_request_fire(origin, dir, slot)` → host doğrular (hayatta mı, ateş hızı, origin ≤ 3 m sapma) → `server_fire` | Olay bazlı, reliable |
| `health`, `is_alive`, `is_protected`, `loadout`, `scope_glint`, `shield_up`, `held_slot`, `powerups`, `special_ammo`, `special_weapon` | `StateSync` (ON_CHANGE, spawn'da da gönderilir; geç katılan da alır). Parlama ve elindeki silah sahibinin isteğiyle (`Requests._request_equip`, `Effects._request_scope`) host'ta değişir | Değişince |
| Ölüm, yeniden doğma, hit onayı, uzak tracer | Host → `Net.broadcast` (`_announce_death`, `_respawn_at`, `_show_shot`, shotgun için `_on_pellets_fired`) / `confirm_hit(zone, killed, amount, point)` sadece atana (hit marker + hasar sayısı) / `_on_hurt(amount)` sadece vurulanın sahibine (kamera sarsıntısı) | Olay bazlı |

- `life` sayacı her doğuşta artar; önceki hayattan geç gelen state paketleri atılır.
- Host'tan gelmesi gereken RPC'ler `any_peer` + `_sender_is_host()` kontrolü kullanır (node authority'si sahibinde olduğu için `authority` modu kullanılamaz).
- Ölüm/doğma (aşama 2): host `take_hit` → can 0 → `_die` → `Game` `Match.respawn_delay` (3 sn) sonra rastgele spawn noktasında `server_respawn`. Haritadan düşme: sahibi `_request_fall_death` ister, host karar verir.
| Maç durumu | Host → herkese (katılana tam snapshot) | Olay bazlı + katılışta |

### Vuruş tespiti (hitscan)

1. Client ateş eder: anında yerel efekt (namlu ateşi, ses, mermi izi). Hasar göstergesi **beklenir**.
2. Client host'a `request_fire` gönderir.
3. Host, atış zamanına göre diğer oyuncuların hitbox'larını geri sarar (lag compensation), raycast yapar, hasarı uygular.
4. Host sonucu yayar → hit marker, hasar, kill feed.

**Lag compensation (`scripts/game/lag_compensator.gd`, Game'in çocuğu):** Host her physics tick'te her oyuncunun pozisyon/yaw/crouch'unu 1 sn'lik geçmişe yazar. `_request_fire` → `fire_rewound`: diğer canlı oyuncular atanın gördüğü ana geri sarılır, `server_fire` yapılır, geri konur.
- Geri sarma = atanın RTT'si (ENet istatistiği). Host'un kendi oyuncusu host'ta canlı çizildiği için ona + `INTERP_DELAY` eklenir. Üst sınır 0,4 sn.
- Transform bildirimleri ertelendiği için `Player.set_hit_pose` hitbox'ları `PhysicsServer3D.area_set_transform` ile anında fizik sunucusuna yazar.
- Testte doğrulandı: 6 m/s koşan hedefe geri sarmayla 2 kill, geri sarmasız 25 sn'de tek isabet.

**Hile koruması:** Arkadaş arası oyun, ağır anti-cheat yok. Host sadece bariz tutarsızlıkları reddeder:
- **Aşırı hız:** `_is_plausible_move` host saatinde token bucket (bhop tavanı × 1,5, 1 sn tampon). Işınlanan paket atılır; hileci herkeste yerinde donar, atışları origin kontrolüne takılır. Her doğuşta sıfırlanır.
- **Ateş hızı:** Silah slotu başına bütçe (`get_average_shot_interval() × 0,95`, 0,25 sn birikme payı; hızlı silah değiştirmede diğer silahın aralığı beklenmez): ağ dalgalanmasında toplu gelen atışlar kaybolmaz, sürekli fazla hız reddedilir. Seri silahta tetik aralığı seriye, çift tabancada ikiye bölünür; Adrenaline aktifken host kendi saatindeki çarpanla böler.
- Host'un reddettiği fırlatma bıçağı sahibine geri verilir (bıçak sahibinde düşülür, sadece host geri verir).
- **Hayat sayacı:** host sadece kendi `life` değerindeki hareket paketlerini kabul eder; client sayacı ileri itemez.
- **Hız:** token bucket, sınıf hızı × host'taki Adrenaline hız çarpanı × bhop tavanı × 1,5. Dash (18 m/s × 0,15 sn ≈ 2,7 m) bu 1 sn'lik bütçeye sığar.
- **Ölüyken ateş**, geçersiz slot, origin'i bilinen gözden 3 m'den uzak atış reddedilir.
- Host mermi/şarjör takibi yapmaz (bilinçli; arkadaş arası).

### Pickup'lar ve airdrop (aşama 6)

- **Pickup** (`scripts/pickups/pickup.gd`, haritada `Pickups/...`, `PickupDef`): host her tick yakındaki canlı oyuncuya bakar (Health sadece canı eksiğe), `PlayerStatus.server_take_pickup` → Health anında; Speed/Double Jump host saatinde + sahibine `_receive_pickup`. `Net.broadcast(_set_state)` ile herkes ikon/hologram; geç katılana `sync_to_peer`. `Player.powerups` bit maskesi → `Effects.show_powerups` ışık.
- **Airdrop silahı:** `Player.SPECIAL_SLOT` (3, tuş 4). Host `give_special_weapon(index, ammo)` → `special_ammo`, `special_weapon` StateSync → her peer `_apply_special` (silahı ekler/çıkarır; sahibi eline alır). Ateşte host `server_use_special_round` (mermi biter → kaldırılır). `_die`'da `AirdropManager.server_drop_weapon`. `WeaponDef.airdrop / carry_speed_mult / pierce_walls / spin_up_time`; `GrenadeDef.knockback` (patlama itmesi, `status.server_knockback`).
- **AirdropManager** (`Game/Airdrops`, kodla eklenir): host zamanlayıcı (`MatchDef` airdrop alanları) → `_spawn_crate` herkese (kasa iniş zamanı her peer'da yerel), `_remove_crate`, `_spawn_drop` / `_remove_drop`. Açma: sahibi `tick_local(player, cmd.interact)` → `_request_open` / `_request_cancel`; host `_update_openers` (mesafe, canlı, silahsız, `Player.last_hurt_time` başlangıçtan önce) → süre dolunca rastgele silah; iptalde `_open_cancelled` sahibine. Geç katılana `sync_to_peer` (kasalar kalan düşüş süresiyle, yerdeki silahlar).

### Fiziksel mermiler (bomba, roket, bıçak)

Host spawn eder ve simüle eder, pozisyonları client'lara yayılır. Atan client kendi ekranında hemen görsel bir kopya gösterir, host'unki gelince ona geçer.

Güdümlü roket: `WeaponDef.guidable` silahta sağ tık lazeri açar/kapatır (sahip `PlayerRequests.send_guided` → host `Player.rocket_guided`). `GrenadeDef.guided_turn_rate > 0` olan roketi host her fizik adımında, atan canlıysa, güdümlü silah elindeyse ve lazer açıksa, bakış ışınının çarptığı noktaya sınırlı hızla döndürür (`Grenade._steer`). Lazer noktası sadece sahipte, görsel.

### Ses (`scripts/game/sfx.gd`)

`Sfx` statik yardımcı: konumlu tek seferlik `AudioStreamPlayer3D` (silah, patlama, adım, iniş, bıçak savurma; `panning_strength` 1 = tam sağ/sol, Doppler kapalı) ve UI sesleri (hit, kill). Tamamen kozmetik, her eşte yerel çalar; uzak oyuncunun silah sesi `_show_shot` / `_on_pellets_fired` ile gelir. Silah sesi `WeaponDef` istatistiklerinden seçilir (`Sfx.shot_stream`, kayıtlı seslerde 4 çeşitten rastgele). Kayıtlı klipler ("FREE FPS SFX Pack": adım ×8, iniş, pompalı + pompa, sniper/ağır, roket, patlama, dürbün, grapple, uyarı) `tools/convert_sfx_pack.sh` ile mono'ya çevrilir; tüfek, hafif silah, railgun, hit, kill, savurma `tools/gen_sfx.py` ile üretilir. Pompa sesi pompalının reload'unda (sahibi + `_show_action` ile diğerleri), dürbün sesi dürbün açılınca (sadece sahibi), uyarı airdrop gelirken, grapple atış + kanca `_show_grapple`'da; ses seviyesi `Settings.sfx_volume`. Headless'ta çalmaz. **Adımlar (CS gibi):** topuk + taban "tık tık"ı, ~32 m'ye kadar duyulur (`STEP_MAX_DISTANCE`), sesin geldiği yönden; yavaş yürüme/çömelme sessiz. İniş (`Sfx.land`) iki ayağın birden basması, patlama değil; uzak oyuncuların inişi de duyulur (`SoldierRig.grounded` havadan yere geçişi).

## Veri sistemi

Tüm denge değerleri koddan ayrı, `.tres` dosyalarında. Değer değiştirmek için kod açılmaz.

```gdscript
# scripts/defs/class_def.gd
class_name ClassDef extends Resource
@export var id: StringName
@export var display_name: String
@export var max_health: int = 100
@export var move_speed: float = 6.0
@export var primary_weapons: Array[WeaponDef]
@export var secondary_weapon: WeaponDef
@export var abilities: Array[AbilityDef]
@export var quick_melee: WeaponDef
```

```gdscript
# scripts/defs/weapon_def.gd
class_name WeaponDef extends Resource
enum FireType { HITSCAN, PROJECTILE, MELEE, THROWN }
@export var id: StringName
@export var display_name: String
@export var fire_type: FireType
@export var damage: float
@export var headshot_mult: float = 2.0
@export var leg_mult: float = 0.75
@export var fire_interval: float        # saniye
@export var magazine_size: int
@export var reload_time: float
@export var recoil_pattern: PackedVector2Array
@export var move_speed_mult: float = 1.0
@export var scene: PackedScene          # görsel + davranış
```

`AbilityDef` benzer: `id`, `display_name`, `cooldown`, `duration`, `scene` (Ability node'u). `GrenadeDef extends AbilityDef`: `kind` (FRAG/FLASH), `projectile`, `throw_speed`, `throw_lift`, `fuse_time`, `radius`, `damage`, `flash_duration`.

`WeaponDef` ayrıca: `burst_count` / `burst_interval` (seri atış, tık başına), `get_average_shot_interval()` (host hız kontrolü), `dual_wield` (çift tabanca), `move_spread` / `move_spread_ref_speed` / `move_spread_exponent` (kademeli hız cezası: koni = move_spread × (hız / ref)^üs; eşik yok), `pellet_pattern` + `falloff_start` / `falloff_end` / `falloff_min_mult` (shotgun), `grenade` (PROJECTILE silahın attığı `GrenadeDef`). Yakın dövüş de bir `WeaponDef` (`fire_type = MELEE`, `max_range` = erişim, `fire_interval` = bekleme).

`AbilityDef` ek alanları: `exit_speed` (Dash), `speed_mult` / `fire_rate_mult` (Adrenaline). `GrenadeDef` davranış alanları (varsayılanları eski frag/flash davranışı): `explode_on_impact` (GL mermisi), `sticky` (duvara/oyuncuya yapışır), `trigger_radius` + `arm_time` (mayın), `explode_on_fuse` (false = süre bitince sessizce kaybolur), `max_per_thrower` (oyuncu başına aktif sınır; eskisi silinir).

### Loadout (aşama 4)

- `data/classes/roster.tres` (`ClassRoster`): oynanabilir sınıfların sırası. `Loadout.roster()` ile ilk kullanımda yüklenir; `preload` edilmez, çünkü roster tüm silah/güç sahnelerini çeker ve bunların scriptleri (Game, LoadoutMenu) roster'ı okur → derleme döngüsü. Loadout = `PackedInt32Array [sınıf, birincil silah, güç]` roster indeksleri (`scripts/player/loadout.gd`: doğrulama, Settings'e kayıt, açıklama).
- `Player.loadout` StateSync ile host'tan herkese yayılır (spawn'da da). Setter `_apply_loadout()` çağırır: `class_def`, hareket, silahlar (birincil + ikincil), bıçak (`MeleeWeapon`), `Ability` node'u yeniden kurulur. Her peer aynısını kurar: host hasar için, sahibi kullanım için, diğerleri görüntü için.
- Seçim akışı: sahibi `request_loadout(code)` → host `_request_loadout` doğrular → doğuştan sonraki `rules.loadout_swap_window` (3 sn) içindeyse anında uygular + can doldurur, değilse `_pending_loadout` olarak saklar ve `server_respawn`'da uygular. İlk doğuşta client kendi kayıtlı seçimini `_request_spawn(loadout)` ile gönderir.
- Son seçim `Settings` üzerinden `user://settings.cfg`'e kaydedilir (isim, loadout, FOV, hassasiyet, crosshair).

### Yakın dövüş ve güçler

- **Silah slotları:** 0 birincil, 1 ikincil, 2 = `Player.KNIFE_SLOT` (tuş 3, `ClassDef.knife`, her sınıfta), 3 = `Player.SPECIAL_SLOT` (tuş 4, airdrop silahı). Elde bıçak = `MeleeWeapon` silah gibi (`Weapon.tick` → `send_fire` → host `server_fire`). **Backstab:** `WeaponDef.backstab_damage` (bıçak 999) ve `backstab_dot` (0,475, CS): host'ta `MeleeWeapon._is_backstab` hedefin `get_facing()` yönü ile saldırandan hedefe yatay yönün dot'u eşiği geçerse hasar backstab_damage olur (lag compensation'lı pozda; `Player.get_facing` = yaw, `TargetDummy.get_facing` = +Z, spawn'lara doğru). `V` hızlı bıçak (`player.melee_weapon`) backstab yapmaz.
- `V`: `MeleeWeapon.swing()` (sahibi: bekleme + animasyon, silah bu sürede ateş edemez) → `_request_melee` → host bütçe kontrolü + lag compensation ile `server_fire`: 5 ışınlık yelpaze, en yakın hitbox; `take_hit(..., is_melee = def.counts_as_knife)` (knife ödülü; Bear'ın tekmesi sayılmaz).
- `Q`: `Ability.try_use` (sahibi: yerel bekleme, HUD) → `_request_ability` → host kendi saatinde `server_try_use` (bekleme × 0,9 tolerans) → `server_use`. Hareket güçleri (aşama 5) `_use_local` ile sahibinde çalışır.
- Fırlatmalar (bombalar, yapışkan bomba, mayın, fırlatma bıçağı): `Player.get_throw_launch(origin, dir, hız, kaldırma)` → sağ elden çıkar (`THROW_HAND_OFFSET`), nişangahın değdiği noktaya doğru gider (ışın `world | player`, 80 m; 2 m'den yakında bakış yönü), atanın yatay koşu hızını taşır (`THROW_INHERIT`; uzak oyuncuda `PlayerNetSync.get_latest_velocity()`). Duvara yapışıkken el noktası duvarın bu tarafına çekilir.
- Bombalar: `GrenadeAbility.server_use` → `Game.server_spawn_grenade` → `ProjectileSpawner` (spawn_function, `Sync` görünürlüğü oyuncularla aynı desen). Fizik sadece host'ta; client kopyası donuk, `Sync` ile pozisyon/rotasyon alır. Zeminde sürtünme (`GROUND_DRAG`) kaymayı keser. Fitil bitince `Game.server_explode`: frag = yarıçap içinde görüş hattı olanlara doğrusal azalan hasar (kendine de, mankenlere de); flash = görüş hattı olan oyunculara bakış açısı ve mesafeye göre `Player.flash(sn)` → HUD beyaz ekran. Efekt `Game._explosion_fx` ile herkeste.

Sabit kurallar (kafa çarpanı istisnası gibi) `WeaponDef` alanlarıyla ifade edilir; örn. Heavy Rifle `damage = 250, leg_mult = 0.26` (gövde/kafa her sınıfı öldürür, bacak 65 = en düşük can 70'in altında).

### Sınıf silahları ve güçleri (aşama 5)

- **Cheetah:** SMG (hitscan, düşük `move_spread`), Dual Pistols (`DualPistolsWeapon`: sol tık sol, sağ tık sağ tabanca, ayrı bekleme, ortak şarjör; `PlayerCommand.secondary_pressed`). Dash (`DashAbility` → `Movement.start_dash`: girdi yönünde, yoksa bakış yönünde düz atılma, havada da, yerçekimsiz; bitince yatay hız `exit_speed`'e sınırlanır). Adrenaline (`AdrenalineAbility`: sahibinde `Player.start_buff_local` → hareket hızı ve `Weapon.get_fire_interval()`; host'ta `server_start_buff` → hız/ateş kontrolleri).
- **Volcano:** Shotgun (`ShotgunWeapon`: sabit `pellet_pattern`, sahibi tracer için, host hasar için aynı ışınları atar; mesafeyle azalan hasar hedef başına toplanır → tek `take_hit` / `confirm_hit`). Grenade Launcher (`LauncherWeapon`: `WeaponDef.grenade`'i `Game.server_spawn_grenade` ile host'ta fırlatır, çarpınca patlar, atanı da yaralar). Sticky Bomb ve Landmine `GrenadeAbility` + `GrenadeDef` bayraklarıyla; yapışkan bomba oyuncuya yapışırsa host'ta o oyuncunun konumunu izler; mayın durunca donar, `arm_time` sonra üstüne/yanına gelen (atan hariç, hasar alabilen) oyuncuyla patlar, oyuncu başına 1 tane.
- **Hound (2026-10-05):** Scout (hitscan, dürbün 2,5x, düşük `move_spread`), Double Barrel (`ShotgunWeapon`, 2 fişek, 0,2 sn aralık), Desert Eagle. **Sonar** (`SonarAbility`): host menzildeki canlı oyuncuları bulur → `PlayerEffects.server_show_sonar` sadece Hound'un sahibine (`_show_sonar` → `SoldierRig.reveal`: gövde mesh'ine `material_overlay`, `no_depth_test` kırmızı, süre sonunda kalkar) + her bulunana `server_sonar_ping` (Hound'un yerinden 3D ping; bağlı olmayan peer'e gönderilmez).
- **Ghost:** MP5SD, USP-S: `WeaponDef.suppressed` → `Sfx.shot` kısık `shot_suppressed` (12 m), sahibinde ve uzakta namlu alevi/tracer yok (`HitscanWeapon._fire`, `PlayerEffects._show_shot`). `ClassDef.silent_steps` → `Player._update_footsteps` ses çalmaz. **Cloak** (`CloakAbility`): host `Player.server_cloak(süre)` → replike `Player.cloaked` (StateSync property 10); host süre dolunca, `_request_fire` / `_request_stab` / `_request_melee` (`server_break_cloak`) ve `take_hit`'te hasar alınca kapatır. Her peer'de `PlayerEffects._process` `_cloak_value`'yu `AbilityDef.fade_time` (0,6 sn) ile yumuşatır; `_fade_meshes` malzemelerin alfa'lı kopyalarını takar (her renderer'da çalışır; `GeometryInstance3D.transparency` uyumluluk renderer'ında çalışmıyor): başkalarında gövde + eldeki silah %6 görünür, nick gizli; sahibinde silah %45.
- **Trickster:** **Swap Dart** (`SwapDartAbility`): host'ta `SwapDart` (Node3D, sadece host) her tick dünya ışını + `projectile_radius` (0,3 m) küreyle hitbox taraması (fırlatma bıçağı gibi); ilk canlı oyuncuya değince `_swap` → iki `Player.server_teleport`. Herkes `DartFx` kozmetik dartını görür (`server_show_dart`).
- **Phantom:** **Mark / Recall** (`RecallAbility`): sahibinde ilk Q `_window_left = duration` (bekleme başlamaz), pencerede ikinci Q geri dönüş + bekleme; pencere biterse bekleme başlar. Host kendi saatiyle aynı fazları tutar (`server_try_use` override): işaret `server_show_mark` (herkese mor sütun), geri dönüşte `server_teleport`, süre/ölüm/loadout değişince `server_hide_mark` ve `host_ready_at`. HUD: `Ability.get_hud_window()` → `[kalan, toplam, yazı, taralı]`; `HudBar.striped` çapraz çizgiler (Ghost'un pelerin süresi de bu yolla, taralı değil).
- **Işınlanma (`Player.server_teleport`):** host `_life` sayacını artırır (respawn gibi), `reset_validation`, lag compensation geçmişini unutur, `_teleport_to(pos, life)` herkese: sahibi konumu alır ve hızını sıfırlar; eski life'lı hareket paketleri reddedilir, hız kontrolü atlamayı kabul eder.
- `Grenade` atanın gövdesiyle çarpışmaz (`add_collision_exception_with`); GL ve yapışkan bomba sahneleri oyunculara da çarpar (`collision_mask = 3`), frag/flash/mayın sadece dünyaya.

## Oyuncu yapısı

```
Player (CharacterBody3D)            player.gd       – durum, bileşenleri bağlar
├── CollisionShape3D                                – hareket kapsülü
├── Head (Node3D)                                   – göz noktası, eğilmede alçalır (sadece pozisyon)
├── Camera3D                                        – top_level, her frame Head'in interpolasyonlu pozisyonuna konur
│   └── WeaponHolder (Node3D)                       – aktif silah sahnesi buraya eklenir
├── Hitboxes (Node3D)
│   ├── HeadHitbox (Area3D)         hitbox.gd       – zone = HEAD
│   ├── BodyHitbox (Area3D)                         – zone = BODY
│   └── LegHitbox (Area3D)                          – zone = LEG (eğilince Hitbox.set_pose; kutular local_to_scene)
├── Model (Node3D)                                  – başkalarının gördüğü gövde (sahibinde gizli), çömelince scale.y = SoldierRig.CROUCH_SCALE
│   ├── Rig (SoldierRig)                            – `Player._ready`'de koddan kurulur: Mixamo iskeleti + karakter (Saul, `CharacterSkin`) + AnimationTree + SpineAim / WeaponHold modifier'ları
│   ├── Hand (Node3D) / Muzzle                      – eldeki silah; Rig her frame WeaponHold'un silah konumuna (reload/fırlatma klibinde sağ ele) koyar
│   ├── (Label3D)                                   – kafanın üstünde nick; airdrop taşıyanınki turuncu ve duvar arkasından görünür
│   └── Crown                                       – lider tacı; Rig kafanın üstüne koyar
├── Movement (Node)                 movement.gd     – Quake tarzı ivme, bhop, slide, crouch
├── PlayerInput (Node)              player_input.gd – sadece sahip client'ta aktif
├── NetSync (Node)                  player_net_sync.gd – hareket senkronu (sahip → host → diğerleri), interpolasyon, host hız kontrolü
├── Requests (Node)                 player_requests.gd – sahip → host istekleri (ateş, V, Q, loadout, düşme) + host kontrolleri
├── Status (Node)                   player_status.gd – kalkan, stun, itme, Adrenaline, kill ödülü, bıçak iadesi (host saati + sahibe RPC)
├── Effects (Node)                  player_effects.gd – herkesin gördüğü görseller: kalkan paneli, dürbün parlaması, eldeki silah modeli (`Model/Hand`, WeaponDef `world_model`), ip, decoy, uzak tracer
├── StateSync (MultiplayerSynchronizer)             – health, is_alive, is_protected, loadout; authority host (1)
└── (Ability)                                       – aktif güç, loadout'tan kurulur

Bileşenler sahnede sabit düğümler: RPC'leri her peer'da aynı yolda (`Players/<id>/Requests` vb.). Dışarıdan erişim `player.status.server_stun(...)`, `player.effects.show_grapple(...)` gibi; silahlar `player.send_fire(...)` ile atar. Bileşenlerin `_ready`'si oyuncununkinden önce çalıştığı için oyuncuya düğüm ekleyen kurulum (`Effects.setup`) `Player._ready`'den çağrılır.
```

### Üçüncü şahıs animasyon (aşama 8)

Sadece görsel; hitbox'lar, vuruş ve ölüm kararı değişmedi (host, sabit kutular, lag compensation).

- **Kaynak:** `assets/models/characters/mixamo/*.fbx` (Mixamo "without skin": sadece `mixamorig_*` iskeleti + tek klip). `SoldierAnimations` (statik, bir kez) klipleri bir `AnimationLibrary`'ye toplar: yürüyüşlerin kök hareketi silinir (gövdeyi oyun taşır), hızları kök hareketinden ölçülür; eksik yönler ters oynatmayla üretilir (`run_back` = ileri yürüyüş tersten, `run_back_right`, `crouch_left`), `crouch_idle` = çömelme yürüyüşünün ilk karesi. `strafing.fbx` kullanılmıyor (yerinde, yönü belirsiz).
- **Karakter (`CharacterSkin` + `data/characters/*.tres` = `CharacterModelDef`):** iskeletsiz statik bir modeli (şimdi Saul Goodman, `saul.glb`) çalışma anında bir kez Mixamo iskeletine bağlar: model ölçeklenir (`height`), çevrilir (`yaw_degrees`, +Z'ye baksın), iskelet modelin kendi pozuna bükülür (`fit_points`: dirsek, bilek, parmak ucu, diz, ayak bileği; sol taraf, sağ aynalanır), sonra her köşe en yakın iki kemiğe ağırlıklanır (uzaklık / o vücut parçasının kalınlığı). PS2 modelleri ayrı parçalardan yapılır: her parça (ceket, kol, bacak) önce gövde/kol/bacak olduğunu seçer, köşeleri sadece o türdeki kemikleri izler (sarkan elin yanındaki ceket eteği kola yapışmasın). Bind pozu bükülmüş poz; animasyonlar Mixamo'nun kendi dönüşleri olduğu için doğru oynar. Yeni model: `.tres`'te sahne, boy, dönüş ve uzuv noktaları (modelden ölçülür), `SoldierRig.MODEL`.
- **Ağaç (`SoldierRig`):** `state` Transition (ground / crouch / jump / fall) → `fire` Blend2 (üst gövde filtresi, `firing_rifle` atıştan sonra 0,35 sn) → `action` OneShot (üst gövde: `reload` ya da `throw`, aksiyon süresine sıkıştırılır). ground = BlendSpace2D (idle + 6 yön, yerel hız m/s; 2,2 m/s üstü klibi hızlandırır), crouch = BlendSpace1D (sol / dur / sağ) + üst gövdede nişan pozu. Girdiler her peer'ın zaten bildikleri: interpolasyonlu pozisyondan hız, yaw, `look_pitch`, `is_pose_crouched()`, gösterilen atış (`PlayerEffects._show_shot`), yer için kısa aşağı ray (katman 1).
- **`SpineAimModifier` (SkeletonModifier3D, animasyondan sonra):** (1) *upright*: omurgayı kafa ayakların (oyuncu orijininin) üstüne gelecek şekilde döndürür. Hitbox'lar animasyonla oynamadığı için öne eğik koşu klibi görünen kafayı kafa hitbox'ının dışına taşıyordu (~18 cm); şimdi görünen kafa hitbox ekseninde (koşarken ~9 cm alçak, kürenin içinde). (2) *pitch*: omurga bakış açısına eğilir (±60°).
- **`WeaponHoldModifier` (SpineAim'den sonra):** silahı sağ omzun önüne, bakış yönüne koyar (tüfek: omzun 26 cm önü / 17 cm altı; 45 cm'den kısa silahlar tabanca gibi, kollar uzanmış) ve iki kemikli IK ile sağ eli kabzaya, sol eli ön tutamağa (silah boyunun %40'ı ileride; tabancada sağ elin yanına) götürür; dirsekler aşağı-dışa, parmaklar silah boyunca. `tilt` silahı yukarı kaldırır, `swing` bıçak savurma yolu. `influence` reload/fırlatma klibinde 0'a iner, silah o sırada sağ el kemiğini izler. Silah boyu `PlayerEffects.get_held_length()` (dünya modelinin AABB'si).
- **Aksiyonlar (görünür olsun diye ağdan):** sahibi `PlayerEffects.report_action(kind, sn)` → host (`_request_action`, gönderen sahibi mi kontrol) → diğer herkes (`_show_action`) → `SoldierRig.play_action`. RELOAD: `Weapon._start_reload` (süre doldurma çarpanıyla); `WeaponDef.reload_clip = true` olan şarjörlü silahlarda (AR, Burst, SMG, LMG, Marksman, Heavy, Railgun) Mixamo reload klibi, diğerlerinde (pompalı, revolver, tabancalar, musket, roketatar, GL, minigun) silah 38° yukarı kalkar. THROW: Q bombası (`GrenadeAbility`) ve fırlatma bıçağı; Throw_Grenade klibinin sadece atış kısmı (1,1–2,3 sn) 0,7 sn'ye sıkıştırılmış, silah bu sırada gizli. SWING: `MeleeWeapon._play_swing` (V, bıçak sol/sağ tık) — sağ el yukarı-dıştan aşağı-içe. Kozmetik: kaybolursa (unreliable) bir şey bozulmaz.
- **Çömelme:** klip, çömelmiş kafa hitbox'ından (0,98 m) uzun durur; `Model` `CROUCH_SCALE` (0,74) ile basılır.
- **Ölüm:** `_set_alive(false)` başkalarının ekranında `Corpse` bırakır (yeni bir rig, `dying` 1,4x, 5 sn sonra batarak kaybolur; collision yok). Decoy `Model`'i kopyaladığında rig donmuş pozla gelir (`_player` yok → ağaç kapalı).
- Kendi oyuncunda rig de çalışır (decoy kopyası gerçek poz alsın diye), ama `Model` gizli.

### Girdi, bakış ve kamera

- `PlayerInput.gather()` her physics tick'te bir `PlayerCommand` (RefCounted) üretir. `Movement` ve `Weapon` sadece bu komutu okur, böylece aşama 2'de aynı mantık ağdan gelen girdiyle de çalışır.
- Fare bakışı input anında uygulanır: yaw = gövdenin `rotation.y`, pitch = `Player.look_pitch`. Hassasiyet CS ile aynı birimde (`sens * 0.022` derece/count), FOV 4:3 yatay (CS kuralı).
- Physics interpolation açık (60 Hz tick, yüksek FPS'te akıcı). Kamera `top_level` ve interpolasyonu kapalı, `_process`'te yerleştirilir, bu yüzden fare gecikmesi olmaz.
- Atış `get_aim_origin()` (tick anındaki göz) + `get_aim_basis()` (bakış + recoil) ile yapılır, kamera pozisyonuyla değil.
- **Kamera hissi (`CameraFeel`, sadece sahibinde, sadece görsel):** hızla artan FOV kayması, head bob, iniş çökmesi (`Movement.landed`), slide'da alçalma + yan yatma, hasar sarsıntısı (host `_on_hurt`, 0,4°). Miktarlar `data/camera/default.tres`, her efekt `Settings.camera_*` (0–1) ile ölçeklenir. Nişan bunlardan etkilenmez.
- **Hasar kırmızısı (`DamageOverlay`, HUD'un çocuğu, kendi CanvasLayer'ı `ScreenFx.LAYER + 1`, yoksa PS2 filtresi kırmızıyı soldurur):** `Player.health_changed` ile: her darbede kenarlarda kısa kırmızı parlama (hasara göre), can %60'ın altına inince kalıcı kırmızı kenar, can azaldıkça koyulaşır. Değerler `CameraFeelDef` "Damage Overlay" grubu; `Settings.camera_damage_shake` ile ölçeklenir.
- **Birinci şahıs gövde Saul:** `FirstPersonArms` kolların köşelerini önkol kemiğine bağlılığına göre boyar (vertex rengi) ve bir shader ile önkolu lacivert takım kolu, bileği beyaz manşet, eli modelin ten dokusu yapar; `FirstPersonLegs` takım pantolon + siyah ayakkabı.
- **Atış tekmesi (`WeaponDef.view_kick`, derece, sadece görsel):** desen tepmesi ilk atışta sıfır olduğu için tek atışlık silahlar (Heavy 9, Musket 8, pompalı 7, roketatar 6, railgun 6, Marksman 5, revolver 5, GL 4) her atışta ayrıca tekme atar: `Player.send_fire` → `CameraFeel.add_kick`; silah modeli tamamen (yukarı + `kick_back` geri + sırayla sağa/sola hafif yatma), kamera `kick_view_share` (%30) kadar; `kick_recover` ile söner. Nişan (`get_aim_basis`) etkilenmez.
- **Birinci şahıs silah boyu:** `CameraFeelDef.view_model_scale` (1,15): `Player._add_weapon` her silah sahnesini bu kadar büyütür; tutuş işaretleri ve namlu da ölçeklendiği için eller ve mermi izi uyar.
- **Birinci şahıs gövde (sadece sahibinde, sadece görsel):** `FirstPersonLegs` (Player'ın çocuğu): iki kemikli bacak, ayak hedefi hızla adım atar, çömelince katlanır, havada toplanır, slide'da öne uzanır (kalça gözün önüne geçer, botlar görünür). `FirstPersonArms` (WeaponHolder'ın çocuğu): hvarley'in "Rigged Low Poly FPS Hands" modeli (`assets/models/characters/fp_hands/fp_hands.glb`): iki önkol, bir tüfeği tutar pozda (sağ yumruk kabzada, sol el kundağın altında; modelin kendi gri yer tutucu tüfeği atılır). Her önkol (`Armature_002` sağ, `Armature_001` sol) ayrı yerleştirilir: modeldeki tutuş noktası (`RIGHT_HOLD` / `LEFT_HOLD`, ölçekli yan/üst görüntüden) silahın tutuş noktasına oturur, el silahla birlikte döner. IK ve parmak animasyonu yok; parmaklar hep tutuş pozunda. Çift tabancada sol el, sağ elin aynalanmış kopyası. Gölge düşürmez; gölge tarafı karanlık kalmasın diye malzeme `DIFFUSE_LAMBERT_WRAP` + backlight (`SELF_LIGHT`). **Tutuşlar silah sahnesinde:** `RightHand` / `LeftHand` Marker3D = tutuşun ortası (silahın kendi uzayında), dönüşü = elin duruşu (birim = modelin kendi tüfek tutuşu; kundakta `(0, 0, -25°)`, önkol sol alttan gelir). Değerler `tools/apply_view_grips.py`'de (yakın dövüşte `("along", d)` = sap ekseninde model birimi). Marker yoksa namluya göre tahmin. Yakın dövüş ve fırlatma bıçağında el yönü modelden gelir (sap = model −Z); el sap ekseni etrafında, önkol `BLADE_FOREARM` yönüne (sağ alttan) en yakın olacak açıya döner (silah başına bir kez, `_best_blade_turn`), böylece bıçağın açısı serbestçe ayarlanır. Tabanca ve revolver iki elli (CS:GO: sol el sağı alttan sarar, `PISTOL_SUPPORT`); `NONE` silahlarda eller gizli. **Animasyonlar (sahibinde, sadece görsel):** silah kökünün transformu oynatılır, eller IK ile takip eder, yani bütün kol hareket eder. `MeleeWeapon`: kurma → vuruş → dönüş anahtarları (tek el: sağ üstten sol alta kesik, iki el: yukarıdan iniş; `melee_swing_angle` ölçekler, 0 = yok). `ThrowingKnifeWeapon`: atışta eldeki model ilk karede gizlenir, el ileri savrulur, görüş altına iner, mermi kaldıysa yeni bıçakla döner. Gölge yok.
- **Ekran filtresi (`ScreenFx`, CanvasLayer 120, her şeyin üstünde):** `assets/shaders/ps2_screen.gdshader` — doygunluk/kontrast/soğuk ton, 5 bit renk + Bayer dither, grain, vignette (değerler `ps2_screen.tres`). `Settings.post_process` kapatır, `Settings.render_scale` root viewport'un `scaling_3d_scale`'i.
- **UI ölçeği:** taban 1280×720, `canvas_items` stretch + `expand`: UI her çözünürlükte aynı düzende büyür, 3D tam çözünürlükte.
- **Vuruş hissi:** host onayından sonra (`confirm_hit`) X hit marker (gövde/bacak beyaz, kafa kırmızı; `Settings.hit_marker_enabled`) ve sadece vuranın ekranında hasar sayısı (`DamageNumber`, Label3D). Mankenler artık kendi sayılarını göstermez. Hit-stop yok.

### Silah

- `Weapon` (taban): şarjör, ateş aralığı, şarjör değiştirme, recoil durumu. `HitscanWeapon._fire()` ray atar, `Hitbox`'a çarparsa `owner.take_hit(amount, zone, attacker_id) -> bool` çağırır (aşama 1'de yerel; aşama 2'de host'a taşınır).
- Recoil deseni: tırmanma kısmı + salınım; desen bitince `recoil_loop_start`'tan döngüye girer (`Weapon.recoil_index`), salınımın x toplamı sıfır, böylece uzun sprey sola/sağa kaymaz; `recoil_max_up` tırmanmayı keser.
- Bıçak sağ tık (`heavy_damage`, `heavy_interval`, `heavy_backstab_damage`): sahibi `MeleeWeapon.tick` içinde ortak bekleme ile `requests.send_stab` → host `_request_stab` aynı slot bütçesini `heavy_interval` ile harcar, `MeleeWeapon.server_heavy` açıkken `server_fire`.
- HUD silah satırları: slot başına sabit satır (0–3), elde olan büyük + parlak (modulate > 1) + açık plaka; ikonlar `assets/ui/weapon_icons/<id>.png`, `tests/render_weapon_icons.tscn` modellerden üretir (pencereli çalışır), yoksa çizilmiş yer tutucu.
- Pencere: `Settings.fullscreen` (varsayılan açık, kenarlıksız tam ekran), Alt+Enter / F11, Ayarlar > Graphics; headless ve `--write-movie` çalıştırmalarında dokunulmaz.
- Recoil: `WeaponDef.recoil_pattern` her atışta nişana (`get_aim_basis`, mermiler) eklenen derece değerleri; ateş bitince `recoil_recovery` hızıyla sıfıra döner. İlk mermi her zaman tam isabetli. Kamera bunun `CameraFeelDef.recoil_view_share` kadarını izler (şu an 0: nişangah yerinde kalır, mermiler desene göre tırmanır, Can'ın kararı); kalan kısım eldeki silahı yukarı ve geri iter (`Player._kick_view_model`, WeaponHolder dönüşü).
- Dağılma (`HitscanWeapon.get_spread_cone`, sahibi seçer, host gönderilen yönü izler): hıza bağlı `move_spread` + `unscoped_spread` (dürbünlü silahta dürbünsüz; dürbünsüz silahta her atış, örn. Minigun) + slide'da `MovementDef.slide_spread`. Dürbün `scope_in_time` boyunca açılır: `Player.scope_blend` 0 → 1, zoom yumuşak geçer (`get_zoom`), `unscoped_spread` aynı oranda söner. `hip_crosshair = false` silahta dürbünsüz nişangah gizli (Hawk'ın tüfekleri).
- Tracer ve mermi izi `ShotEffects` (sadece görsel) ile `Players` node'una eklenir. Uzak oyuncuların atışlarını host `_show_shot` ile yayar.

### Test haritası

`scenes/maps/test_range.tscn`: 15/30/55 m'de mankenler (`scenes/maps/target_dummy.tscn`, 70/100/175 HP), zıplama/crouch-jump kasaları (0,8 / 1,4 / 2,2 m), rampa ve platform, crouch tüneli (1,3 m), 10 m işaretli bhop pisti. Mankenler katman 2'de (oyuncu gibi), hitbox'ları katman 3'te. Oyuncu ve HUD haritada değil `game.tscn`'de; harita `SpawnPoints` (8 nokta) sağlar. Manken canı host'ta, can yazısı `Net.broadcast` ile herkeste; hasar sayısı sadece vuranın ekranında (`DamageNumber`). Mankenler sadece bu haritada.

### Hareket

- Quake/Source tarzı: yerde sürtünme + ivme. Hava: `air_speed_cap = 0` → serbest hava ivmesi (strafe ile yön değiştirme), ama hava ivmesi yatay hızı `max(mevcut hız, base × bhop_cap_mult)` üstüne çıkaramaz.
- **Bunny hop:** Yere değdiği frame'de zıplarsa sürtünme uygulanmaz → hız korunur. Zıplamada yatay hız `base × 1.3`'e kırpılır → sonsuz hızlanma yok.
- **Affedicilik:** jump buffer (`jump_buffer_time`) ve coyote time (`coyote_time`: kenardan düştükten kısa süre sonra zıplama).
- **Slide:** Yerdeyken ve hız eşiğin üstündeyken Ctrl (düz ileri) → kısa süreli düşük sürtünmeli kayma, alçak kapsül. Slide'dan zıplamada (`slide_jump_keeps_speed`) hız 1,3 tavanına kırpılmaz, korunur (kazanç yok; aynı tick'te başlayan slide sayılmaz). **Eğimde slide:** zeminin yatay aşağı yönü (`get_floor_normal` x/z, uzunluğu eğimin sinüsü) × yerçekimi × `slide_slope_accel` eklenir, hız `base × slide_slope_max_speed_mult`'a kadar (host hız kontrolünün altında); aşağı inerken slide süresi işlemez.
- **Crouch:** Kapsül ve kamera alçalır, hız düşer. Havada crouch = crouch-jump (kasalara çıkış).
- **Basamak çıkma (`_move_and_step`):** `move_and_slide` duvara (normal y < 0,7) takılırsa başlangıçtan "yukarı `step_height`, ileri, aşağı" denenir. Üst yüzey kısa bir ışınla kontrol edilir, çünkü kapsülün yuvarlak altı basamağın kenarına eğik temas eder. İleri adım en az `STEP_MIN_FORWARD` (0,15 m), böylece kapsül kenarda asılı kalmaz. Göz yükselme kadar indirilir ve `_update_eye` ile yumuşakça geri gelir. Sadece yerdeyken ve yukarı hız yokken çalışır (zıplarken değil); Charge ve Dash de kullanır. `floor_snap_length` = `step_height`, merdiven ve rampa inerken ayak yerde kalır.
- Değerler `data/movement/standard.tres` (`MovementDef`, `ClassDef.movement`) dosyasında; koşu hızı sınıfın `move_speed` değeri. Hareket sadece sahip peer'da çalışır.

### Haritalar

- `MapDef` (`id`, `display_name`, `scene_path`, `players_hint`), `MapList` (`data/maps/map_list.tres`; lobi sırası, ilki varsayılan). Host indeksi seçer, `Net.server_start_match` yolu `map_path` olarak herkese gönderir. Komut satırı `--host` ve Test Range `Net.DEFAULT_MAP_PATH` (test_range) kullanır.
- Harita sahnesi: `Geometry` (çarpışmalı her şey, katman 1: hareket, mermi, kanca, basamak çıkma görür), `SpawnPoints` (Marker3D, yaw = bakış), `Pickups` (`pickup.tscn` + `PickupDef`), `AirdropPoints` (Marker3D; üstü 40 m açık olmalı, kasa oradan düşer). Mankenler sadece Test Range'de.
- **Yapım kuralları** (`map_test` ve `movement_test` bunları denetler):
  - Merdiven = görsel basamaklar (çarpışmasız) + görünmez rampa çarpışması. Arka arkaya sığ basamaklarda kapsül iki kenar arasında takılır.
  - Rampanın üst ucu bağlandığı döşemenin kenarına tam oturur. Aradaki küçük dışbükey kenarda floor snap tutmaz, inen oyuncu havalanır. Alt ucu zeminin içine uzanır.
  - Tek basamak, kaldırım ve eşik ≤ 0,4 m (basamak çıkma); daha yüksekler zıplama / crouch-jump ister (crouch-jump ~1,4 m).
  - Çatıdan bhop hızıyla atlayan çiti aşmasın: site sınırında yüksek görünmez duvar (StaticBody3D + BoxShape3D, mesh yok; gizli CSG kullanılmaz).
  - Her yüksek noktaya en az iki yol: `map_test.ALTERNATE_ROUTES`'ta harita başına listelenir, her yol tek tek kaldırılıp navmesh yeniden çıkarılır.
- **Ice Yard:** `tools/maps/build_iceworld.py`; 67×67 m duvarlı kar avlusu (yerleşim 56 m için yazılı, yatay koordinatlar `SCALE` = 1,2 ile çarpılır, yükseklikler değil), kapalı ve karanlık hava, 4 yönlü dönme simetrisi (`turn` / `quarter_box`: çeyrek 0 yazılır, 90°'lik dönüşlerle çoğaltılır). Orta buz plazası (her kenarda boşluk, sütun), orta halka buz duvarları + kasalar, köşelerde 3 m nişancı yuvası (rampa + iki kasa basamağı), duvar üstünde görünmez duvar, dışarıda çam/kar (dekor).
- **AVM:** `tools/maps/build_mall_blockout.py` yerleşimi koddan üretir (CSGBox3D, `use_collision`). Yerleşim oturana kadar değişiklik orada yapılır ve sahne yeniden üretilir; sonra sahne elle düzenlenip üreteç bırakılabilir. Eksenler: x doğu, z güney; bina x −32..32, z −24..24; katlar 0 / 5 / 10 m.

## Fizik katmanları

| Katman | İsim | İçerik |
| --- | --- | --- |
| 1 | world | Harita geometrisi |
| 2 | player | Oyuncu hareket kapsülleri |
| 3 | hitbox | Oyuncu hitbox Area3D'leri (raycast hedefi) |
| 4 | projectile | Fiziksel mermiler |
| 5 | pickup | Pickup ve airdrop alanları |
| 6 | grapple | Kanca takılabilen yüzeyler |

Hitscan raycast maskesi: `world | hitbox`. Oyuncu kapsülü maskesi: `world | player` (oyuncular birbirinin içinden geçmez).

## Input Map

Aksiyon isimleri (`project.godot` içinde, fiziksel tuş kodu ile): `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `crouch` (Ctrl: eğil; koşarken basınca slide), `sprint` (Shift), `respawn` (T, sadece test range), `fire`, `secondary`, `ability`, `reload`, `interact` (E basılı: kasa aç), `melee`, `weapon_primary`, `weapon_secondary`, `weapon_knife` (3, bıçak), `weapon_special` (4, airdrop silahı), `class_menu`, `scoreboard`, `pause_menu` (Esc).

## Kodlama kuralları

- Statik tip her yerde. `@onready var camera: Camera3D = $Head/Camera3D`.
- Fonksiyon/değişken adı Godot'un kendi `Node` / `Node3D` üyeleriyle çakışmasın (örn. `request_ready`, `position`): proje uyarıları hata sayıyor, script derlenmez.
- Sınıf scriptlerinde büyük kaynak ağaçlarını (`roster.tres` gibi) `const ... = preload(...)` ile tutma: başka scriptlerle derleme döngüsü kurabilir; ilk kullanımda `load` et.
- İsimlendirme: dosya ve fonksiyon `snake_case`, `class_name` `PascalCase`, sinyal geçmiş zaman (`died`, `weapon_fired`).
- Oyun içi tüm metinler İngilizce.
- Kod yorumları İngilizce, kısa. Dokümanlar Türkçe.
- Sihirli sayı yok: denge değerleri `.tres`'te, teknik sabitler dosya başında `const`.
- Bir sistem diğerinin iç durumunu doğrudan değiştirmez; ya fonksiyon çağırır ya `Events` sinyali.
- Ağa dokunan her fonksiyonun başında kimin çalıştırdığı belli olsun:
  ```gdscript
  func apply_damage(amount: float, attacker_id: int) -> void:
      assert(multiplayer.is_server(), "apply_damage is host-only")
  ```
- RPC isimleri niyet belirtir: client isteği `request_*`, host yayını `broadcast_*` / `on_*`.

## Git

- `.godot/` klasörü commit edilmez (her makinede yeniden oluşur). Varlıkların yanındaki `.import` dosyaları commit edilir.
- Büyük binary'ler (model, doku, ses) büyüyünce Git LFS'e geçilir (`.gitattributes` içinde hazır, yorum satırı).
- Sürümler GitHub Releases'a zip olarak: `SFB-GO_v0.X.zip`.
