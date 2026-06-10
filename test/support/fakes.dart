import 'dart:typed_data';

import 'package:myroom/core/failures.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/shared/ai/domain/ai_resource.dart';
import 'package:myroom/shared/ai/domain/ai_service.dart';
import 'package:myroom/shared/ai/domain/classification.dart';
import 'package:myroom/shared/auth/domain/app_user.dart';
import 'package:myroom/shared/auth/domain/auth_repo.dart';
import 'package:myroom/shared/storage/storage_repo.dart';

/// In-memory [StorageRepo] for repo tests — records uploads so the note repo's
/// content-addressed upload flow can be asserted without Firebase Storage.
class FakeStorageRepo implements StorageRepo {
  final Map<String, Uint8List> uploaded = {};

  /// When true, the next [upload] returns an [Err] (to test the abort path).
  bool failUploads = false;

  @override
  Future<Result<UploadedFile>> upload({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (failUploads) return const Err(NetworkFailure());
    uploaded[path] = bytes;
    return Ok(
      UploadedFile(storagePath: path, downloadUrl: 'https://fake.test/$path'),
    );
  }

  @override
  Future<Result<void>> delete(String storagePath) async {
    uploaded.remove(storagePath);
    return const Ok(null);
  }

  @override
  Future<Uint8List> download(String storagePath) async =>
      uploaded[storagePath] ?? Uint8List(0);

  @override
  Future<String> downloadUrl(String storagePath) async =>
      'https://fake.test/$storagePath';
}

/// Stub [AiService] for widget tests — records calls and returns canned results
/// (no Cloud Functions). Tune the public fields per test.
class FakeAiService implements AiService {
  final List<String> chatCalls = [];
  final List<String> classifyCalls = [];
  List<ClassificationItem> classifyResult = const [];
  List<AiResource> recommendations = const [];
  String eraInsight = 'AI 生成的洞察';

  @override
  Future<Result<String>> chat(String message) async {
    chatCalls.add(message);
    return const Ok('好的，已為你處理。');
  }

  @override
  Future<Result<List<ClassificationItem>>> classifyMultiInput({
    required String text,
    List<String> images = const [],
    String fileText = '',
    List<AiAttachmentRef> attachments = const [],
    String? userSpecifiedCat,
  }) async {
    classifyCalls.add(text);
    return Ok(classifyResult);
  }

  @override
  Future<Result<List<AiResource>>> fetchRecommendations(
    List<String> ideaTexts,
  ) async => Ok(recommendations);

  @override
  Future<Result<String>> generateEraInsight({
    required String eraLabel,
    required String dataSummary,
  }) async => Ok(eraInsight);

  @override
  Future<Result<String>> transcribe({
    required Uint8List audioBytes,
    required String filename,
  }) async => const Ok('轉錄文字');

  @override
  Future<Result<String>> exportRecap(String recapId) async =>
      const Ok('users/u/exports/r.svg');

  @override
  Future<Result<String>> exportAchievement({
    required String achievementId,
    required String era,
  }) async => const Ok('users/u/exports/a.svg');
}

/// Stub [AuthRepo] for widget tests — records sign-in calls; everything succeeds.
class FakeAuthRepo implements AuthRepo {
  FakeAuthRepo({this.user = const AppUser(uid: 'userA', email: 'a@b.com')});

  final AppUser user;
  final List<({String email, String password})> signInCalls = [];
  int signOutCount = 0;

  @override
  Stream<AppUser?> get authState => Stream.value(user);

  @override
  String? get currentUserId => user.uid;

  @override
  Future<Result<void>> signIn(String email, String password) async {
    signInCalls.add((email: email, password: password));
    return const Ok(null);
  }

  @override
  Future<Result<void>> signUp(String email, String password) async =>
      const Ok(null);

  @override
  Future<Result<void>> signInWithGoogle() async => const Ok(null);

  @override
  Future<Result<void>> signInWithApple() async => const Ok(null);

  @override
  Future<Result<void>> sendPasswordReset(String email) async => const Ok(null);

  @override
  Future<Result<void>> signOut() async {
    signOutCount++;
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteAccount({String? password}) async =>
      const Ok(null);
}
