import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Conditional imports for web
import 'stripe_service_web.dart'
    if (dart.library.io) 'stripe_service_stub.dart'
    as web_helper;

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // Get secret key from .env
  String get _secretKey {
    final key = dotenv.env['STRIPE_SECRET_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('WARNING: STRIPE_SECRET_KEY not found in .env');
    }
    return key;
  }

  // Make payment with card or FPX
  Future<bool> makePayment({
    required double amountInRm,
    required String paymentMethod, // 'card' or 'fpx'
    String? selectedBank, // For FPX only
  }) async {
    // Web uses different payment flow (Stripe.js would be ideal, but for demo we'll create intent)
    if (kIsWeb) {
      return await _makeWebPayment(
        amountInRm: amountInRm,
        paymentMethod: paymentMethod,
        selectedBank: selectedBank,
      );
    }

    try {
      debugPrint(
        "Starting payment for RM${amountInRm.toStringAsFixed(2)} using $paymentMethod",
      );

      // 1. Create Payment Intent with selected payment method
      String? clientSecret = await createPaymentIntent(
        amount: amountInRm,
        currency: 'myr',
        paymentMethod: paymentMethod,
      );

      if (clientSecret == null) {
        debugPrint("Failed to create payment intent");
        return false;
      }

      debugPrint("Payment intent created successfully");

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'SmartServe',
          allowsDelayedPaymentMethods: true,
          returnURL: 'flutterstripe://stripe-redirect',
          style: ThemeMode.light,
        ),
      );

      debugPrint("Payment sheet initialized");

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      debugPrint("✅ Payment completed successfully");
      return true;
    } on StripeException catch (e) {
      debugPrint("❌ Stripe Exception: ${e.error.localizedMessage}");
      debugPrint("Error code: ${e.error.code}");
      debugPrint("Error type: ${e.error.type}");

      // User cancelled the payment
      if (e.error.code == FailureCode.Canceled) {
        debugPrint("User cancelled payment");
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint("❌ General Error: $e");
      debugPrint("Stack trace: $stackTrace");
      return false;
    }
  }

  Future<String?> createPaymentIntent({
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      final Dio dio = Dio();

      debugPrint(
        "Creating payment intent for amount: ${amount.toStringAsFixed(2)} $currency with $paymentMethod",
      );

      // Build payload based on the user's selected method.
      // If FPX is selected, restrict the intent to FPX only so the sheet shows FPX.
      // Otherwise restrict to card. Do not set automatic_payment_methods here.
      final Map<String, dynamic> data = {
        'amount': _calculateAmount(amount),
        'currency': currency,
      };

      if (paymentMethod == 'fpx') {
        data['payment_method_types[0]'] = 'fpx';
      } else {
        data['payment_method_types[0]'] = 'card';
      }

      debugPrint("Request data: $data");

      var response = await dio.post(
        'https://api.stripe.com/v1/payment_intents',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Authorization": "Bearer ${_secretKey}",
            "Content-Type": "application/x-www-form-urlencoded",
          },
        ),
      );

      debugPrint("✅ Payment intent response: ${response.statusCode}");
      debugPrint("Response body: ${response.data}");

      if (response.data != null) {
        debugPrint("Client secret obtained");
        return response.data['client_secret'];
      }

      debugPrint("No data in response");
      return null;
    } on DioException catch (e) {
      debugPrint("❌ Dio Error: ${e.message}");
      if (e.response != null) {
        debugPrint("Response status: ${e.response?.statusCode}");
        debugPrint("Response data: ${e.response?.data}");
      }
      return null;
    } catch (e) {
      debugPrint("❌ Create Intent Error: $e");
      return null;
    }
  }

  String _calculateAmount(double amount) {
    // Convert RM to cents, rounding to nearest cent
    final cents = (amount * 100).round();
    final calculatedAmount = cents.toString();
    debugPrint("Amount in cents: $calculatedAmount");
    return calculatedAmount;
  }

  // Web payment flow - creates Stripe Checkout session and redirects
  Future<bool> _makeWebPayment({
    required double amountInRm,
    required String paymentMethod,
    String? selectedBank,
  }) async {
    try {
      debugPrint(
        "🌐 Starting web payment for RM${amountInRm.toStringAsFixed(2)} using $paymentMethod",
      );

      // Create Stripe Checkout Session
      String? sessionUrl = await _createCheckoutSession(
        amount: amountInRm,
        currency: 'myr',
        paymentMethod: paymentMethod,
      );

      if (sessionUrl == null) {
        debugPrint("❌ Failed to create checkout session");
        return false;
      }

      debugPrint("✅ Checkout session created: $sessionUrl");

      // Open Stripe Checkout in a new tab
      web_helper.openUrlInNewTab(sessionUrl);

      debugPrint("✅ Redirected to Stripe Checkout (test mode)");
      debugPrint("💳 Use test card: 4242 4242 4242 4242");
      debugPrint("📅 Expiry: Any future date");
      debugPrint("🔒 CVC: Any 3 digits");

      // Return true immediately - in production you'd wait for webhook confirmation
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ Web payment error: $e");
      debugPrint("Stack trace: $stackTrace");
      return false;
    }
  }

  // Create Stripe Checkout Session for web payments
  Future<String?> _createCheckoutSession({
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      final Dio dio = Dio();

      debugPrint(
        "Creating checkout session for amount: ${amount.toStringAsFixed(2)} $currency",
      );

      final response = await dio.post(
        'https://api.stripe.com/v1/checkout/sessions',
        data: {
          'payment_method_types[]': paymentMethod == 'fpx' ? 'fpx' : 'card',
          'line_items[0][price_data][currency]': currency,
          'line_items[0][price_data][product_data][name]': 'Donation',
          'line_items[0][price_data][unit_amount]': _calculateAmount(amount),
          'line_items[0][quantity]': '1',
          'mode': 'payment',
          'success_url': web_helper.getCurrentUrl() + '/#/success',
          'cancel_url': web_helper.getCurrentUrl() + '/#/cancel',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Authorization": "Bearer ${_secretKey}",
            "Content-Type": "application/x-www-form-urlencoded",
          },
        ),
      );

      debugPrint("✅ Checkout session response: ${response.statusCode}");

      if (response.data != null && response.data['url'] != null) {
        return response.data['url'];
      }

      debugPrint("No URL in response");
      return null;
    } on DioException catch (e) {
      debugPrint("❌ Dio Error: ${e.message}");
      if (e.response != null) {
        debugPrint("Response status: ${e.response?.statusCode}");
        debugPrint("Response data: ${e.response?.data}");
      }
      return null;
    } catch (e) {
      debugPrint("❌ Create Checkout Session Error: $e");
      return null;
    }
  }

  // Get list of Malaysian banks for FPX
  static List<Map<String, String>> getMalaysianBanks() {
    return [
      {'code': 'maybank', 'name': 'Maybank'},
      {'code': 'cimb', 'name': 'CIMB Bank'},
      {'code': 'public_bank', 'name': 'Public Bank'},
      {'code': 'rhb', 'name': 'RHB Bank'},
      {'code': 'hong_leong_bank', 'name': 'Hong Leong Bank'},
      {'code': 'ambank', 'name': 'AmBank'},
      {'code': 'bank_islam', 'name': 'Bank Islam'},
      {'code': 'bank_rakyat', 'name': 'Bank Rakyat'},
      {'code': 'hsbc', 'name': 'HSBC Bank'},
      {'code': 'uob', 'name': 'UOB Bank'},
    ];
  }
}
