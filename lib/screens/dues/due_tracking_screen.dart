import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import '../../widgets/empty_state.dart';
import '../transactions/payment_entry_screen.dart';

class DueTrackingScreen extends StatefulWidget {
  final DocumentRepository? repository;

  const DueTrackingScreen({super.key, this.repository});

  @override
  State<DueTrackingScreen> createState() => _DueTrackingScreenState();
}

class _DueTrackingScreenState extends State<DueTrackingScreen> {
  late DocumentRepository _repo;
  List<BusinessDocument> _allDues = [];
  Map<int, Map<String, String>> _partyInfoMap = {};
  String _shopName = 'DM LACE SURAT';
  String _shopPhone = '';
  String _shopUpi = '';
  bool _isLoading = true;
  String _selectedAging = 'all'; // all, due_today, overdue_1_7, overdue_8_30, overdue_30_plus, not_due
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DocumentRepository();
    _loadDues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDues() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch parties info (phone, firm_name)
      final partyRows = await db.query(DatabaseTables.tableParties);
      final Map<int, Map<String, String>> partyMap = {};
      for (final p in partyRows) {
        final id = p['id'] as int;
        partyMap[id] = {
          'phone': (p['phone'] as String? ?? '').trim(),
          'firm_name': (p['firm_name'] as String? ?? '').trim(),
          'name': (p['name'] as String? ?? '').trim(),
        };
      }

      // 2. Fetch shop profile (name, phone, upi)
      final settingsRows = await db.query(DatabaseTables.tableAppSettings);
      final settings = {for (final r in settingsRows) r['setting_key'] as String: r['setting_value'] as String};
      final shopName = settings['shop_name'] ?? 'DM LACE SURAT';
      final shopPhone = settings['shop_phone'] ?? '';
      final shopUpi = settings['shop_upi'] ?? '';

      // 3. Unpaid & Partial bills
      final unpaid = await _repo.getDocuments(status: 'unpaid');
      final partial = await _repo.getDocuments(status: 'partial');
      final combined = [...unpaid, ...partial].where((d) => !d.isChallan && !d.isCancelled).toList();

      if (mounted) {
        setState(() {
          _allDues = combined;
          _partyInfoMap = partyMap;
          _shopName = shopName;
          _shopPhone = shopPhone;
          _shopUpi = shopUpi;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BusinessDocument> get _filteredDues {
    return _allDues.where((d) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesNum = d.docNumber.toLowerCase().contains(q);
        final matchesParty = (d.partyName ?? '').toLowerCase().contains(q);
        final partyInfo = _partyInfoMap[d.partyId];
        final matchesFirm = (partyInfo?['firm_name'] ?? '').toLowerCase().contains(q);
        final matchesPhone = (partyInfo?['phone'] ?? '').contains(q);
        if (!matchesNum && !matchesParty && !matchesFirm && !matchesPhone) return false;
      }

      if (_selectedAging == 'all') return true;

      if (d.dueDate == null) {
        return _selectedAging == 'not_due';
      }

      final dueDate = DateFormatter.parse(d.dueDate);
      if (dueDate == null) return true;

      final days = DateFormatter.daysOverdue(dueDate);

      if (_selectedAging == 'not_due') return days < 0;
      if (_selectedAging == 'due_today') return days == 0;
      if (_selectedAging == 'overdue_1_7') return days >= 1 && days <= 7;
      if (_selectedAging == 'overdue_8_30') return days >= 8 && days <= 30;
      if (_selectedAging == 'overdue_30_plus') return days > 30;

      return true;
    }).toList();
  }

  String _formatReminderMessage(BusinessDocument doc, LanguageProvider lang) {
    final partyInfo = _partyInfoMap[doc.partyId];
    final partyDisplayName = (partyInfo?['firm_name'] ?? '').isNotEmpty
        ? '${partyInfo!['firm_name']} (${doc.partyName ?? "ग्राहक"})'
        : (doc.partyName ?? 'ग्राहक');

    final dueDateFormatted = doc.dueDate != null
        ? DateFormatter.format(DateFormatter.parse(doc.dueDate))
        : (lang.isHindi ? 'तुरंत (Immediate)' : 'Immediate');

    final upiSection = _shopUpi.isNotEmpty
        ? (lang.isHindi
            ? '\n💳 ऑनलाइन UPI द्वारा भुगतान करें:\nUPI ID: $_shopUpi\n(PhonePe / Google Pay / Paytm से सीधे पेमेंट करें)\n'
            : '\n💳 Pay via UPI:\nUPI ID: $_shopUpi\n(Pay directly via PhonePe, GPay, Paytm)\n')
        : '';

    final phoneSection = _shopPhone.isNotEmpty
        ? (lang.isHindi ? '📞 संपर्क: $_shopPhone\n' : '📞 Contact: $_shopPhone\n')
        : '';

    if (lang.isHindi) {
      return '''
*$_shopName*
सूरत टेक्सटाइल मार्केट
----------------------------------------
📌 *भुगतान तकादा (Payment Reminder)*
पार्टी: $partyDisplayName
बिल नंबर: #${doc.docNumber}
बिल तारीख: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}
देय तारीख: $dueDateFormatted
----------------------------------------
बिल कुल राशि: ${CurrencyFormatter.format(doc.grandTotalRupees)}
जमा राशि: ${CurrencyFormatter.format(doc.paidAmountRupees)}
*बाकी बकाया रकम: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}*
----------------------------------------$upiSection$phoneSection
कृपया बाकी रकम का भुगतान जल्द कराने की कृपा करें।
धन्यवाद! • $_shopName
''';
    } else {
      return '''
*$_shopName*
Surat Textile Market
----------------------------------------
📌 *Payment Reminder*
Party: $partyDisplayName
Bill No: #${doc.docNumber}
Bill Date: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}
Due Date: $dueDateFormatted
----------------------------------------
Bill Total: ${CurrencyFormatter.format(doc.grandTotalRupees)}
Paid: ${CurrencyFormatter.format(doc.paidAmountRupees)}
*Remaining Balance: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}*
----------------------------------------$upiSection$phoneSection
Kindly arrange payment for the remaining balance.
Thank You! • $_shopName
''';
    }
  }

  Future<void> _sendWhatsAppReminder(BusinessDocument doc, LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    final message = _formatReminderMessage(doc, lang);
    final partyInfo = _partyInfoMap[doc.partyId];
    final rawPhone = partyInfo?['phone'] ?? '';
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.isNotEmpty) {
      final phoneWithCountry = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
      final uri = Uri.parse('https://wa.me/$phoneWithCountry?text=${Uri.encodeComponent(message)}');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // Fallback to system share
    ShareHelper.shareText(message, subject: 'Payment Reminder - ${doc.docNumber}');
  }

  Future<void> _callParty(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final dues = _filteredDues;
    final totalPendingRupees = dues.fold<double>(0.0, (acc, d) => acc + d.remainingBalanceRupees);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'उधारी तकादा (Payment Reminders)' : 'Payment Reminders',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: lang.tr(en: 'Refresh', hi: 'रिफ्रेश'),
            onPressed: _loadDues,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Executive Outstanding Summary Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'TOTAL PENDING DUES', hi: 'कुल बाकी उधारी रकम'),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.format(totalPendingRupees),
                      style: const TextStyle(
                        color: Color(0xFFFDE047),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFFFDE047), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${dues.length} ${lang.tr(en: 'Bills Due', hi: 'बाकी बिल')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Real-time Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: lang.tr(
                  en: 'Search party name, firm or bill number...',
                  hi: 'पार्टी का नाम, फर्म या बिल नंबर खोजें...',
                ),
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),

          // 3. Aging Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(lang.isHindi ? 'सभी' : 'All', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip(lang.isHindi ? 'आज का तकादा' : 'Due Today', 'due_today'),
                  const SizedBox(width: 6),
                  _buildFilterChip(lang.isHindi ? '1–7 दिन' : '1–7 Days', 'overdue_1_7'),
                  const SizedBox(width: 6),
                  _buildFilterChip(lang.isHindi ? '8–30 दिन' : '8–30 Days', 'overdue_8_30'),
                  const SizedBox(width: 6),
                  _buildFilterChip(lang.isHindi ? '> 30 दिन' : '> 30 Days', 'overdue_30_plus'),
                  const SizedBox(width: 6),
                  _buildFilterChip(lang.isHindi ? 'समय बाकी' : 'Not Due', 'not_due'),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 4. Dues List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : dues.isEmpty
                    ? EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: lang.tr(en: 'No Pending Dues', hi: 'कोई बकाया उधारी नहीं है'),
                        message: lang.tr(
                          en: 'All payments are cleared for the selected filter.',
                          hi: 'बधाई! चुने गए फ़िल्टर में कोई भी बिल बाकी नहीं है।',
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF2563EB),
                        onRefresh: _loadDues,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: dues.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final doc = dues[idx];
                            return _buildDueCard(doc, lang);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedAging == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.lightImpact();
        setState(() => _selectedAging = value);
      },
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 11.5,
      ),
    );
  }

  Widget _buildDueCard(BusinessDocument doc, LanguageProvider lang) {
    final partyInfo = _partyInfoMap[doc.partyId];
    final phone = partyInfo?['phone'] ?? '';
    final firmName = partyInfo?['firm_name'] ?? '';

    final dueDate = DateFormatter.parse(doc.dueDate);
    final days = dueDate != null ? DateFormatter.daysOverdue(dueDate) : -1;
    final isOverdue = days > 0;
    final isDueToday = days == 0;

    String agingLabel;
    Color agingColor;
    Color agingBg;

    if (isDueToday) {
      agingLabel = lang.isHindi ? 'आज देय' : 'Due Today';
      agingColor = const Color(0xFFD97706);
      agingBg = const Color(0xFFFFFBEB);
    } else if (isOverdue) {
      agingLabel = lang.isHindi ? '$days दिन देरी' : '$days days overdue';
      agingColor = const Color(0xFFDC2626);
      agingBg = const Color(0xFFFEF2F2);
    } else {
      agingLabel = lang.isHindi ? '${days.abs()} दिन बाकी' : 'Due in ${days.abs()} days';
      agingColor = const Color(0xFF059669);
      agingBg = const Color(0xFFECFDF5);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isOverdue ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Party Name + Aging Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.partyName ?? 'Party #${doc.partyId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (firmName.isNotEmpty && firmName != doc.partyName) ...[
                      const SizedBox(height: 1),
                      Text(
                        firmName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Bill #${doc.docNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.format(DateFormatter.parse(doc.docDate)),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: agingBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: agingColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  agingLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: agingColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Balance Amount and Phone
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isHindi ? 'बाकी बकाया रकम' : 'Remaining Balance',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    CurrencyFormatter.format(doc.remainingBalanceRupees),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty)
                InkWell(
                  onTap: () => _callParty(phone),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons: WhatsApp Reminder & Collect Payment
          Row(
            children: [
              // WhatsApp Reminder Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text(
                    lang.isHindi ? 'WhatsApp तकादा' : 'WhatsApp Remind',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _sendWhatsAppReminder(doc, lang),
                ),
              ),
              const SizedBox(width: 8),

              // Collect Payment Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.currency_rupee_rounded, size: 15),
                  label: Text(
                    lang.isHindi ? 'जमा लें (Collect)' : 'Collect',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentEntryScreen(
                          initialPartyId: doc.partyId,
                          initialTxType: 'customer_receipt',
                          initialRelatedDocId: doc.id,
                          initialAmountRupees: doc.remainingBalanceRupees,
                        ),
                      ),
                    );
                    if (res == true) _loadDues();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
