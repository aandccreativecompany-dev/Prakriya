import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../store.dart';
import 'auth_service.dart';

/// Live sync for signed-in users through Firestore, shared with the Prakriyā
/// web/desktop app: the whole local AppState is one document at
/// `users/{uid}` = { state, updatedAt }. Edits on either side show up on the
/// other within seconds (the app listens to the document).
///
/// Writes are last-write-wins, with safeguards so nothing is silently lost:
///   * a device with no unsynced edits simply adopts a newer remote copy;
///   * local edits are never replaced by an older/equal remote copy;
///   * if BOTH sides were edited since the last sync, the more recent edit wins;
///   * a pending-edit flag is saved to disk, so edits made offline or just
///     before the app closed are still pushed on the next launch.
/// Local storage is always the source of truth on the device.
class CloudSync with WidgetsBindingObserver {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  final _db = FirebaseFirestore.instance;
  Timer? _debounce;
  bool _wired = false;
  bool _applying = false; // true while we write remote data into the store
  bool _busy = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _listener;
  String? _listeningUid;
  _Meta _meta = _Meta();
  bool _metaLoaded = false;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  /// Starts mirroring local edits whenever a user is signed in. Safe to call
  /// once, at app start — it is a no-op until someone signs in.
  void wire() {
    if (_wired) return;
    _wired = true;
    store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(syncOnLaunch(user.uid));
    } else if (state == AppLifecycleState.paused) {
      _debounce?.cancel();
      unawaited(_push(user.uid));
    }
  }

  void _onStoreChanged() {
    if (_applying) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    unawaited(_markDirty());
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => _push(user.uid));
  }

  /// Watches the cloud copy so edits from the web app arrive within seconds.
  void startListening(String uid) {
    if (_listeningUid == uid) return;
    stopListening();
    _listeningUid = uid;
    _listener = _doc(uid).snapshots().listen((snap) {
      if (snap.metadata.hasPendingWrites) return; // our own write, not yet confirmed
      unawaited(syncOnLaunch(uid));
    }, onError: (_) {});
  }

  void stopListening() {
    _listener?.cancel();
    _listener = null;
    _listeningUid = null;
  }

  // ---- public API (same entry points the screens already use) ----

  /// Explicit "Back up now": pushes immediately. True when the cloud copy is
  /// up to date afterwards.
  Future<bool> backUpNow(String uid) async {
    _debounce?.cancel();
    await store.flush();
    await _markDirty();
    return _push(uid, force: true);
  }

  /// Explicit "Restore": REPLACES local state with the cloud copy. Only call
  /// when the user asked for it.
  Future<bool> pullAndApply(String uid) async {
    try {
      final remote = await _fetchRemote(uid);
      if (remote == null) return _push(uid, force: true);
      await _apply(remote);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs at launch / resume / whenever the cloud copy changes. Never destroys
  /// local edits (see the class comment).
  Future<void> syncOnLaunch(String uid) async {
    if (_busy) return;
    _busy = true;
    var pushAfter = false;
    var forcePush = false;
    try {
      await _loadMeta();
      final remote = await _fetchRemote(uid);
      if (remote == null) {
        // Nothing in the cloud yet: save what's here (if there is anything).
        pushAfter = !store.looksEmpty;
        forcePush = true;
      } else if (store.looksEmpty) {
        await _apply(remote); // fresh install: bring the account's data down
      } else if (remote.stamp == _meta.remoteStamp) {
        pushAfter = _meta.dirty;
      } else if (remote.stamp > _meta.remoteStamp) {
        // The cloud copy changed since we last synced (e.g. edited on the web).
        if (_sameState(remote.state)) {
          _meta = _Meta(remoteStamp: remote.stamp, dirty: false, dirtyAt: 0);
          await _saveMeta();
        } else if (!_meta.dirty || remote.stamp >= _meta.dirtyAt) {
          await _apply(remote);
        } else {
          pushAfter = true; // our edit is the more recent one
          forcePush = true;
        }
      } else {
        pushAfter = _meta.dirty;
      }
    } catch (_) {
      // Offline or Firestore unreachable — local storage stays the source of truth.
    } finally {
      _busy = false;
    }
    if (pushAfter) await _push(uid, force: forcePush);
  }

  /// Kept for the existing call site in main.dart.
  Future<void> pullIfFreshInstall(String uid) async {
    startListening(uid);
    await syncOnLaunch(uid);
  }

  // ---- internals ----

  Future<bool> _push(String uid, {bool force = false}) async {
    if (_busy && !force) return false;
    final wasBusy = _busy;
    _busy = true;
    try {
      await _loadMeta();
      await store.flush();
      if (!force) {
        final remote = await _fetchRemote(uid);
        if (remote != null &&
            remote.stamp > _meta.remoteStamp &&
            remote.stamp >= _meta.dirtyAt &&
            !_sameState(remote.state)) {
          await _apply(remote); // the web app wrote later than our last edit
          return true;
        }
      }
      await _doc(uid).set({
        'state': store.state.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final after = await _doc(uid).get(const GetOptions(source: Source.server));
      final stamp = _stampOf(after.data());
      _meta = _Meta(remoteStamp: stamp > 0 ? stamp : DateTime.now().millisecondsSinceEpoch, dirty: false, dirtyAt: 0);
      await _saveMeta();
      return true;
    } catch (_) {
      return false; // stays dirty; retried on the next edit / resume
    } finally {
      _busy = wasBusy;
    }
  }

  Future<_Remote?> _fetchRemote(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    final state = data?['state'];
    if (state is! Map) return null;
    return _Remote(Map<String, dynamic>.from(state), _stampOf(data));
  }

  int _stampOf(Map<String, dynamic>? data) {
    final t = data?['updatedAt'];
    return t is Timestamp ? t.millisecondsSinceEpoch : 0;
  }

  bool _sameState(Map<String, dynamic> remoteState) {
    try {
      return jsonEncode(remoteState) == jsonEncode(store.state.toJson());
    } catch (_) {
      return false;
    }
  }

  Future<void> _apply(_Remote remote) async {
    _applying = true;
    try {
      await store.replaceState(AppState.fromJson(remote.state));
    } finally {
      _applying = false;
    }
    _meta = _Meta(remoteStamp: remote.stamp, dirty: false, dirtyAt: 0);
    await _saveMeta();
  }

  // ---- tiny sidecar file: what we last synced, and whether edits are pending ----

  Future<File> _metaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cloud_sync_meta.json');
  }

  Future<void> _loadMeta() async {
    if (_metaLoaded) return;
    try {
      final f = await _metaFile();
      if (await f.exists()) _meta = _Meta.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {}
    _metaLoaded = true;
  }

  Future<void> _saveMeta() async {
    try {
      await (await _metaFile()).writeAsString(jsonEncode(_meta.toJson()));
    } catch (_) {}
  }

  Future<void> _markDirty() async {
    await _loadMeta();
    _meta = _Meta(remoteStamp: _meta.remoteStamp, dirty: true, dirtyAt: DateTime.now().millisecondsSinceEpoch);
    await _saveMeta();
  }
}

class _Remote {
  _Remote(this.state, this.stamp);
  final Map<String, dynamic> state;
  final int stamp;
}

class _Meta {
  _Meta({this.remoteStamp = 0, this.dirty = false, this.dirtyAt = 0});
  final int remoteStamp;
  final bool dirty;
  final int dirtyAt;
  factory _Meta.fromJson(Map<String, dynamic> j) => _Meta(
      remoteStamp: (j['remoteStamp'] as num?)?.toInt() ?? 0,
      dirty: j['dirty'] == true,
      dirtyAt: (j['dirtyAt'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() => {'remoteStamp': remoteStamp, 'dirty': dirty, 'dirtyAt': dirtyAt};
}
