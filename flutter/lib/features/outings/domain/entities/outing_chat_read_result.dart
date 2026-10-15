class OutingChatReadResult {
  const OutingChatReadResult({
    required this.outingId,
    required this.unreadCount,
    required this.unreadChatCount,
  });

  final String outingId;
  final int unreadCount;
  final int unreadChatCount;
}
