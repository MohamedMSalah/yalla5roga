import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_local_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

class SavedOutingsRepositoryImpl implements SavedOutingsRepository {
  const SavedOutingsRepositoryImpl({required this.local});

  final SavedOutingsLocalDataSource local;

  @override
  Future<Either<Failure, List<SavedOuting>>> getSaved() async {
    return Right(await local.getSaved());
  }

  @override
  Future<Either<Failure, List<OutingDraft>>> getDrafts() async {
    return Right(await local.getDrafts());
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> saveOuting(
    SavedOuting outing,
  ) async {
    return Right(await local.saveOuting(outing));
  }

  @override
  Future<Either<Failure, List<SavedOuting>>> removeSaved(String id) async {
    return Right(await local.removeSaved(id));
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
    return Right(await local.isSaved(id));
  }
}
