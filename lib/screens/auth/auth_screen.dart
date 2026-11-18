import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/security/auth_service.dart';
import '../../core/security/email_verification_service.dart';
import '../main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Sign In Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _rememberMe = true;

  // Sign Up Controllers
  final _signUpNameController = TextEditingController();
  final _signUpShopController = TextEditingController(text: 'DM LACE SURAT');
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  bool _obscureSignUpPassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _checkInitialMode();
  }

  Future<void> _checkInitialMode() async {
    final hasUsers = await AuthService.hasAnyUsers();
    if (!hasUsers && mounted) {
      setState(() => _isSignUp = true);
    }
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpShopController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService.login(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = res.error);
    }
  }

  Future<void> _handleSignUp(LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    final name = _signUpNameController.text.trim();
    final shop = _signUpShopController.text.trim();
    final registeredEmail = _signUpEmailController.text.trim();
    final pass = _signUpPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _errorMessage = lang.isHindi ? 'कृपया नाम दर्ज करें' : 'Please enter your name';
      });
      return;
    }
    if (registeredEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(registeredEmail)) {
      setState(() {
        _errorMessage = lang.isHindi ? 'कृपया सही ईमेल दर्ज करें' : 'Please enter a valid email';
      });
      return;
    }
    if (pass.length < 6) {
      setState(() {
        _errorMessage = lang.isHindi ? 'पासवर्ड कम से कम 6 अक्षरों का रखें' : 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    // 1. Check if email is already registered
    final alreadyRegistered = await AuthService.isEmailRegistered(registeredEmail);
    if (alreadyRegistered) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = lang.isHindi
            ? 'इस ईमेल से खाता पहले से मौजूद है! कृपया लॉगिन करें।'
            : 'An account with this email already exists. Please sign in.';
      });
      return;
    }

    // 2. Send 6-digit OTP to the email address
    final otpSendResult = await EmailVerificationService.sendOtp(
      email: registeredEmail,
      name: name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!otpSendResult.success) {
      setState(() {
        _errorMessage = otpSendResult.error ??
            (lang.isHindi ? 'OTP भेजने में समस्या हुई' : 'Failed to send verification OTP');
      });
      return;
    }

    // 3. Show clean OTP Verification Dialog
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OtpVerificationDialog(
        email: registeredEmail,
        name: name,
        lang: lang,
      ),
    );

    if (verified != true) return;

    // 4. Create account after OTP verification
    setState(() => _isLoading = true);
    final res = await AuthService.signUp(
      name: name,
      email: registeredEmail,
      password: pass,
      shopName: shop,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      setState(() {
        _isSignUp = false;
        _loginEmailController.text = registeredEmail;
        _loginPasswordController.clear();
        _signUpPasswordController.clear();
        _successMessage = lang.isHindi
            ? 'खाता बन गया! कृपया पासवर्ड डालकर लॉगिन करें।'
            : 'Account created! Please sign in with your password.';
      });
    } else {
      setState(() => _errorMessage = res.error);
    }
  }

  Future<void> _showForgotPasswordDialog(LanguageProvider lang) async {
    final updatedEmail = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _loginEmailController.text.trim(),
        lang: lang,
      ),
    );

    if (updatedEmail != null && mounted) {
      _loginEmailController.text = updatedEmail;
      _loginPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi
                ? 'पासवर्ड सफलतापूर्वक बदल दिया गया! अब नए पासवर्ड से लॉगिन करें।'
                : 'Password updated successfully! Please sign in with your new password.',
          ),
          backgroundColor: AppColors.receivableGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimal Sleek Brand Header
                  _buildBrandHeader(),
                  const SizedBox(height: 20),

                  // Clean White Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab Switcher (लॉगिन | साइन अप)
                        _buildTabSwitcher(lang),
                        const SizedBox(height: 18),

                        // Success Banner
                        if (_successMessage != null && !_isSignUp) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: AppColors.receivableGreen, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: const TextStyle(color: Color(0xFF065F46), fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.payableRed, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.payableRed, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Form
                        if (!_isSignUp) _buildLoginForm(lang) else _buildSignUpForm(lang),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0F172A),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.8),
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/images/dm_lace_logo.png', fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'DM LACE SURAT',
          style: TextStyle(
            color: Color(0xFFFDE047),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isSignUp = false;
                  _errorMessage = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !_isSignUp ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    lang.isHindi ? 'लॉगिन' : 'Sign In',
                    style: TextStyle(
                      color: !_isSignUp ? const Color(0xFFFDE047) : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isSignUp = true;
                  _errorMessage = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _isSignUp ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    lang.isHindi ? 'साइन अप' : 'Sign Up',
                    style: TextStyle(
                      color: _isSignUp ? const Color(0xFFFDE047) : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Clean Sign In Form
  Widget _buildLoginForm(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'ईमेल' : 'Email',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'पासवर्ड' : 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryNavy),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF64748B),
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFF0F172A),
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  lang.isHindi ? 'याद रखें' : 'Remember me',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showForgotPasswordDialog(lang),
              child: Text(
                lang.isHindi ? 'पासवर्ड भूल गए?' : 'Forgot Password?',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: const Color(0xFFFDE047),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
          ),
          onPressed: _isLoading ? null : () => _handleLogin(lang),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDE047)))
              : Text(
                  lang.isHindi ? 'लॉगिन ➔' : 'Sign In ➔',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }

  // 2. Clean Sign Up Form (Only Essential 4 Fields)
  Widget _buildSignUpForm(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _signUpNameController,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'पूरा नाम' : 'Full Name',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _signUpShopController,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'दुकान का नाम' : 'Shop Name',
            prefixIcon: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _signUpEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'ईमेल' : 'Email',
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _signUpPasswordController,
          obscureText: _obscureSignUpPassword,
          decoration: InputDecoration(
            labelText: lang.isHindi ? 'पासवर्ड' : 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryNavy),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF64748B),
              ),
              onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 18),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: const Color(0xFFFDE047),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
          ),
          onPressed: _isLoading ? null : () => _handleSignUp(lang),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDE047)))
              : Text(
                  lang.isHindi ? 'खाता बनाएं ➔' : 'Create Account ➔',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}

/// Neat & Clean OTP Verification Dialog (Zero Clutter)
class _OtpVerificationDialog extends StatefulWidget {
  final String email;
  final String name;
  final LanguageProvider lang;

  const _OtpVerificationDialog({
    required this.email,
    required this.name,
    required this.lang,
  });

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<_OtpVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _dialogError;
  int _secondsRemaining = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _secondsRemaining = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleResend() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isResending = true;
      _dialogError = null;
    });

    final res = await EmailVerificationService.sendOtp(
      email: widget.email,
      name: widget.name,
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    if (res.success) {
      _startCountdown();
    } else {
      setState(() => _dialogError = res.error);
    }
  }

  void _handleVerify() {
    HapticFeedback.lightImpact();
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _dialogError = widget.lang.isHindi
            ? 'कृपया 6-अंकों का OTP कोड दर्ज करें'
            : 'Please enter 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _dialogError = null;
    });

    final verifyRes = EmailVerificationService.verifyOtp(
      email: widget.email,
      inputOtp: code,
    );

    if (verifyRes.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isVerifying = false;
        _dialogError = verifyRes.error ??
            (widget.lang.isHindi ? 'गलत OTP कोड!' : 'Invalid OTP code!');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = widget.lang.isHindi;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'ईमेल OTP सत्यापन' : 'Email Verification',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text(
                widget.email,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),

              // OTP Input Field
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Color(0xFF0F172A),
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    letterSpacing: 6,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.8),
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),

              if (_dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dialogError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.payableRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: 14),

              // Resend Row
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        isHindi ? 'दोबारा भेजें (${_secondsRemaining}s)' : 'Resend in ${_secondsRemaining}s',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                      )
                    : _isResending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : GestureDetector(
                            onTap: _handleResend,
                            child: Text(
                              isHindi ? 'दोबारा OTP भेजें' : 'Resend OTP',
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
              ),
              const SizedBox(height: 16),

              // Verify Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFFDE047),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                onPressed: _isVerifying ? null : _handleVerify,
                child: _isVerifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDE047)))
                    : Text(
                        isHindi ? 'सत्यापित करें ➔' : 'Verify ➔',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Email-Verified Password Reset Dialog (Cannot directly change without Email OTP)
class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final LanguageProvider lang;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.lang,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _dialogError;
  int _secondsRemaining = 30;
  Timer? _countdownTimer;
  String _userName = 'व्यापारी';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  void _startCountdown() {
    setState(() => _secondsRemaining = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetOtp() async {
    HapticFeedback.lightImpact();
    final email = _emailController.text.trim();

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _dialogError = widget.lang.isHindi
            ? 'कृपया एक मान्य ईमेल आईडी दर्ज करें'
            : 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _dialogError = null;
    });

    // 1. Check if email actually exists in DB
    final isRegistered = await AuthService.isEmailRegistered(email);
    if (!isRegistered) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _dialogError = widget.lang.isHindi
            ? 'इस ईमेल से कोई खाता पंजीकृत नहीं है।'
            : 'No account registered with this email.';
      });
      return;
    }

    // Fetch user's registered name
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.tableAppUsers,
        where: 'email = ?',
        whereArgs: [email.toLowerCase().trim()],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _userName = (rows.first['name'] as String?) ?? 'व्यापारी';
      }
    } catch (_) {}

    // 2. Dispatch OTP to the user's email inbox
    final sendRes = await EmailVerificationService.sendOtp(
      email: email,
      name: _userName,
      isPasswordReset: true,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (sendRes.success) {
      setState(() {
        _otpSent = true;
        _dialogError = null;
      });
      _startCountdown();
    } else {
      setState(() {
        _dialogError = sendRes.error ??
            (widget.lang.isHindi ? 'OTP भेजने में त्रुटि हुई' : 'Failed to send reset code');
      });
    }
  }

  Future<void> _handleVerifyAndReset() async {
    HapticFeedback.lightImpact();
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    if (otp.length != 6) {
      setState(() {
        _dialogError = widget.lang.isHindi
            ? 'कृपया 6-अंकों का पूरा OTP कोड दर्ज करें'
            : 'Please enter the 6-digit OTP code';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _dialogError = widget.lang.isHindi
            ? 'नया पासवर्ड कम से कम 6 अक्षरों का रखें'
            : 'New password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _dialogError = null;
    });

    // 1. Verify OTP first (cannot directly update without email verification)
    final verifyRes = EmailVerificationService.verifyOtp(
      email: email,
      inputOtp: otp,
    );

    if (!verifyRes.success) {
      setState(() {
        _isLoading = false;
        _dialogError = verifyRes.error ??
            (widget.lang.isHindi ? 'गलत OTP कोड!' : 'Invalid OTP code!');
      });
      return;
    }

    // 2. Verified! Now update password in database
    final ok = await AuthService.resetPassword(email: email, newPassword: newPassword);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.of(context).pop(email);
    } else {
      setState(() {
        _dialogError = widget.lang.isHindi
            ? 'पासवर्ड अपडेट करने में समस्या हुई!'
            : 'Failed to update password!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = widget.lang.isHindi;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        isHindi ? 'पासवर्ड रीसेट' : 'Reset Password',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!_otpSent) ...[
                Text(
                  isHindi
                      ? 'अपना पंजीकृत ईमेल दर्ज करें। पासवर्ड बदलने के लिए ईमेल पर 6-अंकों का गुप्त कोड भेजा जाएगा:'
                      : 'Enter registered email. A 6-digit secret code will be sent to your inbox to reset password:',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'पंजीकृत ईमेल' : 'Registered Email',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryNavy),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 15, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _emailController.text.trim(),
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: isHindi ? '6-अंकों का ईमेल OTP' : '6-digit Email OTP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'नया पासवर्ड' : 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryNavy),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                Center(
                  child: _secondsRemaining > 0
                      ? Text(
                          isHindi ? 'दोबारा भेजें (${_secondsRemaining}s)' : 'Resend in ${_secondsRemaining}s',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
                        )
                      : GestureDetector(
                          onTap: _isLoading ? null : _handleSendResetOtp,
                          child: Text(
                            isHindi ? 'दोबारा OTP भेजें' : 'Resend OTP',
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                ),
              ],

              if (_dialogError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _dialogError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.payableRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFFDE047),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                onPressed: _isLoading
                    ? null
                    : (!_otpSent ? _handleSendResetOtp : _handleVerifyAndReset),
                child: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDE047)))
                    : Text(
                        !_otpSent
                            ? (isHindi ? 'ईमेल पर कोड भेजें ➔' : 'Send Code to Email ➔')
                            : (isHindi ? 'पासवर्ड अपडेट करें ➔' : 'Update Password ➔'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
