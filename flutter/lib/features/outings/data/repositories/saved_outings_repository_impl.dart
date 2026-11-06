import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_local_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

class SavedOutingsRepositoryImpl implements SavedOutingsRepository {
  const SavedOutingsRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
  });

  final SavedOutingsRemoteDataSource remote;
  final SavedOutingsLocalDataSource local;
  final NetworkInfo networkInfo;

  @override
  Future<Either<Failure, List<SavedOuting>>> getSaved() {
    return guardRemote(
      networkInfo,
      remote.getSaved,
      reason: 'getSavedOutings',
    );
  }

  @override
  Future<Either<Failure, List<OutingDraft>>> getDrafts() async {
    return Right(await local.getDrafts());
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> saveOuting(
    SavedOuting outing,
  ) {
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
  Future<Either<Failure, List<OutingDraft>>> saveDraft(
    OutingDraft draft,
  ) async {
    return Right(await local.saveDraft(draft));
  }

  @override
  Future<Either<Failure, List<OutingDraft>>> removeDraft(String id) async {
    return Right(await local.removeDraft(id));
  }

  @override
  Future<Either<Failure, bool>> isSaved(String id) async {
    final saved = await getSaved();
    return saved.map((list) => list.any((item) => item.id == id));
  }
}
