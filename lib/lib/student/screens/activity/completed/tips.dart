import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tips Page',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const TipsPage(),
    );
  }
}

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  _TipsPageState createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  double _selectedAmount = 2.0; // Default amount

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tips'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Add this
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile section
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF5E4DB2),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage: const AssetImage('assets/male.jpg'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Gregory Smith',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Contribute to Future Upgrades?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your donation helps us maintain and improve our facilities for a better experience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              // Amount buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTipButton(1.0),
                  _buildTipButton(2.0),
                  _buildTipButton(5.0),
                ],
              ),
              const SizedBox(height: 16),
              // Custom amount button
              TextButton(
                onPressed: () async {
                  final amount = await Navigator.push<double>(
                    context,
                    MaterialPageRoute(builder: (_) => const NumericKeypadPage()),
                  );
                  if (amount != null) {
                    setState(() {
                      _selectedAmount = amount;
                    });
                  }
                },
                child: const Text('Choose other amount'),
              ),
              const SizedBox(height: 24),
              // Selected amount display
              Text(
                'Selected amount: RM${_selectedAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: _submitTip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E4DB2),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Submit Tips',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipButton(double amount) {
    final isSelected = _selectedAmount == amount;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedAmount = amount;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF5E4DB2) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF5E4DB2),
      ),
      child: Text('RM${amount.toStringAsFixed(2)}'),
    );
  }

  void _submitTip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tips Submitted'),
        content: Text('Amount: RM${_selectedAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class NumericKeypadPage extends StatefulWidget {
  const NumericKeypadPage({super.key});

  @override
  _NumericKeypadPageState createState() => _NumericKeypadPageState();
}

class _NumericKeypadPageState extends State<NumericKeypadPage> {
  String _enteredAmount = "0";

  void _addDigit(String digit) {
    setState(() {
      if (_enteredAmount == "0") {
        _enteredAmount = digit;
      } else {
        _enteredAmount += digit;
      }
    });
  }

  void _deleteDigit() {
    setState(() {
      if (_enteredAmount.length > 1) {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      } else {
        _enteredAmount = "0";
      }
    });
  }

  void _submitAmount() {
    final enteredAmount = double.tryParse(_enteredAmount) ?? 0;
    // Handle the amount submission logic here (e.g., save or send to server).
    Navigator.pop(context, enteredAmount);  // Go back to the previous screen with entered amount
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE8E8E8),
        title: const Text('Tips'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'RM $_enteredAmount',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            // Numeric Keypad
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index < 9) {
                  return _buildKeyButton((index + 1).toString());
                } else if (index == 9) {
                  return _buildKeyButton("0");
                } else if (index == 10) {
                  return _buildKeyButton("X", onTap: _deleteDigit);
                } else {
                  return _buildKeyButton("OK", onTap: _submitAmount);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () => _addDigit(label),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5E4DB2),  // Changed to purple to match theme
          ),
        ),
      ),
    );
  }
}