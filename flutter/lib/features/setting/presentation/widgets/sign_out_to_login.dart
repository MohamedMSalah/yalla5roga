import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/auth/presentation/pages/auth_page.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

Future<void> signOutToLogin(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final notifications = context.read<NotificationsProvider>();
  final chat = context.read<OutingChatProvider>();
  final groups = context.read<GroupsProvider>();
  final outings = context.read<OutingsProvider>();
  final discover = context.read<DiscoverProvider>();
  final saved = context.read<SavedOutingsProvider>();
  final shell = context.read<ShellProvider>();
  await auth.logout();
  notifications.clear();
  chat.clear();
  groups.clear();
  outings.clear();
  discover.clear();
  saved.clear();
  shell.setIndex(0);
  Get.offAll(() => const AuthPage(), routeName: '/login');
}
