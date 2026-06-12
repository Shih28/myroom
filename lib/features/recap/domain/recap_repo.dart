import '../../../core/result.dart';
import 'recap.dart';

abstract class RecapRepo {
  /// Streams `users/{uid}/recaps`, newest first.
  Stream<List<Recap>> watchRecaps();

  /// Creates a recap; returns the new doc id.
  Future<Result<String>> add(Recap recap);

  Future<Result<void>> update(Recap recap);

  Future<Result<void>> delete(String id);
}
