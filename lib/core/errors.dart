import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Error raised by the app itself with a message that is already user-facing.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Messages for the `raise exception '<code>'` codes in supabase/migrations.
const rpcErrorMessages = <String, String>{
  'not_authenticated': 'Sesi tidak valid. Silakan buka ulang aplikasi.',
  'not_admin': 'Akun ini bukan admin.',
  'invalid_name': 'Nama wajib diisi (1–50 karakter).',
  'already_has_ticket': 'Anda sudah memiliki nomor antrean aktif.',
  'ticket_not_found': 'Tiket tidak ditemukan.',
  'invalid_transition': 'Status tiket tidak bisa diubah ke status tersebut.',
  'call_in_progress': 'Masih ada nomor yang sedang dipanggil. Selesaikan dulu.',
  'queue_empty': 'Tidak ada antrean yang menunggu.',
  'session_closed': 'Sesi antrean ini sudah ditutup.',
};

const _genericMessage = 'Terjadi kesalahan. Silakan coba lagi.';
const _offlineMessage = 'Tidak ada koneksi internet. Periksa jaringan Anda.';

String friendlyError(Object error) => switch (error) {
  AppException(:final message) => message,
  PostgrestException(:final message) =>
    rpcErrorMessages[message] ?? _genericMessage,
  AuthException(:final code) when code == 'invalid_credentials' =>
    'Email atau kata sandi salah.',
  AuthException() => 'Gagal masuk. Silakan coba lagi.',
  SocketException() || TimeoutException() => _offlineMessage,
  // http's ClientException isn't re-exported by supabase; match by name.
  _ when error.runtimeType.toString() == 'ClientException' => _offlineMessage,
  _ => _genericMessage,
};
