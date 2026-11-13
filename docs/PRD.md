# PRD — Aplikasi Antrean Sederhana (Flutter + Supabase)

Versi: 1.1 · Tanggal: 12 November 2026 · Status: Draft siap dikerjakan

## 1. Latar Belakang

Usaha layanan kecil (barbershop, bengkel, klinik) sering membuat pelanggan menunggu lama di lokasi tanpa tahu kapan gilirannya. Aplikasi ini memungkinkan pelanggan mengambil nomor antrean dan memantau posisinya dari HP, sementara petugas memanggil dan mengelola antrean dari halaman admin di aplikasi yang sama.

## 2. Tujuan

1. Pelanggan bisa mengambil nomor antrean cukup dengan mengisi nama.
2. Pelanggan melihat posisi antrean secara real-time tanpa restart atau refresh manual.
3. Petugas bisa memanggil, menyelesaikan, melewati, dan mereset antrean dengan cepat dari HP.
4. Tampilan rapi, sederhana, dan nyaman dipakai satu tangan di HP.

### Di luar cakupan (versi 1)

Multi-cabang atau multi-layanan, notifikasi push, pembayaran, booking jadwal, display TV/papan antrean, laporan statistik, dan pendaftaran akun pelanggan.

## 3. Pengguna

| Peran | Deskripsi | Autentikasi |
|---|---|---|
| Pelanggan | Orang yang ingin dilayani | Otomatis via Supabase Anonymous Sign-In (tanpa form login) |
| Admin/Petugas | Staf yang melayani pelanggan | Email + password (akun dibuat manual oleh pemilik di Supabase Dashboard) |

## 4. Keputusan Teknis

| Aspek | Keputusan | Alasan |
|---|---|---|
| Framework | Flutter (stable terbaru), target utama Android | Sesuai ketentuan |
| Backend | Supabase (Postgres + Auth + Realtime) | Data terpusat, realtime bawaan, logika atomik via SQL function |
| Struktur | Satu aplikasi dengan dua mode: Pelanggan & Admin | Sesuai pilihan user |
| State management | Riverpod (`flutter_riverpod`, tanpa code generation) | Ringan, cocok dengan stream realtime, mudah dites |
| Routing | `go_router` dengan guard untuk rute admin | Redirect otomatis jika belum login/bukan admin |
| Identitas pelanggan | Anonymous user Supabase (`auth.uid()`) | Pemilik tiket bisa dikenali untuk fitur batal tanpa form login |
| Penulisan data | Hanya lewat RPC (Postgres function `security definer`) | Penomoran atomik, aturan bisnis terpusat, aman dari manipulasi klien |

## 5. Kebutuhan Fungsional

### 5.1 Pelanggan

**F-P1 Ambil nomor antrean**
- Pelanggan mengisi nama (wajib, 1–50 karakter setelah di-trim), lalu menekan "Ambil Nomor".
- Sistem memberi nomor berikutnya dalam sesi aktif (1, 2, 3, …) secara atomik: dua orang yang menekan bersamaan tidak boleh mendapat nomor sama.
- Satu perangkat (anonymous user) hanya boleh punya satu tiket aktif (status `waiting` atau `called`) per sesi. Jika sudah punya, aplikasi langsung menampilkan halaman status tiket tersebut.

**F-P2 Pantau status antrean**
Halaman status menampilkan:
- Nomor antrean milik pelanggan (besar dan menonjol) beserta nama.
- Nomor yang sedang dilayani (tiket berstatus `called`). Jika tidak ada, tampilkan "Terakhir dipanggil: X" atau "Belum ada yang dipanggil".
- Jumlah antrean di depannya = jumlah tiket `waiting` di sesi yang sama dengan nomor lebih kecil.
- Status tiket dengan label dan warna yang jelas:

| Status | Label pelanggan |
|---|---|
| waiting | Menunggu — ada N orang di depan Anda |
| called | Giliran Anda! Silakan menuju petugas |
| done | Selesai — terima kasih |
| skipped | Nomor Anda dilewati — silakan hubungi petugas |
| cancelled | Antrean dibatalkan |

- Data berubah otomatis via Supabase Realtime, tanpa restart. Saat aplikasi kembali dari background, data di-refresh.
- Saat tiket selesai/dilewati/dibatalkan, tampil tombol "Ambil Nomor Baru".
- Jika sesi tiket sudah direset oleh admin, tampilkan "Antrean telah direset" dan tombol ambil nomor baru.

**F-P3 Batalkan nomor**
- Tombol "Batalkan Antrean" hanya muncul untuk tiket milik sendiri berstatus `waiting`.
- Wajib dialog konfirmasi. Setelah batal, status menjadi `cancelled`.

**F-P4 Perkiraan waktu tunggu** *(fitur tambahan)*
- Saat tiket berstatus `waiting`, halaman status menampilkan perkiraan kapan giliran pelanggan tiba, dalam menit dan jam, misalnya "Sekitar 25 menit lagi (sekitar pukul 10.15)".
- Rumus (dihitung di server, di dalam `get_my_status()`):
  - `avg` = rata-rata durasi layanan (`finished_at − called_at`) dari maksimal 10 tiket `done` terakhir di sesi aktif. Setiap durasi dibatasi 1–60 menit agar data aneh (misal lupa menekan "Selesai") tidak merusak rata-rata.
  - Jika belum ada tiket `done` di sesi ini, `avg` = `default_service_minutes` (bawaan 10 menit).
  - `sisa_dilayani` = jika ada tiket `called`: `max(avg − (now − called_at), 0)`, selain itu 0.
  - `perkiraan` = `ahead_count × avg + sisa_dilayani`, dibulatkan ke atas ke kelipatan 5 menit.
- Tampilan khusus: perkiraan < 5 menit → "Kurang dari 5 menit lagi"; `ahead_count = 0` dan tidak ada yang dipanggil → "Sebentar lagi giliran Anda".
- Di bawah perkiraan ada keterangan sumbernya: "Berdasarkan rata-rata layanan hari ini" atau "Perkiraan awal, belum ada data hari ini".
- Karena waktu terus berjalan tanpa ada event realtime, aplikasi me-refetch `get_my_status()` setiap 60 detik selama tiket `waiting` dan aplikasi di foreground.
- Perkiraan disembunyikan untuk status selain `waiting`.

### 5.2 Admin/Petugas

**F-A1 Login**
- Form email + password. Hanya user yang terdaftar di tabel `admins` yang boleh masuk; user lain mendapat pesan "Akun ini bukan admin" lalu di-logout.
- Rute `/admin/*` dilindungi guard. Tersedia tombol logout.

**F-A2 Daftar antrean**
- Kartu ringkasan di atas: nomor yang sedang dipanggil, jumlah menunggu, total tiket hari ini (sesi aktif), dan rata-rata waktu layanan hari ini (dari rumus F-P4; tampil "–" jika belum ada data).
- Daftar tiket sesi aktif urut nomor, berisi nomor, nama, status (chip berwarna), dan jam ambil.
- Filter tab: Semua · Menunggu · Dipanggil · Selesai · Dilewati · Dibatalkan.
- Daftar ter-update real-time.

**F-A3 Panggil berikutnya**
- Tombol besar "Panggil Berikutnya" mengubah tiket `waiting` bernomor terkecil menjadi `called` dan mengisi `called_at`.
- Hanya boleh ada satu tiket `called` dalam satu waktu. Selama masih ada tiket `called`, tombol ini nonaktif dan petugas harus menandai tiket tersebut selesai/dilewati dulu.
- Jika tidak ada yang menunggu, tombol nonaktif dengan teks "Tidak ada antrean".

**F-A4 Tandai selesai / dilewati**
- Pada tiket `called`: tombol "Selesai" (→ `done`) dan "Lewati" (→ `skipped`), mengisi `finished_at`.
- Pada tiket `waiting`: tersedia aksi "Lewati" (misal pelanggan tidak datang).
- Opsional (nice to have): tiket `skipped` bisa "Panggil Ulang" (→ `called`) jika tidak ada tiket lain yang sedang dipanggil.

**F-A5 Reset antrean**
- Tombol "Reset Antrean" di menu, dengan dialog konfirmasi yang menyebut jumlah tiket yang masih menunggu.
- Reset menutup sesi aktif dan membuka sesi baru, sehingga nomor mulai lagi dari 1. Tiket lama tetap tersimpan sebagai riwayat; tiket `waiting`/`called` di sesi lama otomatis menjadi `cancelled`.
- Reset dilakukan manual oleh admin (tidak otomatis tengah malam).

## 6. Kebutuhan Non-Fungsional

- **Realtime**: perubahan status tampil di HP pelanggan maksimal ±2 detik setelah aksi admin pada koneksi normal.
- **Keamanan**: Row Level Security aktif di semua tabel. Pelanggan tidak bisa membaca nama/tiket pelanggan lain. Semua penulisan lewat RPC dengan validasi peran.
- **Konkurensi**: penomoran memakai row lock pada sesi aktif plus unique constraint `(session_id, number)`.
- **UI/UX**: Material 3, bahasa Indonesia, font nomor besar, tombol minimal 48dp, mendukung light/dark mode, layout aman untuk layar kecil (≥ 360dp).
- **Ketahanan**: tampilkan indikator offline/loading dan pesan error yang ramah. Realtime otomatis tersambung ulang; saat tersambung kembali, data di-refetch.
- **Konfigurasi**: URL dan anon key Supabase lewat `--dart-define`, tidak di-hardcode atau di-commit.

## 7. Alur Layar

```
Splash (sign-in anonim jika belum ada sesi)
 └─ Beranda: [Ambil Antrean] [Masuk sebagai Petugas]
     ├─ Pelanggan
     │   ├─ Form Ambil Nomor (nama) ──► Status Tiket
     │   └─ (jika sudah punya tiket aktif) ─► Status Tiket
     └─ Admin
         ├─ Login
         └─ Dashboard Admin
             ├─ Kartu ringkasan + tombol Panggil Berikutnya
             ├─ Tab filter + daftar tiket (aksi Selesai/Lewati)
             └─ Menu: Reset Antrean, Logout
```

Catatan: login admin mengganti sesi anonim di perangkat itu. Setelah logout, aplikasi membuat user anonim baru, sehingga tiket pelanggan lama di perangkat tersebut tidak terbaca lagi. Ini diterima karena perangkat petugas umumnya berbeda dari perangkat pelanggan.

## 8. Desain Data (Supabase / Postgres)

### 8.1 Tabel

```sql
create type ticket_status as enum ('waiting','called','done','skipped','cancelled');

create table queue_sessions (
  id                 uuid primary key default gen_random_uuid(),
  started_at         timestamptz not null default now(),
  ended_at           timestamptz,
  is_active          boolean not null default true,
  last_number        int not null default 0,      -- nomor terakhir yang diberikan
  current_number     int,                          -- nomor berstatus 'called' (null jika tidak ada)
  last_called_number int,                          -- nomor terakhir yang pernah dipanggil
  waiting_count      int not null default 0,
  default_service_minutes int not null default 10 check (default_service_minutes between 1 and 120),
  updated_at         timestamptz not null default now()
);
create unique index one_active_session on queue_sessions (is_active) where is_active;

create table tickets (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references queue_sessions(id),
  number        int not null,
  customer_name text not null check (char_length(btrim(customer_name)) between 1 and 50),
  user_id       uuid not null references auth.users(id),
  status        ticket_status not null default 'waiting',
  created_at    timestamptz not null default now(),
  called_at     timestamptz,
  finished_at   timestamptz,
  unique (session_id, number)
);
create unique index one_active_ticket_per_user
  on tickets (session_id, user_id) where status in ('waiting','called');
create unique index one_called_per_session
  on tickets (session_id) where status = 'called';

create table admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
```

`queue_sessions` menyimpan angka ringkasan (tanpa nama pelanggan) yang aman dibaca semua user dan menjadi pemicu realtime untuk halaman pelanggan. Kolom ringkasan diperbarui oleh trigger `after insert or update on tickets`.

### 8.2 Row Level Security

| Tabel | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| queue_sessions | semua user terautentikasi (termasuk anonim) | tidak ada (hanya via RPC) |
| tickets | `user_id = auth.uid()` atau `is_admin()` | tidak ada (hanya via RPC) |
| admins | `user_id = auth.uid()` | tidak ada (dikelola via Dashboard) |

### 8.3 Fungsi RPC (semua `security definer`, `set search_path = public`)

| Fungsi | Siapa | Perilaku |
|---|---|---|
| `is_admin() → boolean` | semua | cek `auth.uid()` ada di `admins` |
| `ensure_active_session() → uuid` | internal | buat sesi jika belum ada yang aktif |
| `take_ticket(p_name text) → tickets` | pelanggan | lock sesi aktif (`for update`), tolak jika sudah punya tiket aktif, `last_number + 1`, insert tiket |
| `cancel_ticket(p_ticket_id uuid) → tickets` | pemilik tiket | hanya jika milik `auth.uid()` dan status `waiting` |
| `get_my_status() → json` | pelanggan | tiket terbaru milik user, status, `ahead_count`, `current_number`, `last_called_number`, `session_active`, `est_wait_minutes` (null jika bukan `waiting`), `avg_service_seconds`, `estimate_basis` (`history` / `default`) |
| `get_queue_stats() → json` | admin | `avg_service_seconds`, `estimate_basis`, jumlah per status di sesi aktif |
| `call_next() → tickets` | admin | gagal jika ada tiket `called`; ambil `waiting` nomor terkecil (`for update skip locked`) → `called` |
| `set_ticket_status(p_ticket_id uuid, p_status ticket_status) → tickets` | admin | validasi transisi (lihat 8.4) |
| `reset_queue() → queue_sessions` | admin | batalkan tiket aktif sesi lama, tutup sesi, buat sesi baru |

### 8.4 Transisi Status yang Diizinkan

```
waiting ──call_next──► called ──► done
   │                     └──────► skipped ──(opsional: panggil ulang)──► called
   ├──admin lewati──► skipped
   └──pelanggan batal──► cancelled
waiting/called ──reset──► cancelled
```

Transisi lain ditolak oleh RPC dengan pesan error yang jelas.

### 8.5 Strategi Realtime

- Publication `supabase_realtime` mencakup `queue_sessions` dan `tickets`.
- **Pelanggan**: subscribe perubahan `queue_sessions` (baris aktif) dan baris tiket miliknya; setiap event memicu `get_my_status()` ulang, ditambah refetch berkala 60 detik untuk memperbarui perkiraan waktu tunggu. Realtime menghormati RLS sehingga pelanggan tidak menerima data tiket orang lain.
- **Admin**: subscribe `tickets` dengan filter `session_id=eq.<aktif>` dan `queue_sessions`; daftar diperbarui dari event atau refetch.
- Refetch juga dilakukan saat app resume dan saat channel tersambung ulang.

## 9. Kriteria Penerimaan

1. Dua HP mengambil nomor bersamaan → nomor berbeda dan berurutan.
2. Admin memanggil nomor → HP pelanggan berubah ke "Giliran Anda!" tanpa disentuh.
3. Jumlah "di depan Anda" berkurang otomatis saat tiket lain dipanggil, dilewati, atau dibatalkan.
4. Pelanggan membatalkan tiket → admin melihat status `dibatalkan` secara real-time.
5. User non-admin tidak bisa membuka dashboard dan tidak bisa memanggil RPC admin (ditolak server).
6. Setelah reset, tiket pertama berikutnya bernomor 1; pelanggan dengan tiket lama melihat pesan reset.
7. Pelanggan tidak bisa membaca nama pelanggan lain lewat query langsung ke tabel.
8. UI nyaman di layar 360×640dp, light dan dark mode.
9. Tanpa data `done` di sesi, perkiraan = jumlah di depan × 10 menit dengan keterangan "Perkiraan awal".
10. Setelah beberapa tiket selesai, perkiraan memakai rata-rata durasi nyata dan berkurang sendiri seiring waktu tanpa interaksi pengguna.

## 10. Milestone

| # | Lingkup | Hasil |
|---|---|---|
| M1 | Setup Supabase: migrasi SQL, RLS, RPC, realtime, anonymous auth aktif | Skrip migrasi + uji RPC via SQL editor |
| M2 | Setup Flutter: struktur folder, Riverpod, go_router, tema, koneksi Supabase | App jalan, sign-in anonim berhasil |
| M3 | Fitur pelanggan: ambil nomor, status realtime, batal, perkiraan waktu tunggu | F-P1 s/d F-P4 |
| M4 | Fitur admin: login, dashboard, panggil, selesai/lewati, reset | F-A1 s/d F-A5 |
| M5 | Polish: error/offline state, dark mode, uji kriteria penerimaan, README | Siap demo |

## 11. Asumsi & Pertanyaan Terbuka

Asumsi berikut dipakai sebagai default. Bila ada yang ingin diubah, PRD akan diperbarui.

1. Satu usaha, satu antrean (tanpa multi-cabang/multi-layanan).
2. Format nomor angka biasa (1, 2, 3), tanpa prefix seperti "A-001".
3. Status tambahan `cancelled` (dibatalkan) dipakai untuk pembatalan pelanggan, terpisah dari `skipped`.
4. Hanya satu tiket `called` dalam satu waktu (satu petugas/loket).
5. Reset dilakukan manual oleh admin, bukan otomatis tiap tengah malam.
6. Akun admin dibuat manual di Supabase Dashboard lalu ditambahkan ke tabel `admins`.
7. Tiket pelanggan terikat ke perangkat; jika data aplikasi dihapus atau di-uninstall, tiket tidak bisa dipantau lagi dari perangkat itu.
8. Tidak ada push notification (FCM) di versi 1. Ada notifikasi lokal "Giliran Anda!" saat nomor dipanggil, tapi hanya muncul selama aplikasi masih hidup di background; jika aplikasi ditutup paksa, pelanggan perlu membukanya lagi.
9. Waktu layanan bawaan 10 menit per pelanggan, diubah lewat kolom `default_service_minutes` di Supabase Dashboard (belum ada pengaturan di aplikasi).
10. Perkiraan waktu tunggu bersifat perkiraan kasar dan selalu ditampilkan dengan kata "sekitar", bukan janji jam pasti.
