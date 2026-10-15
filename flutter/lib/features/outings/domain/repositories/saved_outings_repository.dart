import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';

abstract class SavedOutingsRepository {
  Future<Either<Failure, List<SavedOuting>>> getSaved();

  Future<Either<Failure, List<OutingDraft>>> getDrafts();

  Future<Either<Failure, List<SavedOuting>>> saveOuting(SavedOuting outing);

  Future<Either<Failure, List<SavedOuting>>> removeSaved(String id);

  Future<Either<Failure, List<OutingDraft>>> saveDraft(OutingDraft draft);

  Future<Either<Failure, List<OutingDraft>>> removeDraft(String id);

  Future<Either<Failure, bool>> isSaved(String id);
}
