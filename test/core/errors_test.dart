import 'dart:io';

import 'package:antre/core/errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps known RPC error codes', () {
    expect(
      friendlyError(const PostgrestException(message: 'already_has_ticket')),
      'Anda sudah memiliki nomor antrean aktif.',
    );
    expect(
      friendlyError(const PostgrestException(message: 'not_admin')),
      'Akun ini bukan admin.',
    );
  });

  test('unknown errors fall back to a generic message', () {
    expect(
      friendlyError(const PostgrestException(message: 'boom')),
      contains('Terjadi kesalahan'),
    );
    expect(friendlyError(Exception('x')), contains('Terjadi kesalahan'));
  });

  test('auth and network errors', () {
    expect(
      friendlyError(const AuthException('bad', code: 'invalid_credentials')),
      'Email atau kata sandi salah.',
    );
    expect(
      friendlyError(const SocketException('offline')),
      contains('koneksi'),
    );
    expect(friendlyError(const AppException('Pesan')), 'Pesan');
  });
}
