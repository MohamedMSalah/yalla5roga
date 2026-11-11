exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'core/network/dio_interceptors.dart',
 ('class AuthInterceptor extends QueuedInterceptor', 'class AuthInterceptor extends Interceptor'),
 ('  Dio? _dio;', '''  Dio? _dio;
  final _refreshes = <String?, Future<String?>>{};

  Future<String?> _refresh(IdTokenProvider provider) {
    final uid = currentUserId?.call();
    return _refreshes.putIfAbsent(uid, () =>
      provider(forceRefresh: true).whenComplete(() => _refreshes.remove(uid)),
    );
  }'''),
 ('final token = await provider(forceRefresh: true);','final token = await _refresh(provider);'))
edit(f+'core/network/request_deduper.dart',
 ('      _inFlight.remove(key);','      if (identical(_inFlight[key], future)) _inFlight.remove(key);'))
edit(f+'features/chat/data/datasources/outing_chat_socket_client.dart',
 ('  var _authRetryScheduled = false;', '  var _authRetryScheduled = false;\n  var _forceTokenRefresh = false;'),
 ('      final token = await tokenProvider();','''      final token = await tokenProvider(forceRefresh: _forceTokenRefresh);
      _forceTokenRefresh = false;'''),
 ('      _socket = socket;', '      _socket = socket;'),
 ('''    } finally {
      if (session == _session) _connecting = false;''','''    } catch (error) {
      if (session == _session) _emitConnection(false);
    } finally {
      if (session == _session) {
        _connecting = false;
        if (!(_connectCompleter?.isCompleted ?? true)) _connectCompleter?.complete();
      }'''),
 ('    _authRetryScheduled = false;\n    _desiredOutingIds.clear();','    _authRetryScheduled = false;\n    _forceTokenRefresh = false;\n    _desiredOutingIds.clear();'),
 ('      _authRetryScheduled = false;\n      await ensureConnected();','      _authRetryScheduled = false;\n      _forceTokenRefresh = true;\n      await ensureConnected();'))
edit(f+'features/chat/data/repositories/outing_chat_repository_impl.dart',
 ('            if (failure.statusCode == 403 || failure.statusCode == 404)', '            if (failure.statusCode == 401 || failure.statusCode == 403 || failure.statusCode == 404)'),
 ('''              await local.saveMessages(outingId, []);
              return Left(failure);''','''              await local.saveMessages(outingId, []);
              return Left(failure);'''),
 ('''      } on AppException catch (error) {
        return Left(ExceptionMapper.toFailure(error));
      }''','''      } on AppException catch (error) {
        return Left(ExceptionMapper.toFailure(error));
      } catch (_) {
        return const Left(CacheFailure('Could not save the pending message'));
      }'''))
edit(f+'features/chat/presentation/providers/outing_chat_provider.dart',
 ('        if (failure.statusCode == 403 || failure.statusCode == 404)', '        if (failure.statusCode == 401 || failure.statusCode == 403 || failure.statusCode == 404)'),
 ('''    final result = await repository.markRead(outingId);''','''    if (_socket != null && !_socket.isConnected) return;
    final result = await repository.markRead(outingId);'''),
 ('''      unawaited(_recoverActiveRoomsFromRest());''','''      unawaited(recoverActiveChats());'''),
 ('''  Future<void> _recoverActiveRoomsFromRest() async {''','''  Future<void> recoverActiveChats() async {
    _recoveryDebounce?.cancel();
    _recoveryDebounce = null;'''),
 ('''    await _recoverActiveRoomsFromRest();''','''    await recoverActiveChats();'''))
edit(f+'core/network/app_sync_provider.dart',
 ("import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';","import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';\nimport 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';"),
 ('    required this.flushSends,','    required this.flushSends,\n    required this.chat,'),
 ('  final Future<bool> Function() flushSends;', '  final Future<bool> Function() flushSends;\n  final OutingChatProvider chat;'),
 ('  bool _inboxDirty = false;', '  bool _inboxDirty = false;\n  bool _chatDirty = false;'),
 ('_profileDirty = _inboxDirty = false;', '_profileDirty = _inboxDirty = _chatDirty = false;'),
 ("      case 'membership':\n        _outingsDirty", "      case 'membership':\n        _chatDirty = true;\n        _outingsDirty"),
 ("      case 'outings':\n        _outingsDirty", "      case 'outings':\n        _chatDirty = true;\n        _outingsDirty"),
 ('    final inbox = full || _inboxDirty;', '    final inbox = full || _inboxDirty;\n    final chatChanged = full || _chatDirty;'),
 ('_profileDirty = _inboxDirty = false;', '_profileDirty = _inboxDirty = _chatDirty = false;'),
 ('        if (loadOutings) outings.load(forceRefresh: true),','        if (loadOutings) outings.load(forceRefresh: true),\n        if (chatChanged) chat.recoverActiveChats(),'))
# Keep chat construction ahead of the sync provider while binding the enqueue callback.
edit(f+'core/di/app_dependencies.dart',
 ('''    final sync = AppSyncProvider(''','''    late final AppSyncProvider sync;
    final outingChat = OutingChatProvider(
      repository: chatRepository,
      sendUpdates: queue.updates,
      onQueued: () => sync.sendsChanged(),
      persistLiveMessage: chatRepository.persistLiveMessage,
      socketClient: outingChatSocket,
    );
    sync = AppSyncProvider(
      chat: outingChat,'''),
 ('''      outingChat: OutingChatProvider(
        repository: chatRepository,
        sendUpdates: queue.updates,
        onQueued: sync.sendsChanged,
        persistLiveMessage: chatRepository.persistLiveMessage,
        socketClient: outingChatSocket,
      ),''','''      outingChat: outingChat,'''))
edit(f+'features/chat/presentation/pages/outing_chat_page.dart',
 ('''class _OutingChatPageState extends State<OutingChatPage>
    with WidgetsBindingObserver {''','''class _OutingChatPageState extends State<OutingChatPage> {'''),
 ('    WidgetsBinding.instance.addObserver(this);','    _outings = context.read<OutingsProvider>()..openOuting(_outingId);'),
 ('  OutingChatProvider? _chat;', '  OutingChatProvider? _chat;\n  OutingsProvider? _outings;'),
 ('''  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final chat = _chat;
    if (chat == null) return;
    // Avoid BuildContext here — provider already tracks the subscribed user.
    unawaited(chat.recoverAfterResume());
  }

''',''),
 ('    WidgetsBinding.instance.removeObserver(this);','    _outings?.closeOuting(_outingId);'))
edit(f+'features/shell/presentation/pages/main_shell.dart',
 ('''  /// Home content first. Groups, notifications, and saved outings follow so
  /// they do not compete with the first screen.''','''  /// Start cache hydration before warming the other tabs.'''),
 ('''    if (!mounted) return;
    StartupTrace.mark('home_feed_ready');

    // Let featured outings paint (and start image decode) before discover
    // covers and the other tabs' data hit the UI thread together.''','''    // Give the initial cached content a frame before warming Discover.'''),
 ('''    await synchronization;
    if (!mounted) return;''','''    await synchronization;
    if (!mounted) return;
    StartupTrace.mark('home_feed_ready');'''))
edit('backend/src/realtime/chat-emitter.ts',
 ('''  const sockets = await io.in(outingChatRoom(outingId)).fetchSockets();
  const recipients = sockets.filter((socket) => authorized.has(socket.data.uid));
  for (const socket of recipients) socket.emit("outing:message", serializeChatMessage(message));''','''  const payload = serializeChatMessage(message);
  try {
    const sockets = await io.in(outingChatRoom(outingId)).fetchSockets();
    for (const socket of sockets) {
      if (authorized.has(socket.data.uid)) socket.emit("outing:message", payload);
    }
  } catch (error) {
    console.error("[realtime] chat delivery failed", error);
  }'''))
