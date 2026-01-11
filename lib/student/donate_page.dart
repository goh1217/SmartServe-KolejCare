import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:owtest/student/services/stripe_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- PAGE 1: MAIN TIPS SELECTION ---
class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  double? selectedAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Donation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.15),
                    spreadRadius: 3,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.volunteer_activism,
                  size: 80,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    spreadRadius: 2,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Contribute to Future\nUpgrades?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your donation helps us maintain and improve our facilities for a better experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Minimum donation: RM 2.00',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [2.0, 5.0, 10.0]
                        .map(
                          (amt) => _AmountButton(
                            amount: amt,
                            isSelected: selectedAmount == amt,
                            onTap: () => setState(() => selectedAmount = amt),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnterAmountPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Choose other amount',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedAmount != null
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentMethodPage(
                                    amount: selectedAmount!,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: Text(
                      'Maybe next time',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- PAGE 2: CUSTOM AMOUNT (KEYPAD WITH DECIMAL) ---
class EnterAmountPage extends StatefulWidget {
  const EnterAmountPage({super.key});

  @override
  State<EnterAmountPage> createState() => _EnterAmountPageState();
}

class _EnterAmountPageState extends State<EnterAmountPage> {
  String enteredAmount = '';
  bool hasDecimal = false;

  void _onNumberTap(String number) {
    setState(() {
      if (hasDecimal) {
        final parts = enteredAmount.split('.');
        if (parts.length > 1 && parts[1].length >= 2) {
          return;
        }
      }
      if (enteredAmount.length < 8) {
        enteredAmount += number;
      }
    });
  }

  void _onDecimalTap() {
    setState(() {
      if (!hasDecimal && enteredAmount.isNotEmpty) {
        enteredAmount += '.';
        hasDecimal = true;
      } else if (enteredAmount.isEmpty) {
        enteredAmount = '0.';
        hasDecimal = true;
      }
    });
  }

  void _onDeleteTap() {
    setState(() {
      if (enteredAmount.isNotEmpty) {
        if (enteredAmount.endsWith('.')) {
          hasDecimal = false;
        }
        enteredAmount = enteredAmount.substring(0, enteredAmount.length - 1);
      }
    });
  }

  double? _getAmount() {
    if (enteredAmount.isEmpty) return null;
    try {
      return double.parse(enteredAmount);
    } catch (e) {
      return null;
    }
  }

  bool _isValidAmount() {
    final amount = _getAmount();
    return amount != null && amount >= 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final amount = _getAmount();
    final isValid = _isValidAmount();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        title: const Text(
          'Enter Amount',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Minimum: RM 2.00',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter Amount',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'RM',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 180,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !isValid && amount != null
                                  ? Colors.red
                                  : Colors.deepPurple,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              enteredAmount.isEmpty ? '0.00' : enteredAmount,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: !isValid && amount != null
                                    ? Colors.red
                                    : Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 18,
                      child: amount != null && amount < 2.0
                          ? Text(
                              'Amount must be at least RM 2.00',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 35),
                      child: Column(
                        children: [
                          _NumberRow(
                            numbers: ['1', '2', '3'],
                            onTap: _onNumberTap,
                          ),
                          const SizedBox(height: 16),
                          _NumberRow(
                            numbers: ['4', '5', '6'],
                            onTap: _onNumberTap,
                          ),
                          const SizedBox(height: 16),
                          _NumberRow(
                            numbers: ['7', '8', '9'],
                            onTap: _onNumberTap,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NumberButton(
                                icon: Icons.backspace_outlined,
                                isIcon: true,
                                onTap: (_) => _onDeleteTap(),
                              ),
                              _NumberButton(value: '0', onTap: _onNumberTap),
                              _NumberButton(
                                value: '.',
                                onTap: (_) => _onDecimalTap(),
                                isDecimal: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isValid
                      ? () {
                          final finalAmount = _getAmount()!;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PaymentMethodPage(amount: finalAmount),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE 3: PAYMENT METHOD PAGE ---
class PaymentMethodPage extends StatefulWidget {
  final double amount;
  const PaymentMethodPage({super.key, required this.amount});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  String? selectedPaymentMethod;
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    if (selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await StripeService.instance.makePayment(
        amountInRm: widget.amount.toDouble(),
        paymentMethod: selectedPaymentMethod!,
        selectedBank: null,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result != null && result['success'] == true) {
        // Save donation to Firestore
        await _saveDonationToFirestore(
          paymentIntentId: result['paymentIntentId'],
          amount: widget.amount.toDouble(),
          paymentType: selectedPaymentMethod == 'card' ? 'Card' : 'FPX',
        );
        _showSuccessDialog(paymentIntentId: result['paymentIntentId']);
      } else {
        _showErrorDialog('Payment was cancelled or failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorDialog('An error occurred: ${e.toString()}');
    }
  }

  Future<void> _saveDonationToFirestore({
    required String? paymentIntentId,
    required double amount,
    required String paymentType,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in, cannot save donation');
        return;
      }

      final dateTime = DateTime.now();
      final docId = paymentIntentId ?? 'RCP${dateTime.millisecondsSinceEpoch.toString().substring(7)}';

      await FirebaseFirestore.instance.collection('donation').doc(docId).set({
        'paymentId': docId,
        'amount': amount,
        'donatedBy': '/collection/student/${user.uid}',
        'paymentType': paymentType,
        'donationStatus': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Donation saved to Firestore: $docId');
    } catch (e) {
      debugPrint('❌ Error saving donation to Firestore: $e');
      // Don't throw error - payment was successful, just log the issue
    }
  }

  void _showSuccessDialog({String? paymentIntentId}) {
    // Generate receipt details - use Stripe payment intent ID if available
    final receiptNo = paymentIntentId ?? 'RCP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final dateTime = DateTime.now();
    final formattedDate =
        '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    final formattedTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentReceiptPage(
          receiptNo: receiptNo,
          amount: widget.amount,
          paymentMethod: selectedPaymentMethod == 'card'
              ? 'Card Payment'
              : 'Online Banking (FPX)',
          date: formattedDate,
          time: formattedTime,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Donation Amount',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RM ${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PaymentOption(
                    icon: Icons.credit_card,
                    title: 'Debit / Credit Card',
                    subtitle: 'Visa, Mastercard, Amex',
                    isSelected: selectedPaymentMethod == 'card',
                    onTap: () => setState(() => selectedPaymentMethod = 'card'),
                  ),
                  const SizedBox(height: 16),
                  _PaymentOption(
                    icon: Icons.account_balance,
                    title: 'Online Banking (FPX)',
                    subtitle: 'Malaysian banks',
                    isSelected: selectedPaymentMethod == 'fpx',
                    onTap: () => setState(() => selectedPaymentMethod = 'fpx'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : (selectedPaymentMethod != null
                                ? _handlePayment
                                : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Pay Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing payment...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- UI COMPONENTS ---
class _AmountButton extends StatelessWidget {
  final double amount;
  final bool isSelected;
  final VoidCallback onTap;
  const _AmountButton({
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.deepPurple.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.deepPurple, width: 2),
        ),
        child: Center(
          child: Text(
            'RM${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.deepPurple,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final List<String> numbers;
  final Function(String) onTap;
  const _NumberRow({required this.numbers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers
          .map((n) => _NumberButton(value: n, onTap: onTap))
          .toList(),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String? value;
  final IconData? icon;
  final bool isIcon;
  final bool isDecimal;
  final Function(String) onTap;
  const _NumberButton({
    this.value,
    this.icon,
    this.isIcon = false,
    this.isDecimal = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value ?? ""),
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: isIcon
              ? Colors.deepPurple.shade50
              : (isDecimal ? Colors.deepPurple.shade100 : Colors.deepPurple),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isIcon
              ? Icon(icon, color: Colors.deepPurple, size: 22)
              : Text(
                  value!,
                  style: TextStyle(
                    fontSize: isDecimal ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: isDecimal ? Colors.deepPurple : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final bool showDropdown;
  final bool isExpanded;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showDropdown = false,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (showDropdown)
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.deepPurple,
              ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE 4: PAYMENT RECEIPT ---
class PaymentReceiptPage extends StatelessWidget {
  final String receiptNo;
  final double amount;
  final String paymentMethod;
  final String date;
  final String time;

  const PaymentReceiptPage({
    Key? key,
    required this.receiptNo,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Payment Receipt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 70,
                  color: Colors.green.shade600,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Thank you for your donation',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 30),

              // Receipt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Receipt Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECEIPT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Divider
                    Container(height: 1, color: Colors.grey[300]),

                    const SizedBox(height: 20),

                    // Receipt Details
                    _ReceiptRow(
                      label: 'Payment ID',
                      value: receiptNo,
                      isHighlight: true,
                    ),

                    const SizedBox(height: 16),

                    _ReceiptRow(label: 'Date', value: date),

                    const SizedBox(height: 16),

                    _ReceiptRow(label: 'Time', value: time),

                    const SizedBox(height: 16),

                    _ReceiptRow(label: 'Payment Method', value: paymentMethod),

                    const SizedBox(height: 20),

                    // Divider
                    Container(height: 1, color: Colors.grey[300]),

                    const SizedBox(height: 20),

                    // Amount Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'RM ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Donation',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bottom Note removed

                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReceipt(context),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'DONATION RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              _receiptPdfRow('Payment ID', receiptNo),
              pw.SizedBox(height: 8),
              _receiptPdfRow('Date', date),
              pw.SizedBox(height: 8),
              _receiptPdfRow('Time', time),
              pw.SizedBox(height: 8),
              _receiptPdfRow('Payment Method', paymentMethod),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Thank you for your donation!',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'donation_receipt_$receiptNo.pdf',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt shared successfully!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? Colors.deepPurple : Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// PDF helper method for PaymentReceiptPage
pw.Widget _receiptPdfRow(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.end,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}
