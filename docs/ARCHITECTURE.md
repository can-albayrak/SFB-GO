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
├── .mcp.json                # Claude Code için Godot MCP ayarı
├── docs/                    # GDD, ARCHITECTURE, PROGRESS (.gdignore: Godot import etmez)
├── addons/                  # Godot eklentileri (şimdilik boş)
├── autoload/                # Global singleton'lar
│   ├── events.gd            # Sinyal otobüsü
│   ├── net.gd               # Bağlantı, oyuncu kaydı
│   ├── match.gd             # Maç durumu, skor, spawn (sadece host karar verir)
│   └── settings.gd          # Kullanıcı ayarları (user://settings.cfg)
├── data/
│   ├── classes/             # ClassDef .tres (hawk.tres, bear.tres ...)
│   ├── movement/            # MovementDef .tres (standard.tres: ivme, zıplama, bhop, slide)
│   ├── weapons/             # WeaponDef .tres
│   └── abilities/           # AbilityDef .tres
├── scripts/
│   ├── defs/                # class_def.gd, weapon_def.gd, ability_def.gd, movement_def.gd
│   ├── game/                # game.gd (maç sahnesi: harita, spawn, respawn), lag_compensator.gd
│   ├── player/              # player.gd, movement.gd, player_input.gd, player_command.gd, hitbox.gd
│   ├── maps/                # target_dummy.gd vb. harita scriptleri
│   ├── weapons/             # weapon.gd (taban), hitscan_weapon.gd, projectile_weapon.gd, melee_weapon.gd, thrown_weapon.gd
│   ├── abilities/           # ability.gd (taban), grapple.gd, dash.gd, shield.gd ...
│   ├── pickups/             # pickup.gd, airdrop.gd
│   └── ui/                  # hud.gd, crosshair.gd, scoreboard.gd, kill_feed.gd, main_menu.gd (loadout_menu.gd aşama 4)
├── scenes/
│   ├── main.tscn            # Giriş noktası: ana menü (isim, Host, Join, Test Range)
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
| `Settings` | FOV, hassasiyet, crosshair, tuş atamaları, grafik ayarları | Yerel |

## Ağ modeli

**Prensip:** Her oyuncu kendi hareketini kendisi hesaplar (akıcı his için), ama **hasar, ölüm, skor, pickup, airdrop ve spawn kararlarını sadece host verir.**

### Otorite

- Her `Player` node'unun multiplayer authority'si kendi peer id'si → hareket ve input o client'ta.
- `health`, `kills`, `deaths`, `is_alive`, aktif buff'lar → host'ta tutulur, client'lara yayılır. Client bunları asla kendi değiştirmez.
- Oyuncular `MultiplayerSpawner` ile spawn edilir (host spawn eder, herkeste çoğalır).

### Oturum akışı (aşama 2)

- `scenes/game.tscn` (`/root/Game`, `scripts/game/game.gd`): maç sahnesi. `Net.map_path` haritasını `Map` adıyla yükler (her peer'da aynı yol), `HUD`, `Players` ve `PlayerSpawner` içerir. Haritalar sadece geometri + `SpawnPoints` (Marker3D) + harita nesneleri (mankenler).
- **Host:** `Net.host_game()` → ENet server (port 7777) → `game.tscn`. **Client:** `Net.join_game()` → bağlanınca `_request_register(name)` → host `_welcome(map_path)` ile cevaplar → client `game.tscn` yükler → `Game._request_spawn()`.
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
| Ölüm, yeniden doğma, hit onayı, uzak tracer | Host → `Net.broadcast` (`_announce_death`, `_respawn_at`, `_show_shot`) / `confirm_hit` sadece atana | Olay bazlı |

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
- **Ateş hızı:** Bütçe tabanlı (`fire_interval × 0,95`, 0,25 sn birikme payı): ağ dalgalanmasında toplu gelen atışlar kaybolmaz, sürekli fazla hız reddedilir.
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

`AbilityDef` benzer: `id`, `display_name`, `cooldown`, `duration`, `scene`.

Sabit kurallar (kafa çarpanı istisnası gibi) `WeaponDef` alanlarıyla ifade edilir; örn. Heavy Rifle'da `headshot_mult = 1.0, leg_mult = 1.0, damage = 999`.

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
├── StateSync (MultiplayerSynchronizer)             – health, is_alive; authority host (1)
└── AbilitySlot (Node)                              – aktif güç (aşama 4)
```

### Girdi, bakış ve kamera

- `PlayerInput.gather()` her physics tick'te bir `PlayerCommand` (RefCounted) üretir. `Movement` ve `Weapon` sadece bu komutu okur, böylece aşama 2'de aynı mantık ağdan gelen girdiyle de çalışır.
- Fare bakışı input anında uygulanır: yaw = gövdenin `rotation.y`, pitch = `Player.look_pitch`. Hassasiyet CS ile aynı birimde (`sens * 0.022` derece/count), FOV 4:3 yatay (CS kuralı).
- Physics interpolation açık (60 Hz tick, yüksek FPS'te akıcı). Kamera `top_level` ve interpolasyonu kapalı, `_process`'te yerleştirilir, bu yüzden fare gecikmesi olmaz.
- Atış `get_aim_origin()` (tick anındaki göz) + `get_aim_basis()` (bakış + recoil) ile yapılır, kamera pozisyonuyla değil.

### Silah

- `Weapon` (taban): şarjör, ateş aralığı, şarjör değiştirme, recoil durumu. `HitscanWeapon._fire()` ray atar, `Hitbox`'a çarparsa `owner.take_hit(amount, zone, attacker_id) -> bool` çağırır (aşama 1'de yerel; aşama 2'de host'a taşınır).
- Recoil: `WeaponDef.recoil_pattern` her atışta bakışa eklenen derece değerleri; ateş bitince `recoil_recovery` hızıyla sıfıra döner. İlk mermi her zaman tam isabetli.
- Tracer ve mermi izi `ShotEffects` (sadece görsel) ile `Players` node'una eklenir. Uzak oyuncuların atışlarını host `_show_shot` ile yayar.

### Test haritası

`scenes/maps/test_range.tscn`: 15/30/55 m'de mankenler (`scenes/maps/target_dummy.tscn`, 70/100/175 HP), zıplama/crouch-jump kasaları (0,8 / 1,4 / 2,2 m), rampa ve platform, crouch tüneli (1,3 m), 10 m işaretli bhop pisti. Mankenler katman 2'de (oyuncu gibi), hitbox'ları katman 3'te. Oyuncu ve HUD haritada değil `game.tscn`'de; harita `SpawnPoints` (8 nokta) sağlar. Manken canı host'ta, hasar sayıları `Net.broadcast` ile herkeste görünür.

### Hareket

- Quake/Source tarzı: yerde sürtünme + ivme, havada sınırlı hava ivmesi (strafe ile yön değiştirme).
- **Bunny hop:** Yere değdiği frame'de zıplarsa sürtünme uygulanmaz → hız korunur. Yatay hız üst sınırı `max_speed * 1.3` → sonsuz hızlanma yok.
- **Slide:** Yerdeyken ve hız eşiğin üstündeyken Ctrl → kısa süreli düşük sürtünmeli kayma, alçak kapsül.
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

Aksiyon isimleri (`project.godot` içinde, fiziksel tuş kodu ile): `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `crouch`, `walk`, `fire`, `secondary`, `ability`, `reload`, `interact`, `melee`, `weapon_primary`, `weapon_secondary`, `class_menu`, `scoreboard`, `pause_menu` (Esc).

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
