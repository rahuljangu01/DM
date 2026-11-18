import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/language_provider.dart';

class AppStrings {
  static const String appName = 'DM Lace Surat';
  static const String appTagline = 'Business Manager • लेस व्यापार मैनेजर';
  static const String suratHub = 'Surat Textile Market, Ring Road, Gujarat';

  // Helper method to get localized string via context
  static String tr(BuildContext context, {required String en, required String hi}) {
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: true).currentLanguage;
      return lang == AppLanguage.hindi ? hi : en;
    } catch (_) {
      // Fallback to static instance if provider context is unavailable
      return LanguageProvider().isHindi ? hi : en;
    }
  }

  // Navigation Labels
  static String navDashboard(BuildContext context) => tr(context, en: 'Dashboard', hi: 'डैशबोर्ड');
  static String navParties(BuildContext context) => tr(context, en: 'Parties', hi: 'पार्टियां');
  static String navBills(BuildContext context) => tr(context, en: 'Bills', hi: 'बिल व चालान');
  static String navCashbook(BuildContext context) => tr(context, en: 'Cashbook', hi: 'रोकड़ बही');
  static String navMore(BuildContext context) => tr(context, en: 'More', hi: 'अन्य विकल्प');

  // Quick Action Buttons
  static String newBill(BuildContext context) => tr(context, en: 'New Bill', hi: 'नया बिल');
  static String newChallan(BuildContext context) => tr(context, en: 'Challan', hi: 'चालान');
  static String newPayment(BuildContext context) => tr(context, en: 'Payment', hi: 'पेमेंट');
  static String dailyReport(BuildContext context) => tr(context, en: 'Report', hi: 'रिपोर्ट');

  // Dashboard Financial Headings
  static String outstandingBalances(BuildContext context) => tr(context, en: 'Outstanding Balances', hi: 'बकाया राशि');
  static String viewAllParties(BuildContext context) => tr(context, en: 'View All Parties', hi: 'सभी पार्टियां देखें');
  static String totalReceivables(BuildContext context) => tr(context, en: 'Receivables', hi: 'कुल लेना (वसूली)');
  static String totalPayables(BuildContext context) => tr(context, en: 'Payables', hi: 'कुल देना (भुगतान)');
  static String cashBalance(BuildContext context) => tr(context, en: 'Cash in Hand', hi: 'गल्ला रोकड़');
  static String bankBalance(BuildContext context) => tr(context, en: 'Bank Balance', hi: 'बैंक चालू खाता');

  // Today's Pulse
  static String todayPulse(BuildContext context) => tr(context, en: "Today's Business Pulse", hi: 'आज का व्यापार हिसाब');
  static String todaySales(BuildContext context) => tr(context, en: "Today's Sales", hi: 'आज की लेस बिक्री');
  static String todayReceipts(BuildContext context) => tr(context, en: 'Customer Receipts', hi: 'ग्राहकों से जमा');
  static String todayPayments(BuildContext context) => tr(context, en: 'Supplier Payments', hi: 'सप्लायरों को भुगतान');
  static String todayPurchases(BuildContext context) => tr(context, en: 'Raw Purchases', hi: 'आज माल की खरीद');

  // Inventory & Recent
  static String stockHealth(BuildContext context) => tr(context, en: 'Lace Stock Inventory', hi: 'लेस स्टॉक इन्वेंटरी');
  static String recentTransactions(BuildContext context) => tr(context, en: 'Recent Transactions', hi: 'हाल के लेन-देन');
  static String monthlyTrends(BuildContext context) => tr(context, en: 'Monthly Trends', hi: 'मासिक व्यापार ट्रेंड');

  // Legacy static constants for compatibility
  static const String navDashboardStatic = 'Dashboard';
  static const String navPartiesStatic = 'Parties (पार्टी)';
  static const String navBillsStatic = 'Bills & Challan';
  static const String navCashbookStatic = 'Cashbook (रोकड़)';
  static const String navMoreStatic = 'More';

  static const String receivables = 'Receivables (लेना बाकी)';
  static const String payables = 'Payables (देना बाकी)';
  static const String overdue = 'Overdue Payments (समय सीमा समाप्त)';

  static const String customer = 'Customer (ग्राहक)';
  static const String supplier = 'Supplier (व्यापारी / मिल)';
  static const String both = 'Both (ग्राहक व व्यापारी)';

  static const String kacchaBill = 'Kaccha Bill / Cash Memo (कच्चा बिल)';
  static const String challan = 'Delivery Challan (चालान)';
  static const String taxInvoice = 'GST Tax Invoice (पक्का बिल)';

  static const String unitMeter = 'Meter (मीटर)';
  static const String unitRoll = 'Roll (थान/रोल)';
  static const String unitPiece = 'Piece (नग)';
  static const String unitKg = 'Kg (किलो)';
  static const String unitYard = 'Yard (गज)';

  static const String modeCash = 'Cash (नकद)';
  static const String modeUpi = 'UPI (GPay / PhonePe)';
  static const String modeBank = 'Bank Transfer / NEFT / RTGS';
  static const String modeCheque = 'Cheque (चेक)';
  static const String modeOther = 'Other';
}
