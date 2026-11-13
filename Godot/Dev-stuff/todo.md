Fasa 1: Firmware ESP32 (Sensor & Bluetooth) ✓

[ ] Bersihkan kod Arduino ESP32 supaya hanya menghantar data sudut bersih (contoh: format 45.2\n) tanpa teks debugging yang panjang.

[ ] Masukkan library BluetoothSerial.h dan mulakan Bluetooth dengan nama peranti tetap (contoh: ESP32_Rehab_Knee).

[ ] Uji pairing Bluetooth ESP32 ke komputer (Fedora 44 dan Windows).

Fasa 2: Sambungan Komunikasi Rentas Platform

[ ] Bina skrip jambatan ringan (Python pyserial + socket) yang membaca Bluetooth COM/RFCOMM dan terus memancarkannya ke 127.0.0.1:4242 secara automatik.

[ ] Sediakan fungsi auto-reconnect dalam skrip supaya jika wayar/bateri tercabut, sistem tidak membeku (crash).

[ ] Uji penerimaan data UDP dalam Godot menggunakan nod PacketPeerUDP.

Fasa 3: UI & Modul Kalibrasi Fisioterapi (Godot)

[ ] Bina skrin/tetingkap pop-naik kalibrasi sebelum sesi permainan bermula.

[ ] Sediakan paparan nilai sudut semasa (Live Angle Feed) untuk rujukan ahli terapi.

[ ] Sediakan Butang "Kunci Lurus": Merakam bacaan semasa sebagai min_angle.

[ ] Sediakan Butang "Kunci Bengkok": Merakam bacaan semasa sebagai max_angle.

[ ] Sediakan palang tolok visual (Range Bar 0% - 100%) untuk pesakit menguji pergerakan lutut sebelum bermain.

[ ] Sediakan Butang "Mula Senaman": Membawa pesakit masuk ke Flappy Bird bersama nilai had yang telah dikunci.

Fasa 4: Penyesuaian Logik Permainan (Flappy Bird)

[ ] bird.gd: Buang logik input kekunci ui_up dan ui_down.

[ ] bird.gd: Tambah fungsi lerp() pada paksi-Y untuk pergerakan burung yang lancar (smooth).

[ ] main.gd: Buat fungsi matematik remap() untuk menukar sudut lutut pesakit (min_angle hingga max_angle) kepada koordinat piksel skrin (650px ke 25px).

[ ] main.gd: Pasang sekatan had (clamp) supaya burung tidak terkeluar dari skrin jika pesakit terlajak membengkokkan lutut.

Fasa 5: Ujian Klinikal & Penalaan Akhir

[ ] Uji ketepatan respon pergerakan pada tahap kelajuan Slow, Medium, dan Fast.

[ ] Uji kestabilan bacaan apabila sistem dipindahkan dari Fedora 44 ke persekitaran Windows.
