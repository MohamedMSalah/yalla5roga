/// Stable machine codes for [Failure] / [AppException] → user message mapping.
///
/// Firebase Auth codes stay as Firebase strings (see [AuthErrorCodes]).
abstract final class ErrorCodes {
  static const network = 'network';
  static const timeout = 'timeout';
  static const unauthorized = 'unauthorized';
  static const forbidden = 'forbidden';
  static const notFound = 'not-found';
  static const conflict = 'conflict';
  static const validation = 'validation';
  static const server = 'server';
  static const parse = 'parse';
  static const cache = 'cache';
  static const unexpected = 'unexpected';
  static const socket = 'socket';
}
