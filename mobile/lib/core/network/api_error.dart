import 'package:dio/dio.dart';

/// Turns any thrown error into a short message that is safe to show a user.
String apiErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
    }
    if (e.response?.statusCode == 409) {
      return 'Finish or leave your current challenge before starting another one.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Can't reach the server. Check your connection and try again.";
    }
  }
  return 'Something went wrong. Please try again.';
}
