import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';
import 'package:yalla_5roga/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class _Online implements NetworkInfo {
  bool online = true;
  @override
  Future<bool> get isConnected async => online;
}

class _FirebaseAuth extends Fake implements fb.FirebaseAuth {}

class _Credential extends Fake implements fb.UserCredential {}

class _User extends Fake implements fb.User {
  @override
  String get uid => 'B';
  @override
  String? get phoneNumber => '+201001234567';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  Future<void> reload() async {}
}

class _Firebase extends FirebaseAuthService {
  _Firebase({this.proof}) : super(auth: _FirebaseAuth());
  String? proof;
  @override
  String? get pendingPhoneVerificationToken => proof;
  @override
  void clearPhoneVerificationToken() => proof = null;
  @override
  fb.User? get currentUser => _User();
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      'canonical-token';
  @override
  Future<String> verifyPhoneOtpThenSignOut({
    required String verificationId,
    required String smsCode,
  }) async => 'verified-otp-proof';
  @override
  Future<fb.UserCredential> signInWithCustomToken(String customToken) async =>
      _Credential();
  @override
  Future<void> debugPrintSwaggerIdToken() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = {
    'id': 'B',
    'name': 'B',
    'phone': '+201001234567',
    'has_password': true,
  };

  Future<AuthRepositoryImpl> authRepository(
    Dio dio, {
    _Firebase? firebase,
    NetworkInfo? network,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = AuthLocalDataSourceImpl(prefs);
    await local.cacheUser(
      const UserModel(id: 'B', name: 'B', phone: '+201001234567'),
    );
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(ApiClient(dio)),
      local: local,
      networkInfo: network ?? _Online(),
      firebaseAuth: firebase ?? _Firebase(),
    );
  }

  void resolve(
    RequestOptions request,
    RequestInterceptorHandler handler,
    Object data,
  ) {
    handler.resolve(
      Response(
        requestOptions: request,
        statusCode: 200,
        data: {'success': true, 'data': data},
      ),
    );
  }

  test('registration passes Firebase OTP proof to the signup API', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          resolve(request, handler, {
            'uid': 'B',
            'idToken': 'id',
            'customToken': 'custom',
            'refreshToken': 'refresh',
            'expiresIn': '3600',
            'user': profile,
          });
        },
      ),
    );
    final repository = await authRepository(dio);
    final result = await repository.register(
      name: 'B',
      password: 'secret123',
      phone: '01001234567',
      verificationId: 'otp',
      smsCode: '123456',
    );
    expect(result.isRight(), isTrue);
    expect(requests.single.path, '/api/auth/signup');
    expect(
      (requests.single.data as Map)['phoneVerificationToken'],
      'verified-otp-proof',
    );
    result.fold((failure) => fail(failure.message), (user) {
      expect(user.id, 'B');
      expect(user.phoneVerified, isTrue);
    });
  });

  test('offline session restores cached profile before online profile revalidation', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final started = Completer<void>();
    final release = Completer<void>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          expect(request.path, '/api/users/cuser');
          expect(request.method, 'GET');
          started.complete();
          await release.future;
          resolve(request, handler, profile);
        },
      ),
    );
    final network = _Online()..online = false;
    final auth = AuthProvider(
      repository: await authRepository(dio, network: network),
    );
    addTearDown(auth.dispose);
    await auth.restoreSession();
    expect(auth.user?.id, 'B');
    expect(auth.user?.hasPassword, isFalse);
    expect(started.isCompleted, isFalse);

    network.online = true;
    final refresh = auth.refreshProfile();
    await started.future;
    expect(auth.user?.hasPassword, isFalse);
    release.complete();
    await refresh;
    expect(auth.user?.hasPassword, isTrue);
  });

  test('phone verification sync uses the invitation-claim endpoint', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          resolve(request, handler, profile);
        },
      ),
    );
    final result = await (await authRepository(dio))
        .syncProfileToBackend(phone: '+201001234567');
    expect(result.isRight(), isTrue);
    expect(requests.single.path, '/api/users/sync');
    expect(requests.single.method, 'POST');
  });

  test(
    'cached startup defers account sync, coalesces it, and runs it once',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final started = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests++;
            expect(request.path, '/api/users/sync');
            expect(request.method, 'POST');
            started.complete();
            await release.future;
            resolve(request, handler, profile);
          },
        ),
      );
      final auth = AuthProvider(repository: await authRepository(dio));
      addTearDown(auth.dispose);
      await auth.restoreSession();
      expect(auth.user?.id, 'B');
      expect(requests, 0);
      final first = auth.synchronizeRestoredAccount();
      final duplicate = auth.synchronizeRestoredAccount();
      expect(identical(first, duplicate), isTrue);
      await started.future;
      expect(auth.user?.hasPassword, isFalse);
      release.complete();
      expect(await first, isTrue);
      expect(auth.user?.hasPassword, isTrue);
      expect(await auth.synchronizeRestoredAccount(), isFalse);
      expect(requests, 1);
    },
  );

  test(
    'legacy OTP proof sync preserves the canonical account and clears proof',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final firebase = _Firebase(proof: 'legacy-otp-proof');
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            resolve(request, handler, profile);
          },
        ),
      );
      final repository = await authRepository(dio, firebase: firebase);
      final result = await repository.syncProfileToBackend(
        phone: '+201001234567',
      );
      expect(requests.single.path, '/api/users/sync');
      expect(
        (requests.single.data as Map)['phoneVerificationToken'],
        'legacy-otp-proof',
      );
      result.fold((failure) => fail(failure.message), (user) {
        expect(user.id, 'B');
        expect(user.phoneVerified, isTrue);
      });
      expect(firebase.proof, isNull);
    },
  );

  test('logout clears the visible list and ignores a response from the previous account', () async {
    final dio = Dio();
    addTearDown(dio.close);
    var uid = 'A';
    final startedA = Completer<void>();
    final releaseA = Completer<void>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          final caller = uid;
          if (caller == 'A') {
            startedA.complete();
            await releaseA.future;
          }
          resolve(request, handler, [
            {'id': 'group-$caller', 'name': 'Group $caller'},
          ]);
        },
      ),
    );
    final shell = ShellProvider();
    addTearDown(shell.dispose);
    final repository = GroupsRepositoryImpl(
      remote: GroupsRemoteDataSource(ApiClient(dio)),
      networkInfo: _Online(),
      currentUserId: () => uid,
    );
    final groups = GroupsProvider(repository: repository, shell: shell);
    addTearDown(groups.dispose);
    final first = groups.refresh();
    await startedA.future;
    groups.clear();
    expect(groups.groups, isEmpty);
    expect(groups.hasLoaded, isFalse);
    uid = 'B';
    await groups.refresh();
    expect(groups.groups.single.id, 'group-B');
    releaseA.complete();
    await first;
    expect(groups.groups.single.id, 'group-B');
    await groups.refresh();
    expect(groups.groups.single.id, 'group-B');
    groups.clear();
    expect(groups.groups, isEmpty);
    expect(groups.hasLoaded, isFalse);
  });

  test('list caches are scoped by the current account without another HTTP request on cache hits', () async {
    final dio = Dio();
    addTearDown(dio.close);
    var uid = 'A';
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests++;
          resolve(request, handler, [
            {'id': 'group-$uid', 'name': 'Group $uid'},
          ]);
        },
      ),
    );
    final repository = GroupsRepositoryImpl(
      remote: GroupsRemoteDataSource(ApiClient(dio)),
      networkInfo: _Online(),
      currentUserId: () => uid,
    );
    await repository.getGroups();
    await repository.getGroups();
    expect(requests, 1);
    uid = 'B';
    final result = await repository.getGroups();
    result.fold(
      (failure) => fail(failure.message),
      (groups) => expect(groups.single.id, 'group-B'),
    );
    expect(requests, 2);
  });
  test('targeted group details update the cached list without another list request', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final requests = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          if (request.path.endsWith('/cuser')) {
            resolve(request, handler, [
              {'id': 'group', 'name': 'Old name'},
            ]);
          } else if (request.path.endsWith('/members')) {
            resolve(request, handler, <Object>[]);
          } else {
            resolve(request, handler, {'id': 'group', 'name': 'New name'});
          }
        },
      ),
    );
    final repository = GroupsRepositoryImpl(
      remote: GroupsRemoteDataSource(ApiClient(dio)),
      networkInfo: _Online(),
      currentUserId: () => 'alice',
    );
    await repository.getGroups();
    await repository.getGroup('group', forceRefresh: true);
    final result = await repository.getGroups();
    result.fold(
      (failure) => fail(failure.message),
      (groups) => expect(groups.single.name, 'New name'),
    );
    expect(requests.where((path) => path.endsWith('/cuser')).length, 1);
  });
}
