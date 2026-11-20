# VORTEX_GT_MASTER

Vortex GT, Godot 4.4.1 ile hazırlanmış çevrimdışı Android sürüş prototipidir. İlk sürüm doğrudan gündüz sahil yolunda açılır. 2,4 km sonunda yol başa döner. Hız, toplam mesafe ve anlık FPS sürüş sırasında ekranda görünür.

## Kontroller

Sol alttaki direksiyona dokunup parmağını yatay kaydır. Sağdaki gaz veya fren pedalını aynı anda basılı tutabilirsin. Sağ üstteki kamera düğmesi takip, yakın arka çapraz ve ön çapraz görünümler arasında geçiş yapar.

Bilgisayarda W/S veya yukarı/aşağı gaz ve freni, A/D veya sol/sağ direksiyonu, C kamerayı kontrol eder.

## Android test paketi

Godot 4.4.1, aynı sürümün Android dışa aktarma şablonu, Android SDK ve JDK kurulu bir ortamda proje kökünden çalıştır.

```sh
mkdir -p build
godot --headless --import
godot --headless --export-debug Android build/VortexGT.apk
```

APK, ARM64 Android cihazlar için yatay ekran ayarıyla imzalanır. Araç modeli `assets/gt/VortexGT.gltf` ve aynı klasördeki ikili veri dosyalarından yüklenir.
