import 'package:flutter_test/flutter_test.dart';
import 'package:dm_lace_surat/core/security/email_verification_service.dart';

void main() {
  setUp(() {
    EmailVerificationService.clearCache();
    EmailVerificationService.bypassOtpForTesting = true;
    EmailVerificationService.fixedTestOtp = null;
  });

  tearDown(() {
    EmailVerificationService.clearCache();
    EmailVerificationService.bypassOtpForTesting = false;
    EmailVerificationService.fixedTestOtp = null;
  });

  test('generateOtp produces 6-digit string', () {
    final otp = EmailVerificationService.generateOtp();
    expect(otp.length, equals(6));
    expect(int.tryParse(otp), isNotNull);
  });

  test('sendOtp validates invalid email format', () async {
    final res = await EmailVerificationService.sendOtp(
      email: 'invalid-email',
      name: 'Test User',
    );

    expect(res.success, isFalse);
    expect(res.error, contains('मान्य ईमेल'));
  });

  test('verifyOtp handles full lifecycle with exact match and prevents replay', () async {
    EmailVerificationService.bypassOtpForTesting = false;
    EmailVerificationService.fixedTestOtp = '654321';

    // 1. Send OTP to valid email
    final sendRes = await EmailVerificationService.sendOtp(
      email: 'merchant@dmlace.com',
      name: 'Dinesh Bhai',
    );

    expect(sendRes.success, isTrue);
    expect(sendRes.otp, equals('654321'));

    // 2. Verify with wrong OTP fails
    final wrongRes = EmailVerificationService.verifyOtp(
      email: 'merchant@dmlace.com',
      inputOtp: '111111',
    );
    expect(wrongRes.success, isFalse);
    expect(wrongRes.error, contains('गलत OTP'));

    // 3. Verify with correct OTP succeeds
    final correctRes = EmailVerificationService.verifyOtp(
      email: 'merchant@dmlace.com',
      inputOtp: '654321',
    );
    expect(correctRes.success, isTrue);

    // 4. Replay attempt fails because OTP is consumed
    final replayRes = EmailVerificationService.verifyOtp(
      email: 'merchant@dmlace.com',
      inputOtp: '654321',
    );
    expect(replayRes.success, isFalse);
  });

  test('sendOtp supports password reset mode', () async {
    EmailVerificationService.bypassOtpForTesting = true;
    final res = await EmailVerificationService.sendOtp(
      email: 'merchant@dmlace.com',
      name: 'Dinesh Bhai',
      isPasswordReset: true,
    );

    expect(res.success, isTrue);
    expect(res.otp, isNotNull);
  });
}
