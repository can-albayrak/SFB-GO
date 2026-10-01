# SFB:GO – Architecture

Kod yapısının ve kuralların referansı. Tasarım için `GDD.md`, durum için `PROGRESS.md`.

## Temel kararlar

| Konu | Karar |
| --- | --- |
| Motor | Godot 4.4+ (en son stable 4.x) |
| Dil | GDScript, **statik tipli** (`var hp: int`, `func f() -> void`) |
| Renderer | Mobile (Vulkan) |
| Fizik | Jolt Physics (dahili), physics tick 60 Hz |
| Ağ | `ENetMultiplayerPeer`, listen server, host = peer 1 |
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
│   └── settings.gd          # Kullanıcı ayarları (user://settings.cfg), `changed` sinyali
├── data/
│   ├── classes/             # ClassDef .tres (wolf, hawk, bear, cheetah, volcano) + roster.tres
│   ├── camera/              # CameraFeelDef .tres (default.tres: FOV kayması, head bob, iniş, slide, sarsıntı)
│   ├── movement/            # MovementDef .tres (standard.tres: ivme, zıplama, bhop, slide, coyote)
│   ├── weapons/             # WeaponDef .tres
│   └── abilities/           # AbilityDef .tres
├── scripts/
│   ├── defs/                # class_def.gd, class_roster.gd, weapon_def.gd, ability_def.gd, grenade_def.gd, movement_def.gd, match_def.gd, camera_feel_def.gd
│   ├── game/                # game.gd (maç sahnesi: harita, spawn, respawn), lag_compensator.gd
│   ├── player/              # player.gd + bileşenler (player_net_sync, player_requests, player_status, player_effects), movement.gd, camera_feel.gd, player_input.gd, player_command.gd, hitbox.gd, loadout.gd
│   ├── maps/                # target_dummy.gd vb. harita scriptleri
│   ├── weapons/             # weapon.gd (taban), hitscan_weapon.gd, shotgun_weapon.gd, dual_pistols_weapon.gd, launcher_weapon.gd, melee_weapon.gd, throwing_knife_weapon.gd
│   ├── abilities/           # ability.gd (taban), grenade_ability.gd, grenade.gd (bomba/mermi), grapple, decoy, shield, charge, dash, adrenaline
│   ├── pickups/             # pickup.gd, airdrop.gd
│   └── ui/                  # hud.gd, crosshair.gd, damage_number.gd, scoreboard.gd, kill_feed.gd, main_menu.gd, lobby.gd, loadout_menu.gd, settings_panel.gd
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
│       └── mall/            # İlk gerçek harita
├── tools/                   # .gdignore; oyun dışı araçlar
│   └── blender/build_placeholders.py   # Yer tutucu modelleri üretir (Blender headless → .glb)
└── assets/
    ├── models/              # characters/soldier.glb, weapons/*.glb (Blender'da +Y ileri = Godot -Z)
    ├── textures/
    ├── audio/
    └── shaders/
```

## Autoload'lar

| İsim | Görev | Kim yazar |
| --- | --- | --- |
| `Events` | Global sinyaller (`player_killed`, `match_ended`, `airdrop_incoming`...). Sistemler birbirini doğrudan çağırmaz, buradan haberleşir. | Herkes emit eder |
| `Net` | Host/join, peer listesi, oyuncu isimleri, bağlantı kopması | Host + client |
| `Match` | Skor, kill hedefi, süre, spawn seçimi, pickup/airdrop zamanlayıcıları | **Sadece host** değiştirir, client'lara RPC ile yayar |
| `Settings` | İsim, son host, FOV, hassasiyet, crosshair + hit marker, kamera efekti ölçekleri (tuş/grafik sonra). `SettingsPanel` ana menü ve Esc menüsünden açılır. | Yerel |

## Ağ modeli

**Prensip:** Her oyuncu kendi hareketini kendisi hesaplar (akıcı his için), ama **hasar, ölüm, skor, pickup, airdrop ve spawn kararlarını sadece host verir.**

### Otorite

- Her `Player` node'unun multiplayer authority'si kendi peer id'si → hareket ve input o client'ta.
- `health`, `kills`, `deaths`, `is_alive`, aktif buff'lar → host'ta tutulur, client'lara yayılır. Client bunları asla kendi değiştirmez.
- Oyuncular `MultiplayerSpawner` ile spawn edilir (host spawn eder, herkeste çoğalır).

### Oturum akışı (aşama 2)

- `scenes/game.tscn` (`/root/Game`, `scripts/game/game.gd`): maç sahnesi. `Net.map_path` haritasını `Map` adıyla yükler (her peer'da aynı yol), `HUD`, `Players` ve `PlayerSpawner` içerir. Haritalar sadece geometri + `SpawnPoints` (Marker3D) + harita nesneleri (mankenler).
- **Host:** `Net.host_game()` → ENet server (port 7777) → `lobby.tscn` (komut satırı `--host`: `use_lobby = false`, doğrudan `game.tscn`). **Client:** `Net.join_game()` → bağlanınca adres `Settings.last_host`'a kaydedilir, `_request_register(name)` → host lobi açıksa `_welcome_lobby()` (client `lobby.tscn` yükler), maç sürüyorsa `_welcome(map_path)` → client `game.tscn` yükler → `Game._request_spawn()`.
- **Lobi (`Net.in_lobby`):** oyuncu listesi, isim, hazır durumu (`_request_ready` → host `ready_peers` → `_on_lobby_synced` herkese), boş yüz yeri (aşama 8). Host kill/dakika/harita seçer (`server_set_lobby_settings`, `Net.MAP_NAMES/MAP_PATHS`) ve Start der: `server_start_match` → `Match.configure` → host `game.tscn` yükler, kendi `Game`'i hazır olunca lobideki her peer'a mevcut `_welcome`'ı gönderir. Yani lobiden gelenler geç katılanla aynı yoldan girer; `Game` ve `Match` lobiden habersizdir.
- Host, sahnesi yüklenmiş peer'ları `Net.ingame_peers`'te tutar. Oyun RPC'leri sadece bunlara gider (`Net.broadcast(node, method, args)`), yüklenmekte olan client "node not found" almaz. Hareket yayını (`Net.state_peers`) katılımdan 0,5 sn sonra başlar; unreliable paketler reliable spawn paketlerini geçmesin diye. Geç katılana mankenlerin canı `sync_to_peer` ile gönderilir.
- Maç kuralları `Match.rules` (`MatchDef`, `data/match/default.tres`): kill hedefi, süre, respawn, spawn koruması, sonuç ekranı süresi. Host ana menüde kill/dakika seçer (`Match.configure`); Test Range'de limit yok.

### Maç döngüsü (aşama 3, `autoload/match.gd`)

- Durum host'ta: `kills`, `deaths`, `state` (PLAYING/ENDED), `time_left`. Her değişiklik `Net.broadcast` ile; katılana `_sync_full` snapshot. Süre her peer'da yerelde geri sayar.
- Akış: `Player._die` → `died(killer, weapon, headshot)` → `Game._on_player_died` (mesafe hesaplar) → `Match.server_register_kill` → `_on_kill` herkese → `Events.kill_registered` (kill feed) + `scores_changed` (skor tablosu, taç).
- Bitiş: kill hedefi veya süre → `_on_match_ended(winner, awards)` → `end_screen_time` (10 sn) sonra `_on_match_started` → `Events.match_started` → host herkesi yeniden doğurur. ENDED'da hasar yok.
- Ödüller (host hesaplar): Most Deaths, Longest Headshot, Most Self-Kills. Knife ödülü hızlı yakın dövüşle (aşama 4) gelecek.
- Doğma noktası: canlı düşmanlara en yakın mesafesi en büyük olan nokta (`Game._pick_spawn_point`).
- Spawn koruması: `Player.is_protected` (host'ta, StateSync ile yayılır), `rules.spawn_protection` sn veya ateş edince biter; korumalıyken hasar yok, başkalarına model yanıp söner.
- Taç: `Match.get_leader()` (tek başına lider, ≥1 kill) → `Player.set_leader`; kendinde çizilmez.
- Ölüm ekranı: öldüren, silah ve öldürenin kalan canı (`_announce_death(killer_id, weapon_name, killer_health)`).
- Spawn: `spawner.spawn_function` + `{id, position, yaw}` verisi. `Player.StateSync` (MultiplayerSynchronizer, authority 1, `public_visibility = false`) spawn görünürlüğünü belirler: host yeni peer için `set_visibility_for()` açınca mevcut oyuncular o peer'da da doğar (geç katılma).
- **Test Range** = `OfflineMultiplayerPeer` ile aynı kod: biz peer 1'iz, `is_server()` true.
- Host çıkarsa client'lar `server_disconnected` → ana menü ("Host left the game").
- Komut satırı (test için): `-- --name=X --host` / `-- --join=IP`.

### Senkronizasyon

| Veri | Yöntem | Sıklık |
| --- | --- | --- |
| Oyuncu pozisyonu, bakış yönü, crouch, `life` | Sahibi `_submit_state` → host `_relay_state` → diğerleri `_receive_state`; `unreliable_ordered` RPC, sahibin saat damgasıyla | 30 Hz |
| Diğer oyuncuların görüntüsü | Snapshot tamponu, ~100 ms geriden interpolasyon (`Player._interpolate_remote`) | Her frame |
| Ateş etme | Sahibi `_request_fire(origin, dir, slot)` → host doğrular (hayatta mı, ateş hızı, origin ≤ 3 m sapma) → `server_fire` | Olay bazlı, reliable |
| `health`, `is_alive` | `StateSync` (ON_CHANGE, spawn'da da gönderilir) | Değişince |
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
- **Ateş hızı:** Bütçe tabanlı (`get_average_shot_interval() × 0,95`, 0,25 sn birikme payı): ağ dalgalanmasında toplu gelen atışlar kaybolmaz, sürekli fazla hız reddedilir. Seri silahta tetik aralığı seriye, çift tabancada ikiye bölünür; Adrenaline aktifken host kendi saatindeki çarpanla böler.
- **Hız:** token bucket, sınıf hızı × host'taki Adrenaline hız çarpanı × bhop tavanı × 1,5. Dash (18 m/s × 0,15 sn ≈ 2,7 m) bu 1 sn'lik bütçeye sığar.
- **Ölüyken ateş**, geçersiz slot, origin'i bilinen gözden 3 m'den uzak atış reddedilir.
- Host mermi/şarjör takibi yapmaz (bilinçli; arkadaş arası).

### Fiziksel mermiler (bomba, roket, bıçak)

Host spawn eder ve simüle eder, pozisyonları client'lara yayılır. Atan client kendi ekranında hemen görsel bir kopya gösterir, host'unki gelince ona geçer.

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

- `data/classes/roster.tres` (`ClassRoster`): oynanabilir sınıfların sırası. Loadout = `PackedInt32Array [sınıf, birincil silah, güç]` roster indeksleri (`scripts/player/loadout.gd`: doğrulama, Settings'e kayıt, açıklama).
- `Player.loadout` StateSync ile host'tan herkese yayılır (spawn'da da). Setter `_apply_loadout()` çağırır: `class_def`, hareket, silahlar (birincil + ikincil), bıçak (`MeleeWeapon`), `Ability` node'u yeniden kurulur. Her peer aynısını kurar: host hasar için, sahibi kullanım için, diğerleri görüntü için.
- Seçim akışı: sahibi `request_loadout(code)` → host `_request_loadout` doğrular → doğuştan sonraki `rules.loadout_swap_window` (3 sn) içindeyse anında uygular + can doldurur, değilse `_pending_loadout` olarak saklar ve `server_respawn`'da uygular. İlk doğuşta client kendi kayıtlı seçimini `_request_spawn(loadout)` ile gönderir.
- Son seçim `Settings` üzerinden `user://settings.cfg`'e kaydedilir (isim, loadout, FOV, hassasiyet, crosshair).

### Yakın dövüş ve güçler

- `V`: `MeleeWeapon.swing()` (sahibi: bekleme + animasyon, silah bu sürede ateş edemez) → `_request_melee` → host bütçe kontrolü + lag compensation ile `server_fire`: 5 ışınlık yelpaze, en yakın hitbox; `take_hit(..., is_melee=true)` (knife ödülü).
- `Q`: `Ability.try_use` (sahibi: yerel bekleme, HUD) → `_request_ability` → host kendi saatinde `server_try_use` (bekleme × 0,9 tolerans) → `server_use`. Hareket güçleri (aşama 5) `_use_local` ile sahibinde çalışır.
- Bombalar: `GrenadeAbility.server_use` → `Game.server_spawn_grenade` → `ProjectileSpawner` (spawn_function, `Sync` görünürlüğü oyuncularla aynı desen). Fizik sadece host'ta; client kopyası donuk, `Sync` ile pozisyon/rotasyon alır. Zeminde sürtünme (`GROUND_DRAG`) kaymayı keser. Fitil bitince `Game.server_explode`: frag = yarıçap içinde görüş hattı olanlara doğrusal azalan hasar (kendine de, mankenlere de); flash = görüş hattı olan oyunculara bakış açısı ve mesafeye göre `Player.flash(sn)` → HUD beyaz ekran. Efekt `Game._explosion_fx` ile herkeste.

Sabit kurallar (kafa çarpanı istisnası gibi) `WeaponDef` alanlarıyla ifade edilir; örn. Heavy Rifle `damage = 250, leg_mult = 0.26` (gövde/kafa her sınıfı öldürür, bacak 65 = en düşük can 70'in altında).

### Sınıf silahları ve güçleri (aşama 5)

- **Cheetah:** SMG (hitscan, düşük `move_spread`), Dual Pistols (`DualPistolsWeapon`: sol tık sol, sağ tık sağ tabanca, ayrı bekleme, ortak şarjör; `PlayerCommand.secondary_pressed`). Dash (`DashAbility` → `Movement.start_dash`: girdi yönünde, yoksa bakış yönünde düz atılma, havada da, yerçekimsiz; bitince yatay hız `exit_speed`'e sınırlanır). Adrenaline (`AdrenalineAbility`: sahibinde `Player.start_buff_local` → hareket hızı ve `Weapon.get_fire_interval()`; host'ta `server_start_buff` → hız/ateş kontrolleri).
- **Volcano:** Shotgun (`ShotgunWeapon`: sabit `pellet_pattern`, sahibi tracer için, host hasar için aynı ışınları atar; mesafeyle azalan hasar hedef başına toplanır → tek `take_hit` / `confirm_hit`). Grenade Launcher (`LauncherWeapon`: `WeaponDef.grenade`'i `Game.server_spawn_grenade` ile host'ta fırlatır, çarpınca patlar, atanı da yaralar). Sticky Bomb ve Landmine `GrenadeAbility` + `GrenadeDef` bayraklarıyla; yapışkan bomba oyuncuya yapışırsa host'ta o oyuncunun konumunu izler; mayın durunca donar, `arm_time` sonra üstüne/yanına gelen (atan hariç, hasar alabilen) oyuncuyla patlar, oyuncu başına 1 tane.
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
├── Model (Node3D)                                  – başkalarının gördüğü gövde (sahibinde gizli)
├── Movement (Node)                 movement.gd     – Quake tarzı ivme, bhop, slide, crouch
├── PlayerInput (Node)              player_input.gd – sadece sahip client'ta aktif
├── NetSync (Node)                  player_net_sync.gd – hareket senkronu (sahip → host → diğerleri), interpolasyon, host hız kontrolü
├── Requests (Node)                 player_requests.gd – sahip → host istekleri (ateş, V, Q, loadout, düşme) + host kontrolleri
├── Status (Node)                   player_status.gd – kalkan, stun, itme, Adrenaline, kill ödülü, bıçak iadesi (host saati + sahibe RPC)
├── Effects (Node)                  player_effects.gd – herkesin gördüğü görseller: kalkan paneli, dürbün parlaması, ip, decoy, uzak tracer
├── StateSync (MultiplayerSynchronizer)             – health, is_alive, is_protected, loadout; authority host (1)
└── (Ability)                                       – aktif güç, loadout'tan kurulur

Bileşenler sahnede sabit düğümler: RPC'leri her peer'da aynı yolda (`Players/<id>/Requests` vb.). Dışarıdan erişim `player.status.server_stun(...)`, `player.effects.show_grapple(...)` gibi; silahlar `player.send_fire(...)` ile atar. Bileşenlerin `_ready`'si oyuncununkinden önce çalıştığı için oyuncuya düğüm ekleyen kurulum (`Effects.setup`) `Player._ready`'den çağrılır.
```

### Girdi, bakış ve kamera

- `PlayerInput.gather()` her physics tick'te bir `PlayerCommand` (RefCounted) üretir. `Movement` ve `Weapon` sadece bu komutu okur, böylece aşama 2'de aynı mantık ağdan gelen girdiyle de çalışır.
- Fare bakışı input anında uygulanır: yaw = gövdenin `rotation.y`, pitch = `Player.look_pitch`. Hassasiyet CS ile aynı birimde (`sens * 0.022` derece/count), FOV 4:3 yatay (CS kuralı).
- Physics interpolation açık (60 Hz tick, yüksek FPS'te akıcı). Kamera `top_level` ve interpolasyonu kapalı, `_process`'te yerleştirilir, bu yüzden fare gecikmesi olmaz.
- Atış `get_aim_origin()` (tick anındaki göz) + `get_aim_basis()` (bakış + recoil) ile yapılır, kamera pozisyonuyla değil.
- **Kamera hissi (`CameraFeel`, sadece sahibinde, sadece görsel):** hızla artan FOV kayması, head bob, iniş çökmesi (`Movement.landed`), slide'da alçalma + yan yatma, hasar sarsıntısı (host `_on_hurt`). Miktarlar `data/camera/default.tres`, her efekt `Settings.camera_*` (0–1) ile ölçeklenir. Nişan bunlardan etkilenmez.
- **Vuruş hissi:** host onayından sonra (`confirm_hit`) X hit marker (gövde/bacak beyaz, kafa kırmızı; `Settings.hit_marker_enabled`) ve sadece vuranın ekranında hasar sayısı (`DamageNumber`, Label3D). Mankenler artık kendi sayılarını göstermez. Hit-stop yok.

### Silah

- `Weapon` (taban): şarjör, ateş aralığı, şarjör değiştirme, recoil durumu. `HitscanWeapon._fire()` ray atar, `Hitbox`'a çarparsa `owner.take_hit(amount, zone, attacker_id) -> bool` çağırır (aşama 1'de yerel; aşama 2'de host'a taşınır).
- Recoil: `WeaponDef.recoil_pattern` her atışta bakışa eklenen derece değerleri; ateş bitince `recoil_recovery` hızıyla sıfıra döner. İlk mermi her zaman tam isabetli.
- Tracer ve mermi izi `ShotEffects` (sadece görsel) ile `Players` node'una eklenir. Uzak oyuncuların atışlarını host `_show_shot` ile yayar.

### Test haritası

`scenes/maps/test_range.tscn`: 15/30/55 m'de mankenler (`scenes/maps/target_dummy.tscn`, 70/100/175 HP), zıplama/crouch-jump kasaları (0,8 / 1,4 / 2,2 m), rampa ve platform, crouch tüneli (1,3 m), 10 m işaretli bhop pisti. Mankenler katman 2'de (oyuncu gibi), hitbox'ları katman 3'te. Oyuncu ve HUD haritada değil `game.tscn`'de; harita `SpawnPoints` (8 nokta) sağlar. Manken canı host'ta, can yazısı `Net.broadcast` ile herkeste; hasar sayısı sadece vuranın ekranında (`DamageNumber`). Mankenler sadece bu haritada.

### Hareket

- Quake/Source tarzı: yerde sürtünme + ivme. Hava: `air_speed_cap = 0` → serbest hava ivmesi (strafe ile yön değiştirme), ama hava ivmesi yatay hızı `max(mevcut hız, base × bhop_cap_mult)` üstüne çıkaramaz.
- **Bunny hop:** Yere değdiği frame'de zıplarsa sürtünme uygulanmaz → hız korunur. Zıplamada yatay hız `base × 1.3`'e kırpılır → sonsuz hızlanma yok.
- **Affedicilik:** jump buffer (`jump_buffer_time`) ve coyote time (`coyote_time`: kenardan düştükten kısa süre sonra zıplama).
- **Slide:** Yerdeyken ve hız eşiğin üstündeyken Ctrl (düz ileri) → kısa süreli düşük sürtünmeli kayma, alçak kapsül. Slide'dan zıplamada (`slide_jump_keeps_speed`) hız 1,3 tavanına kırpılmaz, korunur (kazanç yok; aynı tick'te başlayan slide sayılmaz).
- **Crouch:** Kapsül ve kamera alçalır, hız düşer. Havada crouch = crouch-jump (kasalara çıkış).
- Değerler `data/movement/standard.tres` (`MovementDef`, `ClassDef.movement`) dosyasında; koşu hızı sınıfın `move_speed` değeri. Hareket sadece sahip peer'da çalışır.

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

Aksiyon isimleri (`project.godot` içinde, fiziksel tuş kodu ile): `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `crouch` (Ctrl: eğil; koşarken basınca slide), `sprint` (Shift), `respawn` (T, sadece test range), `fire`, `secondary`, `ability`, `reload`, `interact`, `melee`, `weapon_primary`, `weapon_secondary`, `class_menu`, `scoreboard`, `pause_menu` (Esc).

## Kodlama kuralları

- Statik tip her yerde. `@onready var camera: Camera3D = $Head/Camera3D`.
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
