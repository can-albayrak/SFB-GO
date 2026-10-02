# SFB:GO – Assets

İlk harita (terk edilmiş AVM, aşama 7–8) için hazır model ve doku ihtiyaç listesi ve lisans takibi. Tasarım için `GDD.md`, harita kuralları için GDD "Harita tasarım kuralları".

## Kurallar

- **Binayı biz yaparız:** duvar, zemin, katlar, kolonlar, korkuluklar, merdivenler, yürüyen merdiven gövdesi, dükkân cepheleri ve kepenkler, çatı. Blockout'tan çıkar, aşama 8'de Blender'da sadeleştirilip dokulanır. Hazır modeller sadece **prop** için.
- **Lisans:** Önce **CC0**. CC-BY olur ama kredi zorunlu. Release zip'i arkadaşlara dağıtmak hukuken dağıtım sayılır. Lisansı belirsiz, "Standard"/"editorial" ya da sadece Unity'ye özel lisanslı hiçbir şey alınmaz.
- **Her indirileni aşağıdaki "Kullanılanlar" tablosuna yaz:** kaynak, yazar, lisans, dosya.
- **Siper ölçüsü oynanışı belirler:** Blockout bu boylarla kurulur, bulunan model Blender'da bu boya ölçeklenir.
  - **Yarım siper:** ~1–1,2 m, eğilince saklanır.
  - **Tam siper:** ~2 m.
  - **Yok:** dekor, collision'sız (GDD kuralı).
- **Performans (GTX 1050 Ti):**
  - Prop başına birkaç bin üçgeni geçmesin.
  - Aynı modeli tekrar kullan (instance).
  - Collision sadece basit kutular.
  - Dokular 512–1024 px.
- **Format:** `.glb`, 1 birim = 1 m. Blender'da ölçek ve yön düzeltilir (+Y ileri = Godot -Z). Ham indirmeler `private_assets/` altında kalır; repoya sadece oyunda kullanılan `.glb` ve dokular girer.

## Kaynaklar

| Kaynak | Ne var | Lisans |
| --- | --- | --- |
| Kenney (kenney.nl) | Mobilya, şehir, bina kitleri; çok düşük poligon | CC0 |
| Quaternius (quaternius.com) | Bina, araba, mobilya, sokak paketleri | CC0 |
| Poly Pizza (poly.pizza) | Aranabilir low-poly model arşivi | Çoğu CC0, bazıları CC-BY |
| Poly Haven (polyhaven.com) | Kaliteli model, fotoğraf dokusu, HDRI | CC0 |
| ambientCG (ambientcg.com) | Fotoğraf tabanlı PBR dokular | CC0 |
| itch.io | "PSX" / "low poly" ücretsiz paketler (2000'ler stiline en yakın) | Pakete göre |
| Sketchfab | Her şey; "Downloadable" + CC0/CC-BY filtresiyle ara | Modele göre |
| OpenGameArt | Karışık | Modele göre |

## İhtiyaç listesi

Adet = farklı model sayısı (yerleştirirken tekrar kullanılır). Durum: `aranıyor` / `bulundu` / `oyunda`.

### Atrium (Wolf, merkez)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Kuru süs havuzu / fıskiye | 1 | Yarım | Sketchfab, Poly Pizza | aranıyor |
| Kiosk / stant | 2–3 | Tam | Kenney, Sketchfab | aranıyor |
| Büyük saksı | 2 | Yarım | Kenney, Quaternius | aranıyor |
| Bank | 1–2 | Yok | Kenney, Quaternius | aranıyor |
| Yürüyen merdiven (görsel; rampa collision'ı biz yaparız) | 1 | – | Sketchfab | aranıyor |
| Yön tabelası / AVM haritası | 1 | Yok | Kendimiz (kutu + doku) | aranıyor |
| Asılı reklam bezi | 2 | Yok | Kendimiz (düzlem + doku) | aranıyor |

### Dükkânlar (Bear, Volcano; 5–6 dükkân, her biri farklı tema)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Kasa bankosu | 1–2 | Yarım | Kenney Furniture, Sketchfab | aranıyor |
| Raf ünitesi (market / eczane) | 2 | Tam | Kenney, Quaternius | aranıyor |
| Elbise askılığı | 1 | Yok | Sketchfab, itch.io | aranıyor |
| Manken | 1–2 | Yok | Sketchfab, Poly Pizza | aranıyor |
| Teşhir masası | 1 | Yarım | Kenney | aranıyor |
| CRT televizyon / TV duvarı | 1–2 | Yok | itch.io (PSX), Sketchfab | aranıyor |
| CD / DVD rafı | 1 | Tam | Sketchfab, itch.io | aranıyor |
| Kafe masa + sandalye | 1 set | Yarım | Kenney Furniture | aranıyor |
| Alışveriş arabası | 1 | Yok | Poly Pizza, Sketchfab | aranıyor |
| Karton kutular | 2–3 | Yarım | Kenney, Quaternius | aranıyor |

### Yemek katı koridoru (Hawk, uzun görüş hattı)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Masa + sandalye seti | 1–2 | Yarım (kırıcı siper) | Kenney Furniture | aranıyor |
| Yemek standı bankosu | 2 | Tam | Sketchfab, Kenney | aranıyor |
| Çöp kutusu | 1 | Yok | Kenney, Quaternius | aranıyor |
| Işıklı menü panosu | 1 | Yok | Kendimiz (kutu + doku) | aranıyor |

### Servis koridoru ve yükleme alanı (Bear, Volcano)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Ahşap sandık | 2 | Yarım ve tam | Kenney, Quaternius | aranıyor |
| Palet | 1 | Yok | Kenney | aranıyor |
| Çöp konteyneri | 1 | Tam | Quaternius, Poly Pizza | aranıyor |
| Tekerlekli kafes | 1 | Yarım | Sketchfab | aranıyor |
| Boru / kablo demeti | 2 | Yok | Kenney, kendimiz | aranıyor |
| Kepenkli kapı | 1 | Duvar | Kendimiz | aranıyor |

### Otopark (Wolf, Hawk, açık alan)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Araba (hurda, 2000'ler) | 3 | Yarım | Quaternius, Kenney Car Kit, itch.io PSX | aranıyor |
| Beton bariyer | 1 | Yarım | Kenney, Poly Pizza | aranıyor |
| Aydınlatma direği | 1 | Yok | Kenney City Kit | aranıyor |
| Otopark gişesi | 1 | Tam | Sketchfab | aranıyor |
| Lastik yığını | 1 | Yarım | Poly Pizza | aranıyor |

### Çatı (Hawk, Cheetah)

| Prop | Adet | Siper | Nereden | Durum |
| --- | --- | --- | --- | --- |
| Klima ünitesi | 2 | Yarım ve tam | Kenney, Sketchfab | aranıyor |
| Havalandırma bacası | 1 | Yarım | Kenney | aranıyor |
| Su tankı | 1 | Tam | Sketchfab | aranıyor |
| Anten / uydu çanağı | 1 | Yok | Kenney | aranıyor |
| Merdiven (ladder) | 1 | Tırmanma | Kendimiz | aranıyor |

### Distopik / 2000'ler detayları

| Prop | Adet | Nereden | Durum |
| --- | --- | --- | --- |
| Ankesörlü telefon | 1 | itch.io PSX, Sketchfab | aranıyor |
| ATM | 1 | Sketchfab | aranıyor |
| İçecek otomatı | 1 | Kenney, itch.io | aranıyor |
| Neon tabela | 2 | Kendimiz (düzlem + emisyon) | aranıyor |
| Hoparlör (anons) | 1 | Kenney, Sketchfab | aranıyor |
| Sahte marka reklam panosu / poster | 6–10 doku | Kendimiz çiziyoruz | aranıyor |

### Dokular (ambientCG / Poly Haven, CC0, fotoğraf tabanlı)

| Yüzey | Dokular | Durum |
| --- | --- | --- |
| Zemin | Terrazzo / mozaik (AVM), seramik karo (yemek katı), halı (giyim), beton (servis), asfalt + park çizgisi (otopark), çakıl / membran (çatı) | aranıyor |
| Duvar | Kirli sıva, alçıpan, fayans, tuğla (dış cephe) | aranıyor |
| Metal ve cam | Paslı sac, kepenk metali, kirli cam | aranıyor |
| Kir katmanları | Su lekesi, yosun, grafiti | aranıyor |

**Toplam:** ~40–50 farklı model, 15–20 doku.

## Adaylar (indirilip Blender'da kontrol edilecek)

| Model | Lisans | Ne için | Kontrol edilecek |
| --- | --- | --- | --- |
| [Suburban Mall 1980 – novusod (Sketchfab)](https://sketchfab.com/3d-models/suburban-mall-1980-edcfb6e9dc47439491ce865b8e9f54b3) | CC-BY (kredi zorunlu: "Suburban Mall 1980" by novusod) | Dış cephe / genel kütle referansı, belki başlangıç modeli; 80'ler AVM silüeti, Caldor ve Sears ana mağaza blokları | 14,1k üçgen: büyük ihtimalle sadece dış kabuk. İç mekân var mı, gerçek ölçek ne (hedef bina ~64 × 48 m), parçalar ayrı mı. Ham dosya `private_assets/` altına. |

## Silah adayları (2026-10-02, Sketchfab taraması)

Hepsi indirilebilir ve **CC-BY** (kredi zorunlu, krediler "Kullanılanlar" tablosuna). Öncelik dokulu PS1/PSX modeller. İndirmek için Sketchfab hesabı gerekir; ham dosyalar `private_assets/weapons/` altına. Blender'da ölçek, yön ve tutuş noktası düzeltilir.

**Ana kaynak Falxxx'in "PS1 Style" serisi:** AK, AWP, Grenade Launcher, Rocket Launcher, Railgun aynı elden, tarz tutarlı.

| Slot | Seçim | Yazar | Üçgen | Yedek aday |
| --- | --- | --- | --- | --- |
| Assault Rifle | [PS1 style AK-47](https://sketchfab.com/models/c05cea3e51484331bfb4c75348d659ef) | Falxxx | 657 | [Ak47 [psx]](https://sketchfab.com/models/ca2a6ae2fe154c76822c0982bd473696) (radint20, 972) |
| Burst Rifle | [PS1-style Steyr AUG](https://sketchfab.com/models/0d5f437f7193404ea0f030651421434f) | andrewwhiskin | 419 | [PS1-style FAMAS](https://sketchfab.com/models/8d7ad8c8b23d406da3c3b05722f4ef33) (andrewwhiskin, 270) |
| LMG | [Low-Poly M249 SAW](https://sketchfab.com/models/76011c365636451c90a8e3a46c2d8ca5) (dokusuz, Blender'da dokulanır) | TastyTony | 12281 | [Low-Poly RPK](https://sketchfab.com/models/acdc6fe399514c41aa4130f8044875fb) (TastyTony, 6964) |
| Heavy Rifle | [PS1 Style AWP Sniper](https://sketchfab.com/models/da7f6dcaa2b2477f97ccdc641e6fc3b6) | Falxxx | 618 | [PS1-style M24](https://sketchfab.com/models/548a84920414451a8471c067a7c8a9b0) (andrewwhiskin, 270) |
| Marksman Rifle | [SVD](https://sketchfab.com/models/1ac10d61438844a9a69d46baa4dcd72b) | thebradqq | 2924 | [Low-poly Dragunov SVD](https://sketchfab.com/models/79216d567ce34644a3f3f0cd4bc8e80a) (veightyfive, 5296) |
| SMG | [Mac10 [psx]](https://sketchfab.com/models/266c6fcda29546fd8de6201295c23695) | radint20 | 1428 | [H&K MP5 PSX Style](https://sketchfab.com/models/45b7b8af512c4d048f8fd374362d7483) (DanielPoollanco, 584) |
| Dual Pistols | [PS1-style Beretta M9](https://sketchfab.com/models/78e8295933594a6a9b5db4ec72b54211) | andrewwhiskin | 710 | [PS1-style Makarov](https://sketchfab.com/models/9686026bf0f54add8ec94053a86276be) (andrewwhiskin, 426) |
| Pistol (yedek) | [Glock [psx]](https://sketchfab.com/models/e72e230edbfe40d9ba249584bf1f836b) | radint20 | 464 | [Colt M1911 PS1/PSX](https://sketchfab.com/models/f9fc36a1f07b47faaadb761702f703b0) (Colin.Greenall, 806) |
| Shotgun | [Remington PS1/PSX](https://sketchfab.com/models/89afc8d893ba479b9dcf1ee39e049bcd) | Colin.Greenall | 724 | [M1897 [psx]](https://sketchfab.com/models/40a3e3c025dc4e44a0b35f2653a3b5b3) (radint20, 836) |
| Grenade Launcher | [PS1 Style Grenade Launcher](https://sketchfab.com/models/0532a58572124fe1b31ecec7a9aff462) | Falxxx | 772 | – |
| Railgun | [PS1 Style Railgun](https://sketchfab.com/models/057d8e6263df484dbcc767ff0aa26be7) | Falxxx | 622 | – |
| Minigun | [Low-Poly M134 Minigun](https://sketchfab.com/models/eed0c95de51b4895a48c5729582732cc) (dokusuz, Blender'da dokulanır) | TastyTony | 12931 | [Minigun](https://sketchfab.com/models/6f70d536bd404eb8a3c9db54022c85c1) (Iliya_Luchkiy, 1119, kontrol edilecek) |
| Rocket Launcher | [PS1 Style Rocket Launcher](https://sketchfab.com/models/a95a9d11c2904f38918507e77df11dc3) | Falxxx | 448 | – |
| Knife (V) | [Combat Knife](https://sketchfab.com/models/48e00da7aeb94530a5d0e0c3d58ca274) | San.Dro | 1200 | [PSX Rusted Knife](https://sketchfab.com/models/81f11a0d53a84cc88d431dd6246dcc7e) (Shazly, 132) |
| Throwing Knife | [Throwing Knife](https://sketchfab.com/models/f13c505160e34193a98fb9a092489e0a) | _NotyGuy_ | 506 | – |
| Sledgehammer | [Sledge Hammer](https://sketchfab.com/models/1ba18e262c054f8687502f2ef98da9c3) | MaX3Dd | 702 | [Rusty Sledgehammer Photoscan](https://sketchfab.com/models/0d4f90b84b1f43ac9ade0eda770a1626) (evan4129, 4218) |
| Chainsaw | [Low Poly Chainsaw](https://sketchfab.com/models/aae9bb6be2ff455bb7a2658f09c8703c) | jonniemadeit | 114 | [Ps1 low-poly chainsaw](https://sketchfab.com/models/507b09788e6c403690274a32d1ffe023) (Madeleinone, 122) |
| Frag Grenade | [Grenade](https://sketchfab.com/models/8d6b63e11b464bb2a10cdbb0a082b5e7) (poligon azaltılır) | Chpndl | 5610 | Mevcut Blender modeli |
| Flashbang | [Flashbang](https://sketchfab.com/models/f4a48db9bd54420696ed282af9574dd9) (poligon azaltılır) | Chpndl | 7178 | Mevcut Blender modeli |

**Bulunamayan, Blender'da biz yaparız:** Claws (Bear), Sticky Bomb, Landmine, Grapple, Bear'ın kalkanı, birinci şahıs kollar.

**Oyunlardan sökülmüş modeller (Can'ın kararı, 2026-10-02):** Oyun sadece 4–5 arkadaş arasında oynandığı için kullanılabilir. Şartlar: repo ve Release'ler gizli kalır, oyun hiçbir yerde herkese açık paylaşılmaz, "Kullanılanlar" tablosunda `ripped` diye işaretlenir (ileride açık paylaşım olursa hangilerinin değişeceği belli olsun).
**Elenenler:** Quaternius silah paketleri (dokusuz, düz renk; tarzımıza uymuyor).

**Ek bulgu (harita için):** wersaus33'ün "PS1 Low Poly" serisi CC-BY ve tarz olarak uygun: içecek otomatı, klima, Toyota Corolla, VW Golf, Iveco ve beyaz minibüsler (otopark).

## İncelenen ama kullanılamayanlar

| Model | Neden olmaz |
| --- | --- |
| [Mall – Pauline (Sketchfab)](https://sketchfab.com/3d-models/mall-53068925c4fa4fc18e5c3bb3936af27b) | İndirilemiyor, lisans yok (yazar işyerinde yaptığı için paylaşamadığını yazmış). Tek bir mobil oyun odası, 54k üçgen. Sadece görsel referans olarak bakılabilir. |

## Kullanılanlar (krediler)

Oyuna giren her dış asset buraya. CC-BY olanlar Release'teki `CREDITS` dosyasına da girer.

| Asset | Dosya | Kaynak (link) | Yazar | Lisans |
| --- | --- | --- | --- | --- |
| – | – | – | – | – |
