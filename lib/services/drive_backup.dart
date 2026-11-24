import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../store.dart';
import 'auth_service.dart';

/// Optional, user-triggered copy of the app's data in the user's OWN Google
/// Drive. It is a plain JSON file ("Prakriya backup.json") in My Drive that the
/// user can see, download or delete. The permission asked for is
/// `drive.file`: Prakriyā can only touch files it created itself.
///
/// This is a safety copy, not the sync channel — live sync goes through
/// Firestore (see CloudSync).
class DriveBackup {
  DriveBackup._();
  static final DriveBackup instance = DriveBackup._();

  static const _name = 'Prakriya backup.json';
  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  /// Saves the current data to Drive (creating or updating the backup file).
  /// Returns the time of the backup, or null if it didn't work.
  Future<DateTime?> backUp() async {
    final token = await AuthService.instance.driveToken(interactive: true);
    if (token == null) return null;
    try {
      await store.flush();
      final payload = jsonEncode({
        'app': 'prakriya',
        'v': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'device': 'android',
        'state': store.state.toJson(),
      });
      final id = await _findId(token);
      late http.Response r;
      if (id != null) {
        r = await http.patch(
          Uri.parse('$_upload/files/$id?uploadType=media&fields=id,modifiedTime'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: utf8.encode(payload),
        );
      } else {
        final b = 'prakriya${DateTime.now().microsecondsSinceEpoch}';
        final meta = jsonEncode({'name': _name, 'mimeType': 'application/json'});
        final body = '--$b\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n'
            '--$b\r\nContent-Type: application/json\r\n\r\n$payload\r\n--$b--';
        r = await http.post(
          Uri.parse('$_upload/files?uploadType=multipart&fields=id,modifiedTime'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'multipart/related; boundary=$b'},
          body: utf8.encode(body),
        );
      }
      if (r.statusCode == 401) await AuthService.instance.clearDriveToken(token);
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      return DateTime.parse(jsonDecode(r.body)['modifiedTime'] as String).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Replaces local data with the Drive backup. Returns false if there is no
  /// backup (or it can't be read). Only call when the user asked for it.
  Future<bool> restore() async {
    final token = await AuthService.instance.driveToken(interactive: true);
    if (token == null) return false;
    try {
      final id = await _findId(token);
      if (id == null) return false;
      final r = await http.get(Uri.parse('$_api/files/$id?alt=media'),
          headers: {'Authorization': 'Bearer $token'});
      if (r.statusCode == 401) await AuthService.instance.clearDriveToken(token);
      if (r.statusCode != 200) return false;
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      final state = decoded is Map ? decoded['state'] : null;
      if (state is! Map) return false;
      await store.replaceState(AppState.fromJson(Map<String, dynamic>.from(state)));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _findId(String token) async {
    final q = Uri.encodeQueryComponent("name='$_name' and trashed=false");
    final r = await http.get(
      Uri.parse('$_api/files?q=$q&orderBy=modifiedTime%20desc&pageSize=1&fields=files(id)'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 401) await AuthService.instance.clearDriveToken(token);
    if (r.statusCode != 200) throw Exception('drive ${r.statusCode}');
    final files = (jsonDecode(r.body)['files'] as List?) ?? const [];
    return files.isEmpty ? null : (files.first as Map)['id'] as String;
  }
}
