import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapotech/shared/web_helpers.dart';

/// Helper service for Duitku QRIS dynamic payment creation and verification
class DuitkuPaymentService {
  static const String _kPendingOrderId = 'duitku_pending_order_id';
  static const String _kPendingPaymentUrl = 'duitku_pending_payment_url';
  static const String _kPendingQrString = 'duitku_pending_qr_string';
  static const String _kPendingAmount = 'duitku_pending_amount';
  static const String _kPendingUserId = 'duitku_pending_user_id';
  static const String _kPendingPackageType = 'duitku_pending_package_type';

  static String get _functionBaseUrl {
    final configured = dotenv.env['DUITKU_FUNCTION_URL']?.trim() ?? '';
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }
    return 'https://ikzjxurjhquohiazmowg.supabase.co/functions/v1';
  }

  /// Create a QRIS payment with the exact package price
  static Future<Map<String, dynamic>> createPayment({
    required String packageType,
    required int amount,
    required String customerEmail,
    required String customerName,
    String? paymentMethod,
  }) async {
    final merchantCode = dotenv.env['DUITKU_MERCHANT_CODE'] ?? 'DS24853';
    final merchantKey = dotenv.env['DUITKU_MERCHANT_KEY'] ?? '605d62af77cf1f18830c961b80cdbe9f';
    final method = paymentMethod ?? dotenv.env['DUITKU_PAYMENT_METHOD'] ?? 'NQ';

    final uri = Uri.parse('$_functionBaseUrl/create-duitku-payment');
    final payload = {
      'packageType': packageType,
      'amount': amount,
      'paymentAmount': amount,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'merchantCode': merchantCode,
      'merchantKey': merchantKey,
      'paymentMethod': method,
    };

    debugPrint('DuitkuPaymentService: Calling $uri with amount=$amount, pkg=$packageType');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    debugPrint('DuitkuPaymentService create response (${response.statusCode}): $data');

    if (response.statusCode == 200 && data['statusCode']?.toString() == '00') {
      return {
        'orderId': data['orderId']?.toString() ?? '',
        'paymentUrl': data['paymentUrl']?.toString() ?? '',
        'qrString': data['qrString']?.toString() ?? '',
        'amount': (data['amount'] as num?)?.toInt() ?? amount,
        'packageType': packageType,
      };
    } else {
      final msg = data['error']?.toString() ??
          data['statusMessage']?.toString() ??
          'Gagal membuat transaksi pembayaran.';
      throw Exception(msg);
    }
  }

  /// Check whether the order has been paid via Duitku
  static Future<bool> checkPaymentStatus(String orderId) async {
    final merchantCode = dotenv.env['DUITKU_MERCHANT_CODE'] ?? 'DS24853';
    final merchantKey = dotenv.env['DUITKU_MERCHANT_KEY'] ?? '605d62af77cf1f18830c961b80cdbe9f';

    final uri = Uri.parse('$_functionBaseUrl/check-duitku-status');
    final payload = {
      'merchantOrderId': orderId,
      'merchantCode': merchantCode,
      'merchantKey': merchantKey,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    debugPrint('DuitkuPaymentService check response (${response.statusCode}): $data');

    final statusCode = data['statusCode']?.toString() ?? '';
    final isPaid = data['isPaid'] == true || statusCode == '00';
    return isPaid;
  }

  /// Save pending payment to localStorage
  static void savePendingPayment({
    required String orderId,
    required String paymentUrl,
    required String qrString,
    required int amount,
    required String userId,
    required String packageType,
  }) {
    WebStorageHelper.setItem(_kPendingOrderId, orderId);
    WebStorageHelper.setItem(_kPendingPaymentUrl, paymentUrl);
    WebStorageHelper.setItem(_kPendingQrString, qrString);
    WebStorageHelper.setItem(_kPendingAmount, amount.toString());
    WebStorageHelper.setItem(_kPendingUserId, userId);
    WebStorageHelper.setItem(_kPendingPackageType, packageType);
  }

  /// Load pending payment from localStorage, validating package type & amount if given
  static Map<String, String>? loadPendingPayment({
    required String userId,
    String? expectedPackageType,
    int? expectedAmount,
  }) {
    final orderId = WebStorageHelper.getItem(_kPendingOrderId);
    final paymentUrl = WebStorageHelper.getItem(_kPendingPaymentUrl);
    final qrString = WebStorageHelper.getItem(_kPendingQrString) ?? '';
    final amountStr = WebStorageHelper.getItem(_kPendingAmount);
    final savedUserId = WebStorageHelper.getItem(_kPendingUserId);
    final packageType = WebStorageHelper.getItem(_kPendingPackageType) ?? 'subscription_30';

    if (orderId == null || paymentUrl == null || amountStr == null) return null;
    if (savedUserId != null && savedUserId != userId) return null;

    final parsedAmount = int.tryParse(amountStr);

    // If expected package type or amount doesn't match, clear old payment so user gets fresh QRIS
    if (expectedPackageType != null && packageType != expectedPackageType) {
      clearPendingPayment();
      return null;
    }
    if (expectedAmount != null && parsedAmount != expectedAmount) {
      clearPendingPayment();
      return null;
    }

    return {
      'orderId': orderId,
      'paymentUrl': paymentUrl,
      'qrString': qrString,
      'amount': amountStr,
      'packageType': packageType,
    };
  }

  /// Clear pending payment from localStorage
  static void clearPendingPayment() {
    WebStorageHelper.removeItem(_kPendingOrderId);
    WebStorageHelper.removeItem(_kPendingPaymentUrl);
    WebStorageHelper.removeItem(_kPendingQrString);
    WebStorageHelper.removeItem(_kPendingAmount);
    WebStorageHelper.removeItem(_kPendingUserId);
    WebStorageHelper.removeItem(_kPendingPackageType);
  }
}
