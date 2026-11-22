import '../core/network/api_client.dart';

class StripeService {
  static Future<Map<String, dynamic>> checkout(int planId, String requestId) =>
      Api.post('payments/stripe/checkout', {
        'plan_id': planId,
        'request_id': requestId,
      });
  static Future<Map<String, dynamic>> status(String id) =>
      Api.get('payments/stripe/orders/$id');
  static Future<List<Map<String, dynamic>>> history() =>
      Api.list('payments/stripe/history');
  static Future<Map<String, dynamic>> cancel(String id) =>
      Api.post('payments/stripe/orders/$id/cancel');
  static Future<Map<String, dynamic>> reconcile(String id) =>
      Api.post('payments/stripe/orders/$id/reconcile', {});
  static Future<Map<String, dynamic>> portal() =>
      Api.post('payments/stripe/portal');
}
