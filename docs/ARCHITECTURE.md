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
│   ├── weapons/             # WeaponDef .tres
│   └── abilities/           # AbilityDef .tres
├── scripts/
│   ├── defs/                # class_def.gd, weapon_def.gd, ability_def.gd
│   ├── player/              # player.gd, movement.gd, player_input.gd, hitbox.gd
│   ├── weapons/             # weapon.gd (taban), hitscan_weapon.gd, projectile_weapon.gd, melee_weapon.gd, thrown_weapon.gd
│   ├── abilities/           # ability.gd (taban), grapple.gd, dash.gd, shield.gd ...
│   ├── pickups/             # pickup.gd, airdrop.gd
│   └── ui/                  # hud.gd, scoreboard.gd, loadout_menu.gd, main_menu.gd
├── scenes/
│   ├── main.tscn            # Giriş noktası: ana menü
│   ├── player/player.tscn
│   ├── weapons/             # Silah başına sahne (görsel + script)
│   ├── projectiles/
│   ├── pickups/
│   ├── ui/
│   └── maps/
│       ├── test_range.tscn  # Test haritası + hedef mankenleri
│       └── mall/            # İlk gerçek harita
└── assets/
    ├── models/
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

### Senkronizasyon

| Veri | Yöntem | Sıklık |
| --- | --- | --- |
| Oyuncu pozisyonu, bakış yönü, hareket durumu | Sahibinden host'a, host'tan herkese; `unreliable_ordered` RPC | 30 Hz |
| Diğer oyuncuların görüntüsü | Gelen state'ler arasında interpolasyon (~100 ms geriden) | Her frame |
| Ateş etme | Client → host `request_fire(origin, dir, fire_time)` | Olay bazlı, reliable |
| Hasar, ölüm, skor | Host → herkese | Olay bazlı, reliable |
| Maç durumu | Host → herkese (katılana tam snapshot) | Olay bazlı + katılışta |

### Vuruş tespiti (hitscan)

1. Client ateş eder: anında yerel efekt (namlu ateşi, ses, mermi izi). Hasar göstergesi **beklenir**.
2. Client host'a `request_fire` gönderir.
3. Host, atış zamanına göre diğer oyuncuların hitbox'larını geri sarar (lag compensation), raycast yapar, hasarı uygular.
4. Host sonucu yayar → hit marker, hasar, kill feed.

**Lag compensation:** Host her physics tick'te her oyuncunun hitbox pozisyonunu halka tampona (son ~500 ms) kaydeder. 2. aşamada basit hali (geri sarmasız) kurulur, altyapı buna uygun tasarlanır; geri sarma 3. aşama sonunda eklenir.

**Hile koruması:** Arkadaş arası oyun, ağır anti-cheat yok. Host sadece bariz tutarsızlıkları reddeder (ateş hızı sınırı, aşırı hız, ölüyken ateş).

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
├── Head (Node3D)                                   – kamera yüksekliği, eğilmede alçalır
│   ├── Camera3D
│   └── WeaponHolder (Node3D)                       – aktif silah sahnesi buraya eklenir
├── Hitboxes (Node3D)
│   ├── HeadHitbox (Area3D)         hitbox.gd       – zone = HEAD
│   ├── BodyHitbox (Area3D)                         – zone = BODY
│   └── LegHitbox (Area3D)                          – zone = LEG
├── Movement (Node)                 movement.gd     – Quake tarzı ivme, bhop, slide, crouch
├── PlayerInput (Node)              player_input.gd – sadece sahip client'ta aktif
└── AbilitySlot (Node)                              – aktif güç
```

### Hareket

- Quake/Source tarzı: yerde sürtünme + ivme, havada sınırlı hava ivmesi (strafe ile yön değiştirme).
- **Bunny hop:** Yere değdiği frame'de zıplarsa sürtünme uygulanmaz → hız korunur. Yatay hız üst sınırı `max_speed * 1.3` → sonsuz hızlanma yok.
- **Slide:** Yerdeyken ve hız eşiğin üstündeyken Ctrl → kısa süreli düşük sürtünmeli kayma, alçak kapsül.
- **Crouch:** Kapsül ve kamera alçalır, hız düşer. Havada crouch = crouch-jump (kasalara çıkış).
- Değerler `movement.gd` içinde `@export` ve sınıfın `move_speed` çarpanıyla ölçeklenir.

## Fizik katmanları

| Katman | İsim | İçerik |
| --- | --- | --- |
| 1 | world | Harita geometrisi |
| 2 | player | Oyuncu hareket kapsülleri |
| 3 | hitbox | Oyuncu hitbox Area3D'leri (raycast hedefi) |
| 4 | projectile | Fiziksel mermiler |
| 5 | pickup | Pickup ve airdrop alanları |
| 6 | grapple | Kanca takılabilen yüzeyler |

Hitscan raycast maskesi: `world | hitbox`.

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
