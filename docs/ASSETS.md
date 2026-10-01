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

## İncelenen ama kullanılamayanlar

| Model | Neden olmaz |
| --- | --- |
| [Mall – Pauline (Sketchfab)](https://sketchfab.com/3d-models/mall-53068925c4fa4fc18e5c3bb3936af27b) | İndirilemiyor, lisans yok (yazar işyerinde yaptığı için paylaşamadığını yazmış). Tek bir mobil oyun odası, 54k üçgen. Sadece görsel referans olarak bakılabilir. |

## Kullanılanlar (krediler)

Oyuna giren her dış asset buraya. CC-BY olanlar Release'teki `CREDITS` dosyasına da girer.

| Asset | Dosya | Kaynak (link) | Yazar | Lisans |
| --- | --- | --- | --- | --- |
| – | – | – | – | – |
