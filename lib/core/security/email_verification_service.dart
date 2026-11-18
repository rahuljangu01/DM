import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../../services/auto_email_dispatch_service.dart';

class EmailVerificationService {
  /// Test bypass switch for CI & test runners
  static bool bypassOtpForTesting = false;
  static String? fixedTestOtp;

  /// In-memory storage for active verification OTPs: email -> {otp, createdAt}
  static final Map<String, ({String otp, DateTime createdAt})> _pendingOtps = {};

  /// Generate a secure 6-digit numeric OTP
  static String generateOtp() {
    if (fixedTestOtp != null) return fixedTestOtp!;
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  /// Sends a 6-digit OTP code to the recipient email address using Gmail SMTP
  static Future<({bool success, String? error, String? otp})> sendOtp({
    required String email,
    required String name,
    bool isPasswordReset = false,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final cleanName = name.trim().isEmpty ? 'व्यापारी बंधु' : name.trim();

    if (cleanEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail)) {
      return (success: false, error: 'कृपया एक मान्य ईमेल पता दर्ज करें', otp: null);
    }

    final otp = generateOtp();
    _pendingOtps[cleanEmail] = (otp: otp, createdAt: DateTime.now());

    // If running in test mode, return immediately without network call
    if (bypassOtpForTesting) {
      return (success: true, error: null, otp: otp);
    }

    try {
      // 1. Fetch SMTP Sender Settings from AppSettings or use defaults
      String senderEmail = 'rahuljangu01@gmail.com';
      String senderPassword = 'kllvesigpxfyhvst';

      try {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query(
          DatabaseTables.tableAppSettings,
          where: 'setting_key IN (?, ?)',
          whereArgs: [
            AutoEmailDispatchService.keySenderEmail,
            AutoEmailDispatchService.keySenderAppPassword,
          ],
        );

        for (final row in rows) {
          final k = row['setting_key'] as String;
          final v = (row['setting_value'] as String?)?.trim() ?? '';
          if (k == AutoEmailDispatchService.keySenderEmail && v.isNotEmpty) {
            senderEmail = v;
          } else if (k == AutoEmailDispatchService.keySenderAppPassword && v.isNotEmpty) {
            senderPassword = v.replaceAll(' ', '');
          }
        }
      } catch (_) {}

      // 2. Configure Gmail SMTP
      final smtpServer = gmail(senderEmail, senderPassword);

      // 3. Render High-Conversion Surat Lace Branded HTML Email
      final htmlContent = _buildOtpHtmlEmail(
        userName: cleanName,
        otp: otp,
        recipientEmail: cleanEmail,
        isPasswordReset: isPasswordReset,
      );

      final subject = isPasswordReset
          ? '🔐 DM LACE SURAT - पासवर्ड रीसेट OTP: $otp'
          : '🔐 DM LACE SURAT - ईमेल सत्यापन OTP: $otp';

      final message = Message()
        ..from = Address(senderEmail, 'DM LACE SURAT')
        ..recipients.add(cleanEmail)
        ..subject = subject
        ..html = htmlContent;

      await send(message, smtpServer).timeout(const Duration(seconds: 12));

      return (success: true, error: null, otp: otp);
    } on MailerException catch (e) {
      String detail = 'ईमेल प्रमाणीकरण विफल';
      if (e.problems.isNotEmpty) {
        detail = e.problems.first.msg;
      }
      return (
        success: false,
        error: 'ईमेल सर्वर त्रुटि ($detail)। कृपया इंटरनेट जांचें या पुनः प्रयास करें।',
        otp: null,
      );
    } catch (e) {
      return (
        success: false,
        error: 'OTP भेजने में समस्या: कृपया सुनिश्चित करें कि इंटरनेट चालू है।',
        otp: null,
      );
    }
  }

  /// Verifies the entered OTP against the active session
  static ({bool success, String? error}) verifyOtp({
    required String email,
    required String inputOtp,
  }) {
    if (bypassOtpForTesting) {
      return (success: true, error: null);
    }

    final cleanEmail = email.toLowerCase().trim();
    final cleanInput = inputOtp.trim();

    if (cleanInput.isEmpty) {
      return (success: false, error: 'कृपया 6-अंकों का OTP कोड दर्ज करें');
    }

    final pending = _pendingOtps[cleanEmail];
    if (pending == null) {
      return (
        success: false,
        error: 'इस ईमेल के लिए कोई OTP नहीं भेजा गया। कृपया "OTP भेजें" पर टैप करें।',
      );
    }

    // Check expiration (10 minutes)
    final ageMinutes = DateTime.now().difference(pending.createdAt).inMinutes;
    if (ageMinutes >= 10) {
      _pendingOtps.remove(cleanEmail);
      return (
        success: false,
        error: 'OTP की समय सीमा समाप्त (Expired) हो चुकी है। कृपया नया OTP प्राप्त करें।',
      );
    }

    // Verify OTP match
    if (pending.otp != cleanInput) {
      return (
        success: false,
        error: 'गलत OTP कोड! कृपया ईमेल में आया सही 6-अंकों का कोड दर्ज करें।',
      );
    }

    // Successfully verified: remove OTP from active cache to prevent reuse
    _pendingOtps.remove(cleanEmail);
    return (success: true, error: null);
  }

  /// Clears in-memory OTP cache
  static void clearCache() {
    _pendingOtps.clear();
  }

  /// Branded HTML Email Template for OTP verification
  static String _buildOtpHtmlEmail({
    required String userName,
    required String otp,
    required String recipientEmail,
    bool isPasswordReset = false,
  }) {
    final title = isPasswordReset ? 'DM LACE SURAT - पासवर्ड रीसेट OTP' : 'DM LACE SURAT - ईमेल सत्यापन OTP';
    final actionText = isPasswordReset
        ? 'आपके <strong>DM Lace</strong> खाते का पासवर्ड रीसेट करने के लिए 6-अंकों का गुप्त सत्यापन कोड (OTP) नीचे दिया गया है:'
        : '<strong>DM Lace Surat</strong> में आपका स्वागत है! आपका नया खाता सुरक्षित रूप से सक्रिय करने के लिए आपका 6-अंकों का गुप्त सत्यापन कोड (OTP) नीचे दिया गया है:';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
</head>
<body style="margin: 0; padding: 24px; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 540px; margin: 0 auto; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.08); border: 1px solid #E2E8F0;">
    <!-- Deep Royal Navy Header -->
    <tr>
      <td style="background: linear-gradient(135deg, #020309 0%, #0F172A 60%, #1E293B 100%); padding: 28px 24px; text-align: center; border-bottom: 2px solid #D4AF37;">
        <h1 style="margin: 0; color: #FDE047; font-size: 22px; font-weight: 900; letter-spacing: 2px;">DM LACE SURAT</h1>
        <p style="margin: 6px 0 0 0; color: #E2E8F0; font-size: 12px; font-weight: 500; letter-spacing: 0.5px;">श्री गणेशाय नमः • सुरक्षित डिजिटल व्यापार बहीखाता</p>
      </td>
    </tr>

    <!-- Body Content -->
    <tr>
      <td style="padding: 28px 26px 20px 26px;">
        <h2 style="margin: 0 0 12px 0; color: #0F172A; font-size: 17px; font-weight: 700;">नमस्ते $userName,</h2>
        <p style="margin: 0 0 16px 0; color: #334155; font-size: 13.5px; line-height: 1.6;">
          $actionText
        </p>

        <!-- Golden OTP Badge Box -->
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 22px 0;">
          <tr>
            <td align="center" style="background: #0F172A; border-radius: 14px; padding: 20px 16px; border: 1.5px solid #D4AF37; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.15);">
              <span style="font-size: 11px; color: #94A3B8; text-transform: uppercase; letter-spacing: 1.5px; font-weight: 700; display: block; margin-bottom: 8px;">आपका सत्यापन कोड (OTP)</span>
              <span style="font-size: 34px; font-weight: 900; color: #FDE047; letter-spacing: 9px; font-family: monospace;">$otp</span>
              <span style="font-size: 11px; color: #A7F3D0; display: block; margin-top: 8px; font-weight: 600;">⏱️ यह कोड 10 मिनट के लिए मान्य है</span>
            </td>
          </tr>
        </table>

        <!-- Security Notice -->
        <div style="background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 10px 14px; border-radius: 6px; margin: 18px 0 14px 0;">
          <p style="margin: 0; color: #92400E; font-size: 11.5px; line-height: 1.5;">
            🔒 <strong>सुरक्षा सूचना:</strong> इस कोड को किसी भी अनजान व्यक्ति के साथ साझा न करें। DM Lace टीम कभी भी आपका पासवर्ड या OTP नहीं मांगती।
          </p>
        </div>

        <p style="margin: 16px 0 0 0; color: #64748B; font-size: 11.5px; line-height: 1.5;">
          यदि आपने यह अनुरोध नहीं किया था, तो आप इस ईमेल को सुरक्षित रूप से अनदेखा कर सकते हैं।
        </p>
      </td>
    </tr>

    <!-- Footer -->
    <tr>
      <td style="background-color: #F8FAFC; padding: 18px 24px; text-align: center; border-top: 1px solid #E2E8F0;">
        <p style="margin: 0; color: #0F172A; font-size: 12px; font-weight: 800;">DM LACE SURAT</p>
        <p style="margin: 4px 0 0 0; color: #64748B; font-size: 10.5px;">रिंग रोड, सूरत (गुजरात) • 100% सुरक्षित बहीखाता</p>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
