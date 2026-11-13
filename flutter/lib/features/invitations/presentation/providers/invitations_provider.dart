import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/domain/repositories/invitations_repository.dart';

class InvitationsProvider extends ChangeNotifier {
  InvitationsProvider({required this.repository});

  final InvitationsRepository repository;

  List<GroupInvitation> _items = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isAccepting = false;
  bool _isDeclining = false;
  String? _errorMessage;
  int _epoch = 0;
  int _loadGeneration = 0;
  String? processingId;

  List<GroupInvitation> get items => List.unmodifiable(_items);

  int get pendingCount =>
      _items.where((i) => i.status == InvitationStatus.pending).length;

  bool get isLoading => _isLoading;

  bool get isAccepting => _isAccepting;

  bool get isDeclining => _isDeclining;

  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoading => !_hasLoaded;

  String? get errorMessage => _errorMessage;

  Future<void> loadInvitations({bool forceRefresh = false}) async {
    final account = _epoch;
    final token = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getInvitations(forceRefresh: forceRefresh);
    if (account != _epoch || token != _loadGeneration) return;

    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'loadInvitations',
        );
      },
      (items) {
        _items = List.of(items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _errorMessage = null;
      },
    );

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> acceptInvitation(String invitationId) async {
    if (_isAccepting || _isDeclining) return false;
    final account = _epoch;
    processingId = invitationId;
    _isAccepting = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.acceptInvitation(invitationId);
    if (account != _epoch) return false;

    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'acceptInvitation',
        );
        return false;
      },
      (_) {
        _errorMessage = null;
        return true;
      },
    );

    _isAccepting = false;
    processingId = null;
    if (ok) onInvitationAccepted(invitationId);
    notifyListeners();
    return ok;
  }

  Future<bool> declineInvitation(String invitationId) async {
    if (_isAccepting || _isDeclining) return false;
    final account = _epoch;
    processingId = invitationId;
    _isDeclining = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.declineInvitation(invitationId);
    if (account != _epoch) return false;

    final ok = result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'declineInvitation',
        );
        return false;
      },
      (_) {
        _errorMessage = null;
        return true;
      },
    );

    _isDeclining = false;
    processingId = null;
    if (ok) onInvitationDeclined(invitationId);
    notifyListeners();
    return ok;
  }

  void _recordDecision(String id, InvitationStatus status) {
    // Discard reads started before the decision and preserve the history row.
    _loadGeneration++;
    _isLoading = false;
    _items = [
      for (final item in _items)
        if (item.invitationId == id) item.copyWithStatus(status) else item,
    ];
    notifyListeners();
  }

  void onInvitationAccepted(String id) =>
      _recordDecision(id, InvitationStatus.accepted);
  void onInvitationDeclined(String id) =>
      _recordDecision(id, InvitationStatus.declined);

  /// Called when a real-time invalidation arrives — refresh if stale.
  void invalidate() {
    if (_hasLoaded) {
      unawaited(loadInvitations(forceRefresh: true));
    }
  }

  void clear() {
    _epoch++;
    _loadGeneration++;
    processingId = null;
    repository.clearCache();
    _items = [];
    _isLoading = false;
    _hasLoaded = false;
    _isAccepting = false;
    _isDeclining = false;
    _errorMessage = null;
    notifyListeners();
  }
}
