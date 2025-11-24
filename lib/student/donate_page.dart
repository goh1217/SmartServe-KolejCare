import 'package:flutter/material.dart';

// Main Tips Page - Image 1
class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  int? selectedAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Donation',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 3),
                image: const DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/100'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Name and College
            const Text(
              'Gregory Smith',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'KK2 - UNM',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 30),

            // Card Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Your donation helps us maintain and\nimprove our facilities for a better\nexperience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Amount Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AmountButton(
                        amount: 1,
                        isSelected: selectedAmount == 1,
                        onTap: () => setState(() => selectedAmount = 1),
                      ),
                      _AmountButton(
                        amount: 2,
                        isSelected: selectedAmount == 2,
                        onTap: () => setState(() => selectedAmount = 2),
                      ),
                      _AmountButton(
                        amount: 5,
                        isSelected: selectedAmount == 5,
                        onTap: () => setState(() => selectedAmount = 5),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Choose other amount link
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnterAmountPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Choose other amount',
                      style: TextStyle(
                        color: Colors.purple[300],
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Done Button
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

                  // Allow user to cancel and return to HomePage
                  TextButton(
                    onPressed: () {
                      // Pop back to the first route (HomePage) so user returns to dashboard
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(
                      'Maybe next time',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  final int amount;
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[100] : Colors.grey[100],
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RM$amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.deepPurple : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enter Amount Page - Image 2
class EnterAmountPage extends StatefulWidget {
  const EnterAmountPage({super.key});

  @override
  State<EnterAmountPage> createState() => _EnterAmountPageState();
}

class _EnterAmountPageState extends State<EnterAmountPage> {
  String enteredAmount = '';

  void _onNumberTap(String number) {
    setState(() {
      if (enteredAmount.length < 6) {
        enteredAmount += number;
      }
    });
  }

  void _onDeleteTap() {
    setState(() {
      if (enteredAmount.isNotEmpty) {
        enteredAmount = enteredAmount.substring(0, enteredAmount.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tips',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),

          // Enter Amount Label
          const Text(
            'Enter Amount',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 20),

          // Amount Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'RM',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    enteredAmount.isEmpty ? '0' : enteredAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Number Pad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _NumberRow(
                  numbers: ['1', '2', '3'],
                  onTap: _onNumberTap,
                ),
                const SizedBox(height: 20),
                _NumberRow(
                  numbers: ['4', '5', '6'],
                  onTap: _onNumberTap,
                ),
                const SizedBox(height: 20),
                _NumberRow(
                  numbers: ['7', '8', '9'],
                  onTap: _onNumberTap,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _onDeleteTap,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.backspace_outlined, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                    _NumberButton(
                      value: '0',
                      onTap: _onNumberTap,
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Done Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enteredAmount.isNotEmpty
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentMethodPage(
                        amount: int.parse(enteredAmount),
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
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final List<String> numbers;
  final Function(String) onTap;

  const _NumberRow({
    required this.numbers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) => _NumberButton(
        value: number,
        onTap: onTap,
      )).toList(),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String value;
  final Function(String) onTap;

  const _NumberButton({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.purple[50],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

// Payment Method Page - Image 3
class PaymentMethodPage extends StatefulWidget {
  final int amount;

  const PaymentMethodPage({super.key, required this.amount});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  String? selectedPaymentMethod;
  String? selectedBank;
  bool showBankList = false;

  final List<String> banks = [
    'Bank 1',
    'Bank 2',
    'Bank 3',
    'Bank 4',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 20),

            // Debit / Credit Card Option
            _PaymentOption(
              icon: Icons.credit_card,
              title: 'Debit / Credit Card',
              isSelected: selectedPaymentMethod == 'card',
              onTap: () {
                setState(() {
                  selectedPaymentMethod = 'card';
                  showBankList = false;
                });
              },
            ),

            const SizedBox(height: 16),

            // Online Banking (FPX) Option
            _PaymentOption(
              icon: Icons.account_balance,
              title: 'Online Banking (FPX)',
              isSelected: selectedPaymentMethod == 'fpx',
              showDropdown: true,
              isExpanded: showBankList,
              onTap: () {
                setState(() {
                  selectedPaymentMethod = 'fpx';
                  showBankList = !showBankList;
                });
              },
            ),

            // Bank Selection Dropdown
            if (showBankList && selectedPaymentMethod == 'fpx')
              Container(
                margin: const EdgeInsets.only(top: 12, left: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Bank from the List',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBank,
                          hint: const Text('Select Bank'),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: banks.map((String bank) {
                            return DropdownMenuItem<String>(
                              value: bank,
                              child: Text(bank),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              selectedBank = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedPaymentMethod == 'card' ||
                    (selectedPaymentMethod == 'fpx' && selectedBank != null))
                    ? () {
                  // Show success dialog or navigate to success page
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Payment Successful'),
                      content: Text('RM${widget.amount} has been processed successfully!'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool showDropdown;
  final bool isExpanded;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
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
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            if (showDropdown)
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }
}