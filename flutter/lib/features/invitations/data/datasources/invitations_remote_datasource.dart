import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';

abstract class InvitationsRemoteDataSource {
  Future<List<GroupInvitation>> getInvitations();
  Future<void> acceptInvitation(String invitationId);
  Future<void> declineInvitation(String invitationId);
}

class InvitationsRemoteDataSourceImpl implements InvitationsRemoteDataSource {
  InvitationsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<GroupInvitation>> getInvitations() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.invitations,
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['items', 'data'],
      );
      return [for (final item in items) GroupInvitation.fromJson(item)];
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.invitationAccept(invitationId),
      );
      if (apiPayload(response.data)['status'] != 'accepted') {
        throw const ServerException(
          'Invitation was already decided',
          'conflict',
          409,
        );
      }
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.invitationDecline(invitationId),
      );
      if (apiPayload(response.data)['status'] != 'declined') {
        throw const ServerException(
          'Invitation was already decided',
          'conflict',
          409,
        );
      }
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
