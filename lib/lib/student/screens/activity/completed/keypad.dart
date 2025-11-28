import 'package:flutter/material.dart';

class NumericKeypadPage extends StatefulWidget {
  const NumericKeypadPage({super.key});

  @override
  _NumericKeypadPageState createState() => _NumericKeypadPageState();
}

class _NumericKeypadPageState extends State<NumericKeypadPage> {
  String _enteredAmount = "0"; // Default value for amount

  // Function to add digit to entered amount
  void _addDigit(String digit) {
    setState(() {
      if (_enteredAmount == "0") {
        _enteredAmount = digit; // Replace '0' with the digit
      } else {
        _enteredAmount += digit; // Append digit to entered amount
      }
    });
  }

  // Function to delete last entered digit
  void _deleteDigit() {
    setState(() {
      if (_enteredAmount.length > 1) {
        _enteredAmount = _enteredAmount.substring(0, _enteredAmount.length - 1);
      } else {
        _enteredAmount = "0"; // Reset to 0 if nothing to delete
      }
    });
  }

  // Function to submit the entered amount
  void _submitAmount() {
    final enteredAmount = double.tryParse(_enteredAmount) ?? 0;
    Navigator.pop(context, enteredAmount); // Go back with the entered amount
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
            // Display the entered amount
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
                crossAxisCount: 3, // 3 columns
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

  // Function to build each key button
  Widget _buildKeyButton(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () => _addDigit(label), // Default action is to add digit
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
            color: Color(0xFF5E4DB2),
          ),
        ),
      ),
    );
  }
}