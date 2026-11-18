import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/language_provider.dart';
import '../core/security/pin_service.dart';
import '../widgets/dmlace_logo.dart';
import 'main_navigation_screen.dart';

class PinScreen extends StatefulWidget {
  final bool isSettingPin;
  final VoidCallback? onSuccess;

  const PinScreen({
    super.key,
    this.isSettingPin = false,
    this.onSuccess,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _firstEnteredPin; // Used during setup confirmation
  String _errorMessage = '';
  bool _isConfirming = false;

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = '';
      });

      if (_pin.length == 4) {
        _processPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _processPin() async {
    if (widget.isSettingPin) {
      if (!_isConfirming) {
        setState(() {
          _firstEnteredPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstEnteredPin) {
          // Set PIN and persist to SQLite
          await PinService.savePin(_pin);
          if (!mounted) return;
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _pin = '';
            _firstEnteredPin = null;
            _isConfirming = false;
            _errorMessage = 'PINs did not match. Try again.';
          });
        }
      }
    } else {
      // Verification mode
      final success = PinService.verifyPin(_pin);
      if (success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      } else {
        setState(() {
          _pin = '';
          _errorMessage = 'Incorrect PIN. Please re-enter.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;

    if (widget.isSettingPin) {
      if (_isConfirming) {
        title = 'Confirm New PIN';
        subtitle = 'Re-enter your 4-digit security PIN';
      } else {
        title = 'Set App Security PIN';
        subtitle = 'Enter a 4-digit PIN to protect your business accounts';
      }
    } else {
      title = 'DM Lace Surat';
      subtitle = 'Enter owner PIN to unlock ledger & transactions';
    }

    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const DmLaceLogo(size: 80, showText: false),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.primaryGold : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? AppColors.primaryGold : AppColors.goldLight.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGold.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                );
              }),
            ),

            if (!widget.isSettingPin)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  Provider.of<LanguageProvider>(context, listen: false).tr(
                    en: '💡 Default PIN: 1234',
                    hi: '💡 डिफ़ॉल्ट पिन: 1234',
                  ),
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.payableRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.payableRed),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Numeric Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel or Clear
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: widget.isSettingPin
                            ? TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppColors.goldLight, fontSize: 13),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _buildKeypadButton('0'),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: IconButton(
                          onPressed: _onBackspace,
                          icon: const Icon(Icons.backspace_outlined, color: AppColors.goldLight, size: 24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: AppColors.navyLight.withValues(alpha: 0.35),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x33D4AF37), width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: AppColors.primaryGold.withValues(alpha: 0.3),
          onTap: () => _onKeyPress(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: AppColors.surfaceWhite,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
