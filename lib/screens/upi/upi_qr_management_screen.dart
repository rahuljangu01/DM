import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../models/upi_qr_account.dart';
import '../../services/upi_qr_service.dart';
import '../../widgets/compact_fab.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/upi_qr_dialog.dart';

class UpiQrManagementScreen extends StatefulWidget {
  const UpiQrManagementScreen({super.key});

  @override
  State<UpiQrManagementScreen> createState() => _UpiQrManagementScreenState();
}

class _UpiQrManagementScreenState extends State<UpiQrManagementScreen> {
  List<UpiQrAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final list = await UpiQrService.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _setPrimary(UpiQrAccount acc) async {
    HapticFeedback.mediumImpact();
    await UpiQrService.setPrimaryAccount(acc.id);
    await _loadAccounts();
    if (!mounted) return;
    final lang = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.isHindi
              ? '"${acc.title}" को मुख्य (Primary) QR बना दिया गया है'
              : '"${acc.title}" set as Primary QR',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAccount(UpiQrAccount acc) async {
    final lang = context.read<LanguageProvider>();
    if (_accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi
              ? 'कम से कम एक QR कोड होना आवश्यक है!'
              : 'At least one QR code is required!',
          ),
          backgroundColor: AppColors.payableRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await ConfirmationDialog.show(
      context: context,
      title: lang.isHindi ? 'QR कोड हटाएं?' : 'Delete QR Code?',
      message: lang.isHindi
          ? 'क्या आप सचमुच "${acc.title}" (${acc.upiId}) को हटाना चाहते हैं?'
          : 'Are you sure you want to remove "${acc.title}" (${acc.upiId})?',
      confirmText: lang.isHindi ? 'हाँ, हटाएं' : 'Delete',
      isDestructive: true,
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      await UpiQrService.deleteAccount(acc.id);
      await _loadAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi ? 'QR कोड सफलतापूर्वक हटा दिया गया' : 'QR code deleted',
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAddEditSheet([UpiQrAccount? existing]) {
    HapticFeedback.lightImpact();
    final lang = context.read<LanguageProvider>();
    final isEdit = existing != null;

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final upiCtrl = TextEditingController(text: existing?.upiId ?? '');
    final holderCtrl = TextEditingController(text: existing?.accountHolderName ?? 'DM LACE SURAT');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String selectedBank = existing?.bankName ?? 'HDFC Bank';
    bool makePrimary = existing?.isPrimary ?? (_accounts.isEmpty);

    final formKey = GlobalKey<FormState>();

    final bankOptions = [
      'HDFC Bank',
      'ICICI Bank',
      'State Bank of India (SBI)',
      'Axis Bank',
      'Bank of Baroda',
      'Kotak Mahindra Bank',
      'Punjab National Bank',
      'Paytm Payments Bank',
      'Canara Bank',
      'Union Bank of India',
      lang.isHindi ? 'अन्य बैंक' : 'Other Bank',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFDE047), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEdit
                              ? (lang.isHindi ? 'QR कोड बदलें' : 'Edit QR Code')
                              : (lang.isHindi ? 'नया QR कोड' : 'New QR Code'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Account Label / Name
                    Text(
                      lang.isHindi ? 'खाते का नाम / पहचान *' : 'Account Label / Nickname *',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: lang.isHindi ? 'उदा. दुकान काउंटर, फर्म खाता, पर्सनल' : 'e.g. Shop Counter, Current A/c',
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (lang.isHindi ? 'कृपया पहचान का नाम दर्ज करें' : 'Please enter a name')
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // 2. UPI ID Field
                    Text(
                      lang.isHindi ? 'UPI ID (VPA) *' : 'UPI ID (VPA) *',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: upiCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: lang.isHindi ? 'उदा. dmlace@okhdfcbank या 9825123456@ybl' : 'e.g. dmlace@okhdfcbank or 9825123456@ybl',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return lang.isHindi ? 'कृपया UPI ID दर्ज करें' : 'Please enter UPI ID';
                        }
                        if (!v.contains('@')) {
                          return lang.isHindi ? 'सही UPI ID दर्ज करें (उदा. username@bank)' : 'Invalid UPI ID format (must contain @)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Bank Selection
                    Text(
                      lang.isHindi ? 'बैंक का नाम' : 'Bank Name',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      initialValue: bankOptions.contains(selectedBank) ? selectedBank : bankOptions.first,
                      items: bankOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13.5)))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedBank = val);
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.account_balance_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Account Holder Name
                    Text(
                      lang.isHindi ? 'खाताधारक का नाम (Business Name)' : 'Account Holder Name',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: holderCtrl,
                      decoration: InputDecoration(
                        hintText: lang.isHindi ? 'उदा. DM LACE SURAT' : 'e.g. DM LACE SURAT',
                        prefixIcon: const Icon(Icons.business_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Primary Checkbox Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.isHindi ? 'मुख्य (Primary) QR बनाएं' : 'Set as Primary QR',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  lang.isHindi ? 'बिल व डैशबोर्ड पर यह QR पहले दिखेगा' : 'Default QR shown on bills & dashboard',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: makePrimary,
                            activeThumbColor: AppColors.primaryGold,
                            onChanged: (val) {
                              setModalState(() => makePrimary = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final newAcc = UpiQrAccount(
                            id: existing?.id ?? 'upi_${DateTime.now().millisecondsSinceEpoch}',
                            title: titleCtrl.text.trim(),
                            upiId: upiCtrl.text.trim(),
                            accountHolderName: holderCtrl.text.trim().isEmpty ? 'DM LACE SURAT' : holderCtrl.text.trim(),
                            bankName: selectedBank,
                            isPrimary: makePrimary,
                            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          );

                          if (isEdit) {
                            await UpiQrService.updateAccount(newAcc);
                          } else {
                            await UpiQrService.addAccount(newAcc);
                          }

                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                          _loadAccounts();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lang.isHindi
                                    ? (isEdit ? 'QR कोड अपडेट हो गया!' : 'नया QR कोड सफलतापूर्वक जुड़ गया!')
                                    : (isEdit ? 'QR code updated!' : 'QR code added successfully!'),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFFFDE047), size: 19),
                            const SizedBox(width: 8),
                            Text(
                              isEdit
                                  ? (lang.isHindi ? 'बदलाव सहेजें' : 'Save Changes')
                                  : (lang.isHindi ? 'QR कोड सुरक्षित करें' : 'Save QR Code'),
                              style: const TextStyle(
                                color: Color(0xFFFDE047),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'UPI QR कोड' : 'UPI QR Codes',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      floatingActionButton: CompactFab(
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'नया QR जोड़ें' : 'Add QR',
        onTap: () => _openAddEditSheet(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              color: AppColors.primaryGold,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                children: [
                  ..._accounts.map((acc) => _buildAccountCard(acc, lang)),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountCard(UpiQrAccount acc, LanguageProvider lang) {
    final isPrimary = acc.isPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? const Color(0xFFD4AF37) : const Color(0xFFE2E8F0),
          width: isPrimary ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bank Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: isPrimary ? const Color(0xFFFDE047) : const Color(0xFF475569),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              acc.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD4AF37), width: 0.9),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Color(0xFFB45309)),
                                  const SizedBox(width: 3),
                                  Text(
                                    lang.isHindi ? 'मुख्य QR' : 'Primary',
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            acc.bankName,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                          Expanded(
                            child: Text(
                              acc.accountHolderName,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // UPI ID with 1-tap Copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: acc.upiId));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lang.isHindi ? 'UPI ID कॉपी हो गई: ${acc.upiId}' : 'UPI ID copied: ${acc.upiId}'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alternate_email_rounded, size: 13, color: Color(0xFF0284C7)),
                              const SizedBox(width: 4),
                              Text(
                                acc.upiId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0369A1),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Action Row
            Row(
              children: [
                // Set as Primary button (if not primary)
                if (!isPrimary)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _setPrimary(acc),
                    icon: const Icon(Icons.star_outline_rounded, size: 15, color: Color(0xFFB45309)),
                    label: Text(
                      lang.isHindi ? 'मुख्य बनाएं' : 'Set Primary',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                    ),
                  ),

                // Test / Preview QR code
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    UpiQrDialog.show(
                      context,
                      partyName: acc.title,
                      amountRupees: 0,
                      note: '${lang.isHindi ? "भुगतान" : "Payment"} - ${acc.accountHolderName}',
                      account: acc,
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF0284C7)),
                  label: Text(
                    lang.isHindi ? 'QR देखें' : 'View QR',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                  ),
                ),

                const Spacer(),

                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openAddEditSheet(acc),
                ),

                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteAccount(acc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
