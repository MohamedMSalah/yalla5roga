import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_local_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

class SavedOutingsRepositoryImpl implements SavedOutingsRepository {
  SavedOutingsRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
    required this.currentUserId,
    this.mediaUploads,
  });

  final SavedOutingsRemoteDataSource remote;
  final SavedOutingsLocalDataSource local;
  final NetworkInfo networkInfo;
  final String? Function() currentUserId;
  final MediaUploadService? mediaUploads;
  Future<void> _draftTail = Future.value();
  Future<Either<Failure, List<OutingDraft>>>? _draftRead;
  String? _draftReadUid;

  Future<Either<Failure, List<OutingDraft>>> _serialize(
    Future<List<OutingDraft>> Function(String uid) action,
  ) {
    final uid = currentUserId();
    final completer = Completer<Either<Failure, List<OutingDraft>>>();
    _draftTail = _draftTail.then((_) async {
      if (uid == null || currentUserId() != uid) {
        completer.complete(const Left(AuthFailure()));
        return;
      }
      try {
        completer.complete(Right(await action(uid)));
      } catch (_) {
        completer.complete(const Left(CacheFailure()));
      }
    });
    return completer.future;
  }

  void _checkAccount(String uid) {
    if (currentUserId() != uid) throw StateError('Account changed');
  }

  String _stableId(String id, String uid) {
    if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return id;
    final hash = sha256.convert(utf8.encode('$uid:$id')).toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-4${hash.substring(13, 16)}-a${hash.substring(17, 20)}-${hash.substring(20, 32)}';
  }

  Future<List<OutingDraft>> _syncDrafts(String uid) async {
    var cached = await local.getDrafts();
    _checkAccount(uid);
    if (OfflineSnapshots.cacheOnly || !await networkInfo.isConnected) {
      return cached.where((d) => (!d.deleted || d.conflict)).toList();
    }
    List<OutingDraft> server;
    try {
      server = await remote.getDrafts();
    } catch (_) {
      return cached.where((d) => (!d.deleted || d.conflict)).toList();
    }
    _checkAccount(uid);
    final rows = {for (final draft in server) draft.id: draft};
    for (final draft in cached) {
      _checkAccount(uid);
      if (!draft.pending || draft.conflict) continue;
      final id = _stableId(draft.id, uid);
      final incoming = rows[id];
      var outgoing = draft.withSync(id: id);
      if (id != draft.id) {
        await local.saveDraft(outgoing);
        await local.removeDraft(draft.id);
      }
      _checkAccount(uid);
      if (incoming != null && incoming.remoteVersion != draft.remoteVersion) {
        if (!draft.deleted && remote.sameDraft(outgoing, incoming)) {
          await local.saveDraft(
            OutingDraft.fromJson({
              ...incoming.toJson(),
              'guestPhones': draft.guestPhones,
              if (draft.image.isNotEmpty && incoming.image.isEmpty)
                'image': draft.image,
            }),
          );
          continue;
        }
        // A response-loss create may have succeeded; never blindly overwrite it.
        await local.saveDraft(outgoing.withSync(conflict: true));
        continue;
      }
      if (draft.remoteVersion != null && incoming == null) {
        if (draft.deleted) {
          await local.removeDraft(id);
        } else {
          await local.saveDraft(outgoing.withSync(conflict: true));
        }
        continue;
      }
      try {
        if (draft.deleted) {
          if (incoming != null) await remote.deleteDraft(outgoing);
          _checkAccount(uid);
          await local.removeDraft(id);
          rows.remove(id);
        } else {
          _checkAccount(uid);
          if (isLocalFilePath(outgoing.image)) {
            if (mediaUploads == null) continue;
            final uploaded = await mediaUploads!.uploadLocalImage(
              path: outgoing.image,
              purpose: MediaPurpose.outing,
            );
            _checkAccount(uid);
            outgoing = OutingDraft.fromJson({
              ...outgoing.toJson(),
              'image': uploaded.reference,
            });
            await local.saveDraft(outgoing);
          }
          _checkAccount(uid);
          final committed = incoming == null
              ? await remote.createDraft(outgoing)
              : await remote.updateDraft(outgoing);
          _checkAccount(uid);
          outgoing = OutingDraft.fromJson({
            ...committed.toJson(),
            'guestPhones': draft.guestPhones,
            if (draft.image.isNotEmpty && committed.image.isEmpty)
              'image': draft.image,
          });
          await local.saveDraft(outgoing);
          rows[id] = outgoing;
        }
      } on DioException catch (error) {
        _checkAccount(uid);
        if (error.response?.statusCode == 409 ||
            error.response?.statusCode == 400 ||
            error.response?.statusCode == 403 ||
            error.response?.statusCode == 404) {
          await local.saveDraft(outgoing.withSync(conflict: true));
        }
        // Transient failures retain the pending write for the next reconnect.
      } catch (_) {
        /* Keep pending changes after transport failures. */
      }
    }
    _checkAccount(uid);
    cached = await local.getDrafts();
    for (final incoming in rows.values) {
      final previous = cached.where((d) => d.id == incoming.id).firstOrNull;
      if (previous?.pending == true) continue;
      await local.saveDraft(
        OutingDraft.fromJson({
          ...incoming.toJson(),
          if (previous != null) 'guestPhones': previous.guestPhones,
          if (previous != null && incoming.image.isEmpty)
            'image': previous.image,
        }),
      );
    }
    for (final old in cached) {
      if (!old.pending && !rows.containsKey(old.id)) {
        await local.removeDraft(old.id);
      }
    }
    return (await local.getDrafts())
        .where((d) => (!d.deleted || d.conflict))
        .toList();
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> getSaved() {
    return guardRemote(networkInfo, remote.getSaved, reason: 'getSavedOutings');
  }

  @override
  Future<Either<Failure, List<OutingDraft>>> getDrafts() {
    if (_draftReadUid != currentUserId()) {
      _draftRead = null;
      _draftReadUid = currentUserId();
    }
    return _draftRead ??= _serialize(_syncDrafts)
        .whenComplete(() => _draftRead = null);
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> saveOuting(SavedOuting outing) {
    return guardRemote(networkInfo, () async {
      await remote.save(outing.id);
      return remote.getSaved();
    }, reason: 'saveOuting');
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> removeSaved(String id) {
    return guardRemote(networkInfo, () async {
      await remote.unsave(id);
      return remote.getSaved();
    }, reason: 'unsaveOuting');
  }

  @override
  Future<Either<Failure, List<OutingDraft>>> saveDraft(OutingDraft draft) =>
      _serialize((uid) async {
        final current = (await local.getDrafts())
            .where((d) => d.id == draft.id)
            .firstOrNull;
        _checkAccount(uid);
        // Use the form's original version, not a fresher cache entry fetched meanwhile.
        await local.saveDraft(
          draft.withSync(
            version: draft.remoteVersion ?? current?.remoteVersion,
            pending: true,
            conflict: false,
          ),
        );
        return _syncDrafts(uid);
      });

  @override
  Future<Either<Failure, List<OutingDraft>>> removeDraft(String id) =>
      _serialize((uid) async {
        final draft = (await local.getDrafts())
            .where((d) => d.id == id)
            .firstOrNull;
        _checkAccount(uid);
        if (draft != null) {
          await local.saveDraft(draft.withSync(pending: true, deleted: true));
        }
        return _syncDrafts(uid);
      });

  @override
  Future<Either<Failure, bool>> isSaved(String id) async {
    final saved = await getSaved();
    return saved.map((list) => list.any((item) => item.id == id));
  }
}
