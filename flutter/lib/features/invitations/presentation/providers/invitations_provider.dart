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
    final token = ++_epoch;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getInvitations(forceRefresh: forceRefresh);
    if (token != _epoch) return;

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
        _items = items
            .where((i) => i.status == InvitationStatus.pending)
            .toList();
        _errorMessage = null;
      },
    );

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<bool> acceptInvitation(String invitationId) async {
    if (_isAccepting) return false;
    final account = _epoch;
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
    notifyListeners();
    return ok;
  }

  Future<bool> declineInvitation(String invitationId) async {
    if (_isDeclining) return false;
    final account = _epoch;
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
    notifyListeners();
    return ok;
  }

  /// Remove a processed invitation from the local list after accept/decline.
  void _removeInvitation(String invitationId) {
    _items = _items.where((i) => i.invitationId != invitationId).toList();
    notifyListeners();
  }

  /// Called by parent (AppSyncProvider) after successful accept/decline
  /// to refresh the local list.
  void onInvitationAccepted(String invitationId) {
    _removeInvitation(invitationId);
  }

  void onInvitationDeclined(String invitationId) {
    _removeInvitation(invitationId);
  }

  /// Called when a real-time invalidation arrives — refresh if stale.
  void invalidate() {
    if (_hasLoaded) {
      unawaited(loadInvitations(forceRefresh: true));
    }
  }

  void clear() {
    _epoch++;
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
