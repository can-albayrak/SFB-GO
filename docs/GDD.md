# SFB:GO – Game Design Document

Son güncelleme: 2026-10-01

## Genel bakış

Arkadaşlar arasında oynanacak, en fazla 10 kişilik, sınıf tabanlı bir FPS. His olarak CS 1.6'nın cilalı ve biraz daha akıcı hali; Straftat kadar hızlı değil. **Oyun içindeki her şey İngilizce.**

- **Motor:** Godot 4.4+ (GDScript)
- **Oyuncu sayısı:** 2–10 (genelde 4–6 kişi oynanır; haritalar 4–6 kişiye göre ölçeklenir, 10 kişiyi de kaldırır)
- **İlk mod:** Free-for-all deathmatch (takım yok)
- **Hedef donanım:** GTX 1050 Ti'da 1080p, 100+ FPS
- **Tarz:** Distopik, 2000'lerin başı estetiği, hafif tuhaf (freaky) ama temiz görüntü. Referans his: 2000'ler PlayStation oyunu, Buckshot Roulette distopikliği.
- **Görsel referans (2026-10-01):** Erken 2000'ler PS2 FPS'leri: düşük poligon, gerçekçi ama yıkanmış dokular, karanlık ve soğuk (gece mavisi, gri, beton), turuncu yok; tuhaflık gerilmiş gri tonlu yüz dokularından gelir. Çocuksu ve modern değil. **HUD (Red Faction / TimeSplitters dönemi):** sol altta çerçeveli ince can ve güç barları, sağ altta silah silüetleri ve küçük mermi sayısı, dört köşeli nişangah, gölgeli düz yazı. HUD'daki silah silüetleri yer tutucu: silah modelleri bitince modellerden render edilmiş ikonlar konur. **Menüler:** sade ve profesyonel; nötr koyu gri paneller, beyaz yazı, seçili satır beyaz bar, renkli tema yok. Menü arka planı oyundaki AVM'nin 3D kamera turu (aşama 8). Taslaklardaki çizilmiş sahneler sadece yer tutucu; oyunun grafik seviyesi referans görsellerdeki PS2 oyunları gibi olacak. Devlet/propaganda teması yok. Taslak: Claude Design "SFB:GO HUD ve Menü"; ana menüde isim alanı "SFB CITIZEN ID".

## Oyun modu ve maç kuralları

Herkes tek başına savaşır; kill hedefine ilk ulaşan ya da süre bittiğinde en çok kill'i olan kazanır.

| Kural | Değer |
| --- | --- |
| Kill hedefi | Host seçer, varsayılan 20 (4–6 kişiye göre) |
| Süre limiti | Host seçer, varsayılan 10 dk |
| Kill ödülü | Her kill'de **+20 can** (maksimumu geçmez) ve elindeki silaha **+15 mermi** (şarjörü geçmez). Airdrop silahlarına (Railgun vb.) mermi eklenmez. |
| Respawn | Otomatik, 3 sn sonra, düşmanlara en uzak spawn noktasında |
| Spawn koruması | 2 sn hasar almaz, ateş edince biter |
| Geç katılma | Maç ortasında katılınabilir, sıfır kill ile başlanır |
| Host çıkarsa | Maç biter, herkes menüye döner |

**Arayüz:**

- Tab ile skor tablosu (kill, death, sıralama)
- Köşede kill feed (kim, kimi, hangi silahla)
- Lider oyuncunun üstünde taç ikonu
- Ölüm ekranı (3 sn): öldüren, silahı ve kalan canı görünür; sınıf menüsü açık
- Maç sonu ödülleri: en çok ölen, en çok bıçak kill'i, en uzun kafa vuruşu, en çok kendini patlatan
- Anonslar: distopik hoparlör sesi ("Double Kill", "Killing Spree", "Airdrop Incoming"). **Anons metinleri ve sesleri Can hazırlar**; silah ve animasyon sesleri ayrı iş.

**Lobi:** Host kill hedefi, süre ve haritayı seçer. Oyuncular kendi isimlerini girer.

- **Bağlanma:** Host'un Tailscale IP'si bir kez girilir ve kaydedilir; sonraki açılışlarda "Last host" ile tek tıkla bağlanılır.
- **Basit lobi:** Oyuncu listesi, her oyuncunun adı, yüz seçimi ve "hazır" durumu görünür; host ayarları yapar ve "Start" der. Maç ortasında katılma (geç katılma) yine mümkün. Sohbet, takım/renk seçimi gibi ek özellikler yoktur.
- **Yüz ve sınıf seçimi:** Her oyuncu lobide ilk doğuşu için **yüzünü ve sınıfını** (loadout) seçer. Ölünce ikisini de değiştirebilir (ölüm ekranındaki menü). Geç katılan oyuncuya katılma sırasında yüz + sınıf sorulur, seçince maça girer.

## Temel oynanış

| Konu | Karar |
| --- | --- |
| Hareket | Hafif bunny hop (zamanlı zıplamada hız korunur, sonsuz hızlanma yok), crouch, slide (koşarken crouch). Düşme hasarı yok. |
| Nişan | Nişan (ADS) modu yok, yalnızca Hawk'ın dürbünü |
| Hasar | Kafa 2x, bacak 0,75x. Hawk Heavy Rifle kafa ve gövdeden tek atış (bacak hariç). |
| Mermi tipi | Mermili silahlar hitscan; bomba, roket, grenade launcher ve fırlatma bıçağı fiziksel mermi |
| Geri tepme | Her silahta sabit, öğrenilebilir desen; CS'ten belirgin şekilde hafif |
| Can | Yenilenme yok, yalnızca Health pickup |
| Mermi | Yedek mermi sınırsız, sadece şarjör değiştirilir (airdrop silahı hariç) |
| Ayak sesi | Yön ve konum anlaşılacak kadar belirgin (aşırı vurgulanmaz). **Ctrl ile eğilip yürürken** ses çok az çıkar. |
| Hızlı yakın dövüş | Herkese `V` ile bıçak: 25 hasar, ~1,5 m menzil, 0,8 sn bekleme. Bear'da `V` = kısa tekme (az hasar, geri itme). |
| Yedek silah | Bear hariç herkese tek tip tabanca. Bear'a 3 Throwing Knife. |
| FOV ve fare | Varsayılan FOV 90 (80–110), fare hassasiyeti, crosshair özelleştirme (renk, boyut, boşluk) |

### Hareket hissi (hedef)

Hedef: **Apex gibi akıcı, CS gibi kesin**; savaş hiç durmasın. Aşağıdakiler tasarım kararı, sayıları oynadıkça `data/movement/` altında ayarlanır (kodda sabit yok).

| Konu | Karar |
| --- | --- |
| Yerde frenleme | CS tarzı: hızlı ve sert durma (counter-strafe), kaygan değil |
| Hız cezası | **Kademeli:** hız arttıkça isabet düşer. Net bir eşik yok; koşarken ateş imkânsız değil, sadece daha dağınık. Sınıfa göre ölçeklenir (Cheetah SMG koşarken isabetli kalır). |
| Slide sonrası zıplama | Hız **korunur** (kazanç yok). Zamanlı slide + zıplama sürtünmeye hız kaybettirmez. |
| Hava kontrolü | Şimdilik **serbest** hava ivmesi (strafe ile yön değiştirme), yatay hız tavanı (`max_speed * 1.3`) kalır. Oynadıkça güncellenecek. |
| Affedicilik | Coyote time (kenardan düştükten kısa süre sonra zıplama kabul edilir) ve jump buffer (yere değmeden hemen önce basılan zıplama saklanır) |
| Kapsam dışı | Apex'in tap-strafe, wall-bounce, superglide gibi öğrenmesi zor teknikleri alınmaz |

**Kamera ve his:** Hepsi hafif tutulur ve ayarlardan kapatılabilir/azaltılabilir; nişan tutarlılığı bozulmaz.

| Konu | Karar |
| --- | --- |
| FOV kayması | Hızlandıkça FOV birkaç derece açılır (başlangıç ~+3–5°), slide ve tırmanışta belirgin. Ayarlardan kapatılır. |
| Head bob | Çok az; ayarlardan kapatılır veya azaltılır. |
| İniş | Zıplayıp inince küçük bir kamera çökmesi (iniş hissi). |
| Slide kamerası | Kamera alçalır ve çok hafif yana yatar; yatma miktarı düşük. |
| Hasar alınca | Hafif kamera sarsıntısı (bkz. Vuruş hissi). |

**Açık sorular (oynadıkça karar verilecek):** hız cezası eğrisi, hava ivmesi miktarı, coyote/buffer süreleri, kamera değerlerinin tam miktarları.

### Vuruş hissi (hedef)

Vuruş geri bildirimi host onayından sonra gelir (yanlış "vurdum" hissi vermez); ses, marker ve hasar sayısı aynı anda çalışır. Değerler ve görseller oynadıkça ayarlanır.

| Konu | Karar |
| --- | --- |
| Hit marker | Klasik **X**. Gövde/bacak vuruşu **beyaz**, kafa vuruşu **kırmızı**. |
| Crosshair ayarı | Ayarlar menüsünde: renk, boyut, boşluk (mevcut karar), ayrıca hit marker'ın görünürlüğü. Maç içinden de erişilir. |
| Hasar sayıları | Maçta da gösterilir (sadece vuranın ekranında). Test range'de de var. |
| Test mankenleri | Sadece `test_range`'de. Host'un oynattığı maç haritalarında manken olmaz. |
| Öldürme anı | Ayrı efekt yok; kill sesi + kill feed yeterli. |
| Düşman tepkisi | Vurulan oyuncunun modeli kısa süreli **flinch** (üst gövde sarsılması) gösterir; sadece görsel, hareketi/nişanı etkilemez. Animasyon aşama 8'de. Şimdilik kan/kıvılcım efekti yeterli. |
| Ses kimliği | 2000'ler tarzı: kaba, sentetik, hafif tuhaf. Kafa vuruşu ve öldürme ayrı sesler. Aşama 9. |
| Hit-stop | Kullanılmaz (ağ senkronunu ve nişan hissini bozmasın). Gerekirse sadece yakın dövüşte kamera sarsıntısı. |
| Vurulan oyuncunun ekranı | Hasar alınca **hafif kamera sarsıntısı** (nişanı bozmaz, sadece görsel). Hasar yönü göstergesi sonra karar verilecek. |

**Açık sorular:** Silah başına ses/kamera tekmesi farkı. Hasar yönü göstergesi yerine **minimap** düşünülüyor; ayrıca detaylı konuşulacak.

### Düello ve silah dengesi (hedef)

| Konu | Karar |
| --- | --- |
| Düello süresi (TTK) | **Orta, ~0,6–1 sn** (aynı sınıf, gövde vuruşlarıyla ilk atıştan ölüme). Karşılıklı ateşleşme mümkün, ilk vuran avantajlı ama kesin kazanan değil. |
| Beceri dengesi | **Dengeli:** nişan ve hareket birbirini dengeler. Hızlı hareket edeni vurmak zor ama imkânsız değil (kademeli hız cezası ile uyumlu). |
| Mevcut durum | Wolf Assault Rifle şu an ~0,4 sn gövde TTK (20 hasar, 0,1 sn aralık); hedefin altında hızlı. Değerler `data/weapons/` içinde ayarlanacak, kod değişmez. |
| Silah kimliği | Silahlar en çok **ateş ritmi ve sesle** ayrılır: SMG sık ve ince, Heavy Rifle yavaş ve tok, Shotgun tek patlama. Hasar/TTK birbirine yakın tutulur, fark his ve ritimdedir (menzil rolü dar tutulur, istisna: Shotgun yakın, Marksman/Heavy uzak). |
| Geri tepme | Mevcut karar korunur: her silahta sabit, öğrenilebilir desen; CS'ten hafif. |
| Heavy Rifle | Tek atış kafa/gövdede kalır, **bacakta öldürmez** (bacak vuruşu yüksek hasar verir ama can bırakır). Uygulama: `heavy_rifle.tres` içinde bacak çarpanı. |
| Bear | Her mesafede orta güçlü; hız cezası az. Dar alanlarda güçlü kalır ama açıkta tamamen çaresiz değildir. Yakın dövüş kimliği korunur, ağır silahlar (Chainsaw) hâlâ yavaşlatır. |

**Not:** Kafa vuruşu (2x) TTK'yı yarıya indirir; bu, nişan becerisinin ödülü olarak kalır. Hawk Heavy Rifle'ın tek atışı bu TTK hedefinin dışındadır (kasıtlı istisna).

### Ses (hedef)

| Konu | Karar |
| --- | --- |
| Ayak sesi | Düşmanın nerede olduğu anlaşılır (yön ve mesafe), ama aşırı vurgulanmaz. Eğilip yürümek (Ctrl) çok az ses çıkarır; koşma, slide ve zıplama ayrı sesler verir. |
| Müzik | Maçta **hafif arka plan** müziği (distopik, düşük sesli); menüde ve maç sonunda ayrı parçalar. Ayarlardan kapatılır/kısılır; ses efektlerini bastırmaz. |
| Anons | **Soğuk, bürokratik hoparlör** sesi: sakin, düz, hafif tuhaf ("Airdrop Incoming", "Double Kill"). |
| Genel kimlik | 2000'ler tarzı, kaba ve sentetik (bkz. Vuruş hissi). |

### Tuş atamaları (hepsi ayarlardan değiştirilebilir)

| Tuş | İşlev |
| --- | --- |
| WASD | Hareket |
| Space | Zıplama |
| Ctrl | Eğilme (eğilip yürürken sessiz) / koşarken slide |
| Shift | Koşma (sprint) |
| Sol / sağ tık | Ateş / ikincil (dürbün, çift tabanca sağ el) |
| Q | Özel güç |
| R | Şarjör |
| E | Etkileşim (airdrop kasası) |
| V | Hızlı yakın dövüş |
| 1 / 2 | Ana silah / yedek |
| B | Sınıf menüsü |
| Tab | Skor tablosu |

## Sınıflar

5 sınıf, her birinde 2–3 silah ve 2 özel güç seçeneği. **Tüm sayılar ilk tahmin, `data/` altındaki Resource dosyalarından değiştirilecek.**

| Sınıf | Can | Hız | Rol | Görünüm |
| --- | --- | --- | --- | --- |
| Hawk | 80 | Normal | Uzak mesafe, yüksek nokta | Uzun palto, boyun atkısı |
| Bear | 175 | Hafif yavaş (hız cezası az) | Yakın dövüş tankı, her mesafede orta güçlü | Kaynaklı ev yapımı zırh, omuz ve kol koruyucuları |
| Cheetah | 70 | Çok hızlı | Vur-kaç, hareket | Eşofman, kapüşon, koşu ayakkabısı |
| Wolf | 100 | Normal | Dengeli, başlangıç sınıfı | Askeri yelek, bere |
| Volcano | 110 | Biraz yavaş | Patlayıcı, alan kontrolü | Kirli koruyucu tulum, madenci kafa lambası (kask yok) |

### Hawk

| Silah | Hasar | Not |
| --- | --- | --- |
| Heavy Rifle | Kafa ve gövdeden tek atış, bacak vuruşu öldürmez | 1,5 sn kurma, yavaş şarjör |
| Marksman Rifle | Kafa 1, gövde 2, bacak 3 atış | Hızlı atış ve şarjör, belirgin geri tepme |

- **Güçler (15 sn):** Grapple (yüksek noktaya çekilme) · Decoy (yerinde hologram bırakma)
- **Dengeleyiciler:** Dürbünde yavaş yürüme ve sallanma, namlu parlaması, dürbünsüz düşük isabet
- **Namlu parlaması:** Sadece dürbün açıkken. Haritanın her yerinden görünür (mesafe sınırı yok), yeri net belli olur.
- **Yedek:** Tabanca

### Bear

| Silah | Hasar | Not |
| --- | --- | --- |
| Sledgehammer | 2 vuruş (Cheetah'a 1) | Yavaş, geniş alan |
| Claws | 4 vuruş | Çok hızlı, kısa menzil |
| Chainsaw | Sürekli hasar | Basılı tutulur, kullanırken yavaşlar |

- **Güçler:** Shield (12 sn; 3 sn önden gelen hasarı engeller, arkadan korumaz) · Charge (ileri hücum, çarptığı rakibi 2 sn stunlar)
- **Yedek: 3 Throwing Knife.** Kavisli fiziksel atış, 35 hasar (kafaya 70). Iskalarsa duvara veya zemine saplanır (diğer oyuncular da görür), üstünden geçince toplanır. Toplanmazsa ya da hedefe saplanırsa her bıçak 8 sn'de envantere geri döner.
- **V:** Tekme (az hasar, geri itme)

### Cheetah

| Silah | Hasar | Not |
| --- | --- | --- |
| SMG | Düşük, çok hızlı atış | Koşarken isabetli |
| Dual Pistols | Orta | Sol/sağ tık ayrı ateş, hızlı şarjör |

- **Güçler:** Dash (5 sn; anlık atılma, havada da) · Adrenaline (4 sn ekstra hız ve ateş hızı)
- **Yedek:** Tabanca

### Wolf

| Silah | Hasar | Not |
| --- | --- | --- |
| Assault Rifle | Orta | Her mesafede dengeli |
| Burst Rifle | Üçlü seri | Orta mesafede güçlü |
| LMG | Orta, büyük şarjör | Uzun şarjör süresi, taşırken yavaşlar |

- **Güçler (15 sn):** Frag Grenade · Flashbang
- **Yedek:** Tabanca

### Volcano

| Silah | Hasar | Not |
| --- | --- | --- |
| Shotgun | Yakında çok yüksek | Uzakta etkisiz |
| Grenade Launcher | Alan hasarı | Kavisli atış, kendine de hasar verir |

- **Güçler (20 sn):** Sticky Bomb (duvara veya oyuncuya yapışır) · Landmine (üstüne basanı patlatır)
- **Landmine:** Herkese görünür, kırmızı ışığı yanıp söner. Tetik alanı küçük ama basanı **öldürür** (her sınıfı, Bear dahil).
- **Kendine hasar:** Volcano'nun patlayıcıları (Grenade Launcher, Sticky Bomb, Landmine) Volcano'nun kendisine **yarı hasar** verir.
- **Yedek:** Tabanca

## Sınıf değiştirme ve loadout

Menü üç adımlı: **sınıf → silah → güç**. Son seçim kaydedilir, tek tıkla aynısıyla doğulur.

- **Ölüyken:** Ölüm ekranında menü açılır, seçilen sınıfla doğulur.
- **Yaşarken:** `B` menüyü açar; ekranda "Next spawn: Bear" yazar, bir sonraki doğuşta geçilir.
- **Spawn koruması sırasında:** Doğduktan sonraki ilk 3 sn içinde seçim yapılırsa anında geçilir.

## Pickup'lar

| Pickup | Etki | Etki süresi | Yeniden çıkma |
| --- | --- | --- | --- |
| Health | +50 can, maksimumu geçmez | Anında | 45 sn |
| Speed | %30 hız | 8 sn | 45 sn |
| Double Jump | Havada ikinci zıplama | 10 sn | 45 sn |

- Haritada **5–6 pickup noktası**; tam yerleri harita bitince belirlenir.
- Yerleri sabit; alındığında yerinde geri sayım hologramı kalır.
- Health güvenli ve dar yerlerde, Speed ve Double Jump açık ve riskli yerlerde.
- Renkler: Health yeşil, Speed sarı, Double Jump mavi. Etkisi altındaki oyuncu parlar.
- İki oyuncu aynı anda basarsa host karar verir.

## Airdrop

1. İlk airdrop 3. dakikadan sonra, ardından her 2–3 dakikada bir. Herkese duyuru gelir.
2. 3–4 olası noktadan biri seçilir (host); ışık hüzmesi iner, kasa 10–15 sn'de paraşütle düşer.
3. Kasayı açmak için `E` 3 sn basılı tutulur; hasar alınırsa iptal olur.

**Kurallar:** Mermi sınırlı, bitince silah yok olur. Taşıyan haritada herkese görünür ve yavaşlar. Ölünce silah kalan mermisiyle yere düşer. Kill ödülü bu silahlara mermi eklemez.

**Silah:** Her airdrop'ta rastgele biri, kasa açılana kadar bilinmez. Hasarlar oynadıkça ayarlanır.

| Silah | Mermi | Davranış |
| --- | --- | --- |
| Railgun | 8 | Işın. **Sınırsız menzil, bütün duvarları deler**, haritanın her yerinden vurabilir. Her yerden tek atış, atış sıklığı düşük. |
| Minigun | 200 | Mermi başına 15 hasar, çok hızlı tarar ("pata küte"), ısınma süreli. |
| Rocket Launcher | 6 | Fiziksel roket. Merkezde 200 hasar, merkezden uzaklaştıkça azalır; alanı Frag'den büyük. Sıkanı geri iter (recoil, rocket jump). |

## Harita tasarım kuralları

Harita her sınıfa kendi güçlü olduğu bir alan sunmalı; oyuncu 5–10 sn'de bir bölge değiştirebilmeli.

| Bölge | Özellik | Kimin için |
| --- | --- | --- |
| Açık meydan | Geniş, dağınık siper | Wolf, Hawk |
| Uzun koridor | Uzun görüş hattı, arada kırıcı siperler | Hawk |
| Yüksek noktalar | Çatı, köprü, kule; grapple noktaları | Hawk, Cheetah |
| Dar iç mekan | Kısa koridor, köşe, kapı | Bear, Volcano |
| Dikey kısa yollar | Zıplanabilir çıkıntı, pencereden atlama | Cheetah |

**Denge kuralları:**

- Her yüksek noktaya en az iki yoldan çıkılabilir.
- Hiçbir görüş hattında 2–3 sn'den uzun açıkta kalınmaz.
- Dar alanlar kısa yol olur, ama etrafından dolanan uzun bir yol da vardır.

**Hareket pürüzsüzlüğü (takılmama kuralları):**

- Duvar ve siper köşeleri pahlanır veya yuvarlanır; oyuncu köşeden takılmadan kayıp geçer.
- Zeminler düz kalır. Kablo, moloz gibi dekoratif detaylar **collision'sız** olur; collision sadece gerçek bir nedeni olan nesnelerde (siper, basamak) bulunur.
- Basamaklar yumuşatılır (kamera step-up'ta interpolasyonla). Godot'ta hazır step-up yok, gerekirse eklenecek.

**Boyut ve yerleşim:**

Ölçek **4–6 oyuncuya** göredir (genelde bu kadar kişi oynar). Daha büyük harita bu sayıda boş hissettirir.

- Bir uçtan diğerine koşarak 15–20 sn (koşu 6,6 m/s)
- 10–12 spawn noktası, tüm bölgelere dağılmış (10 kişide de yeterli)
- 3 airdrop noktası, bölgelerin kesiştiği yerlerde

**İlk harita:** Terk edilmiş alışveriş merkezi. Dar koridorlu mağazalar (Bear, Volcano), ortada açık atrium (Wolf), üst katlar ve yürüyen merdivenler (Hawk, Cheetah), dışarıda otopark ve çatı. Bina yaklaşık **64 × 48 m**, iki kat (0 m ve 5 m) ve çatı (10 m); 5–6 dükkân, bir uzun yemek katı koridoru, dükkân arkalarında dar servis koridoru, dışarıda otopark ve yükleme alanı.

**Yerleşim kararları:**

- **Düzen:** Ortada açık atrium, etrafında **halka koridor**; dükkanlar halkaya açılır. Her yerden her yere birden fazla yol vardır, ölü uç ve sıkışma olmaz.
- **Dikey geçiş:** Yürüyen merdiven, normal merdiven, zıplanabilir çıkıntılar ve atlama noktaları gibi birden fazla hızlı yol. Kat değiştirmek 5–10 sn sürer.
- Dışarıda otopark ve çatı, atrium ve üst katlarla bağlanır; çatı grapple noktalarıyla güçlenir.

**Süreç:** Önce basit bloklarla kurulur (blockout), birkaç maç test edilir, akış oturunca modellenir. Binanın kendisi (duvar, zemin, merdiven) bizim tarafımızdan yapılır; hazır modeller sadece prop için, dokular CC0 fotoğraf dokuları. İhtiyaç listesi ve lisans takibi: `docs/ASSETS.md`.

## Görsel tarz ve performans

Distopik, 2000'lerin başı oyun estetiği: az poligon, fotoğraf tabanlı doku, sert ışık, hafif tuhaf detaylar. Karakterler normal insanlar.

**Karakter yüzleri:** Her karakterin kafası **açık** olur (maske, kask yok; yüz hep görünür). Gerçek yüz fotoğraflarından üretilen kafalar kullanılır (~10 kişi, izinler alındı).

- **Yöntem:** Yüzler **oyunla birlikte gelir**. Kafalar Blender'da önceden hazırlanır (Avaturn GLB → sadece kafa → poligon azaltma → 512 px doku), oyuna gömülür. Oyuncu lobide, ölüm ekranında ve geç katılırken "Face" seçer; ağda sadece yüz ID'si (örn. `face_can`) senkronlanır. Kozmetiktir, oynanışı etkilemez.
- **Plan:** Önce 2 yüzle deneme (aşama 8). Tarz tutarsa kalan yüzler eklenir.
- **Kapsam dışı:** Oyuncunun oyun içinden kendi model/fotoğrafını yüklemesi yoktur.
- Ham fotoğraflar ve indirilen avatar dosyaları repoya girmez (`private_assets/`, `.gitignore`'da).

- **Modeller:** Karakterler ~3–5 bin poligon, dokular ~512px fotoğraf tabanlı
- **Atmosfer:** Turuncu-kırmızı gökyüzü, yoğun sis, baked ışık
- **Post-process:** Hafif film grain, sıcak renk ayarı, ince vignette
- **Tuhaf detaylar:** Sahte marka reklam panoları, tuhaf posterler, hoparlör anonsları

**Performans (GTX 1050 Ti, 1080p, 100+ FPS):**

- Godot Mobile renderer (Vulkan, hafif)
- LightmapGI ile önceden pişirilmiş ışık, sınırlı dinamik gölge
- Grafik menüsü: çözünürlük ölçeği, sis kalitesi, post-process aç/kapa

## Test ve dağıtım

- **Test:** Hasar sayısı gösteren hedef mankenleri. Bot yok.
- **Sesli iletişim:** Discord (oyun içi ses yok)
- **Dağıtım:** GitHub gizli repo (kod) + Releases (oyun zip'i). Arkadaşlar collaborator olarak eklenir.
- **Bağlantı:** Tailscale ile sanal LAN, host'un portu dışarı açmasına gerek yok.
