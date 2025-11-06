import 'package:flutter/material.dart';
import 'dart:core'; // For BigInt

// 1. CORE CONVERSION LOGIC (The Model / conversion_service.dart)
// -----------------------------------------------------------------------------

// Defines a class to hold the base conversion logic, supporting bases 2, 8, 10, and 16.
class ConversionService {
  // Define the maximum allowed base for validation.
  static const int _maxBase = 16; 

  // Helper to map an integer value (0-15) to its character ('0'-'9', 'A'-'F').
  String _valToChar(int v) {
    // Digits 0-9 use ASCII '0' (48).
    if (v < 10) return String.fromCharCode(48 + v);
    // Letters 10-15 use ASCII 'A' (65). Offset 55 (65 - 10) ensures 10 -> 'A'.
    // NOTE: This logic still works correctly for 10-15 (A-F).
    return String.fromCharCode(55 + v);
  }

  // Helper to map a character ('0'-'F', case-insensitive) to its integer value (0-15).
  int _charToVal(String c) {
    final uc = c.toUpperCase().codeUnitAt(0);
    // Handle '0'-'9'.
    if (uc >= 48 && uc <= 57) return uc - 48;
    // Handle 'A'-'F'. The range is now implicitly limited by usage in _fromBaseToBigInt.
    if (uc >= 65 && uc <= 70) return uc - 55; // 'F' is 70
    // Throws a FormatException if the character is not a valid base-16 digit.
    throw FormatException('Invalid character: $c');
  }

  // Converts a number string from a given base (2, 8, 10, 16) to a BigInt (decimal).
  BigInt _fromBaseToBigInt(String s, int base) {
    // *MODIFIED:* Base validation check (must be <= _maxBase, which is 16).
    if (base < 2 || base > _maxBase) throw ArgumentError('Base must be 2..$_maxBase');

    var str = s.trim();
    var negative = false;

    // Handle negative sign.
    if (str.startsWith('-')) {
      negative = true;
      str = str.substring(1);
    }
    if (str.isEmpty) throw const FormatException('Empty input');

    BigInt acc = BigInt.zero;

    // Apply polynomial expansion: acc = acc * base + digit_value
    for (var ch in str.split('')) {
      final val = _charToVal(ch);
      // Validate digit against the specified base.
      if (val >= base) {
        throw FormatException('Digit "$ch" not valid for base $base');
      }
      acc = acc * BigInt.from(base) + BigInt.from(val);
    }

    return negative ? -acc : acc;
  }

  // Converts a BigInt (decimal) to a number string in the target base (2, 8, 10, 16).
  String _bigIntToBase(BigInt value, int base) {
    // *MODIFIED:* Base validation check (must be <= _maxBase, which is 16).
    if (base < 2 || base > _maxBase) throw ArgumentError('Base must be 2..$_maxBase');

    // Handle zero case.
    if (value == BigInt.zero) return '0';

    // Handle sign and get absolute value.
    var negative = value < BigInt.zero;
    var v = negative ? -value : value;

    final digits = <String>[];

    // Repeated division to find digits (collected in reverse order).
    while (v > BigInt.zero) {
      final rem = (v % BigInt.from(base)).toInt();
      digits.add(_valToChar(rem));
      v = v ~/ BigInt.from(base);
    }

    final res = digits.reversed.join();
    return negative ? '-$res' : res;
  }

  // Public method for base conversion.
  String convertBase(String input, int fromBase, int toBase) {
    // 1. Convert to decimal BigInt.
    final decimal = _fromBaseToBigInt(input, fromBase);
    // 2. Convert to target base string.
    return _bigIntToBase(decimal, toBase);
  }
}

// -----------------------------------------------------------------------------
// 2. MAIN APPLICATION AND UI (The View)
// -----------------------------------------------------------------------------

void main() {
  runApp(const NumberConverterApp());
}

class NumberConverterApp extends StatelessWidget {
  const NumberConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Standard application setup.
    return MaterialApp(
      title: 'Base Converter (2, 8, 10, 16)', // *CHANGED APP TITLE*
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8FF),
      ),
      home: const NumberConverterScreen(),
    );
  }
}

// Data structure to map base names to their radix value.
class BaseOption {
  final String name;
  final int radix;
  const BaseOption(this.name, this.radix);
}

// *MODIFIED:* List of available base options for the dropdowns (Base 36 removed).
const List<BaseOption> availableBases = [
  BaseOption('Binary (Base 2)', 2),
  BaseOption('Octal (Base 8)', 8),
  BaseOption('Decimal (Base 10)', 10),
  BaseOption('Hexadecimal (Base 16)', 16),
];

// -----------------------------------------------------------------------------
// 3. WIDGET AND CONTROLLER LOGIC (The Controller)
// -----------------------------------------------------------------------------

class NumberConverterScreen extends StatefulWidget {
  const NumberConverterScreen({super.key});

  @override
  State<NumberConverterScreen> createState() => _NumberConverterScreenState();
}

class _NumberConverterScreenState extends State<NumberConverterScreen> {
  // Instance of the service for logic execution.
  final ConversionService _service = ConversionService();
  final TextEditingController _inputController = TextEditingController();

  // State variables for the UI.
  String _result = '';
  // *MODIFIED:* Default bases adjusted to use the new shorter list.
  BaseOption _fromBase = availableBases[3]; // Default: Hexadecimal (index 3)
  BaseOption _toBase = availableBases[0]; // Default: Binary (index 0)

  // Function to perform the conversion when the button is pressed.
  void _performConversion() {
    // Controller Logic: Get input and bases.
    final input = _inputController.text.trim();
    final fromBase = _fromBase.radix;
    final toBase = _toBase.radix;

    // Early exit if input is empty.
    if (input.isEmpty) {
      setState(() {
        _result = 'Result: Invalid input (Empty)';
      });
      return;
    }

    setState(() {
      try {
        // Call the core service (Model) for the conversion.
        final converted = _service.convertBase(input, fromBase, toBase);
        _result = 'Result: $converted';
      } on ArgumentError catch (e) {
        // Catches errors related to invalid base values.
        _result = 'Error: Base must be 2, 8, 10, or 16.';
        print(e);
      } on FormatException catch (_) {
        // Catches errors for invalid characters or digits not valid for the selected base.
        _result = 'Result: Invalid input';
      } catch (e) {
        // Catch any other unexpected errors.
        _result = 'An unexpected error occurred.';
        print(e);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // --- UI Build Section ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- CHANGED APP BAR TITLE HERE ---
        title: const Text('Base Converter (2, 8, 10, 16)'), // *CHANGED APP BAR TITLE*
        centerTitle: true,
        backgroundColor: Colors.indigo.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Input Field
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'Enter number',
                hintText: 'e.g., FF or 1010',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.text,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Base Selection Dropdowns
            Row(
              children: <Widget>[
                Expanded(child: _buildDropdown('From Base', _fromBase, (newValue) {
                  setState(() {
                    _fromBase = newValue!;
                    // Optional: Recalculate result instantly if input is not empty
                    if (_inputController.text.isNotEmpty) _performConversion();
                  });
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdown('To Base', _toBase, (newValue) {
                  setState(() {
                    _toBase = newValue!;
                    // Optional: Recalculate result instantly if input is not empty
                    if (_inputController.text.isNotEmpty) _performConversion();
                  });
                })),
              ],
            ),
            const SizedBox(height: 30),

            // Convert Button
            ElevatedButton(
              onPressed: _performConversion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade200,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Convert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),

            // Result Display
            Center(
              child: Text(
                _result.isNotEmpty ? _result : 'Result: ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _result.startsWith('Error') || _result.contains('Invalid input')
                      ? Colors.red.shade700
                      : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build the base selection dropdowns.
  Widget _buildDropdown(String label, BaseOption currentValue, ValueChanged<BaseOption?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BaseOption>(
              value: currentValue,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
              isExpanded: true,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              onChanged: onChanged,
              items: availableBases.map((BaseOption option) {
                return DropdownMenuItem<BaseOption>(
                  value: option,
                  child: Text(option.name),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
