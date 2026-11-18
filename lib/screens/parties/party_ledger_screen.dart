import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/party.dart';
import '../../repositories/party_repository.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/party_avatar.dart';
import '../../widgets/upi_qr_dialog.dart';
import '../../services/pdf_service.dart';
import '../transactions/payment_entry_screen.dart';
import '../bills/create_edit_bill_screen.dart';
import '../challans/create_edit_challan_screen.dart';
import 'add_edit_party_screen.dart';

class PartyLedgerScreen extends StatefulWidget {
  final int partyId;
  final PartyRepository? repository;

  const PartyLedgerScreen({super.key, required this.partyId, this.repository});

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  late PartyRepository _repo;
  Party? _party;
  List<Map<String, dynamic>> _ledgerEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PartyRepository();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final party = await _repo.getPartyById(widget.partyId);
    final entries = await _repo.getPartyLedger(widget.partyId);
    if (mounted) {
      setState(() {
        _party = party;
        _ledgerEntries = entries;
        _isLoading = false;
      });
    }
  }

  void _shareLedgerSummary() {
    if (_party == null) return;
    final balance = _party!.currentBalanceRupees;
    final isReceivable = balance >= 0;

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '${_party!.name} • ${Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Share Ledger', hi: 'खाता शेयर करें')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 14),
                // 1. PDF Statement Share
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E3A8A), size: 20),
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: '📄 Share PDF Statement',
                      hi: '📄 PDF खाता विवरण शेयर करें',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: 'Printable Surat market format PDF with bills & QR',
                      hi: 'सूरत मार्केट फ़ॉर्मेट में बिल व QR कोड सहित PDF',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    PdfService.sharePartyLedgerPdf(
                      partyName: _party!.name,
                      partyPhone: _party!.phone,
                      partyAddress: _party!.address,
                      currentBalanceRupees: balance,
                      ledgerEntries: _ledgerEntries,
                    );
                  },
                ),
                // 2. UPI QR Code Modal
                if (isReceivable && balance > 0)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    title: Text(
                      Provider.of<LanguageProvider>(context, listen: false).tr(
                        en: '⚡ Collect Payment via UPI QR',
                        hi: '⚡ UPI QR कोड से पेमेंट लें',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      Provider.of<LanguageProvider>(context, listen: false).tr(
                        en: 'Instant scan & pay via GPay / PhonePe / Paytm',
                        hi: 'GPay / PhonePe / Paytm से तुरंत स्कैन व पे',
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      UpiQrDialog.show(
                        context,
                        partyName: _party!.name,
                        amountRupees: balance.abs(),
                      );
                    },
                  ),
                // 3. Text Message Summary
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: '💬 Share Text Summary',
                      hi: '💬 केवल टेक्स्ट सारांश भेजें',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: 'Quick WhatsApp ledger balance message',
                      hi: 'WhatsApp पर संक्षिप्त खाता बही संदेश',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final lang = Provider.of<LanguageProvider>(context, listen: false);
                    final isHi = lang.isHindi;
                    final message = isHi
                        ? '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
खाता विवरण
पार्टी: ${_party!.name}
तारीख: ${DateFormatter.today()}
----------------------------------------
${isReceivable ? "बाकी रकम (लेना):" : "जमा रकम (देना):"} ₹ ${CurrencyFormatter.format(balance.abs())}
----------------------------------------
${isReceivable ? "कृपया बकाया राशि का भुगतान जल्द कराने की कृपा करें।" : "आपका खाता हमारे यहां जमा है।"}
धन्यवाद! • DM Lace Surat
'''
                        : '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Account Statement
Party: ${_party!.name}
Date: ${DateFormatter.today()}
----------------------------------------
${isReceivable ? "Balance Due:" : "Advance Deposit:"} ₹ ${CurrencyFormatter.format(balance.abs())}
----------------------------------------
${isReceivable ? "Please arrange payment at your earliest convenience." : "Your account has a credit balance."}
Thank You! • DM Lace Surat
''';
                    ShareHelper.shareText(message, subject: 'DM Lace Surat - ${_party!.name}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri callUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        _copyPhone(phone);
      }
    } catch (_) {
      _copyPhone(phone);
    }
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.tr(en: 'Phone number copied: $phone', hi: 'फ़ोन नंबर कॉपी हो गया: $phone')),
        backgroundColor: AppColors.primaryNavy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsAppChat() async {
    if (_party == null || _party!.phone == null || _party!.phone!.isEmpty) return;
    var cleanPhone = _party!.phone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final balance = _party!.currentBalanceRupees;
    final isReceivable = balance >= 0;
    final balanceText = '₹ ${CurrencyFormatter.format(balance.abs())}';

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final message = lang.isHindi
        ? '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
खाता विवरण
पार्टी: ${_party!.name}
तारीख: ${DateFormatter.today()}
----------------------------------------
${isReceivable ? "बाकी रकम (लेना):" : "जमा रकम (देना):"} $balanceText
----------------------------------------
${isReceivable ? "कृपया बकाया राशि का भुगतान जल्द कराने की कृपा करें।" : "आपका खाता हमारे यहां जमा है।"}
धन्यवाद! • DM Lace Surat
'''
        : '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Account Statement
Party: ${_party!.name}
Date: ${DateFormatter.today()}
----------------------------------------
${isReceivable ? "Balance Due:" : "Advance Deposit:"} $balanceText
----------------------------------------
${isReceivable ? "Please arrange payment at your earliest convenience." : "Your account has a credit balance."}
Thank You! • DM Lace Surat
''';

    final Uri waUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        ShareHelper.shareText(message, subject: '${_party!.name} - DM Lace Surat');
      }
    } catch (_) {
      ShareHelper.shareText(message, subject: '${_party!.name} - DM Lace Surat');
    }
  }

  Future<void> _deleteParty() async {
    final canDelete = await _repo.canDeleteParty(widget.partyId);
    if (!mounted) return;

    if (!canDelete) {
      final confirmArchive = await ConfirmationDialog.show(
        context: context,
        title: 'Transactions Exist on Party',
        message: 'This party has bills or payments recorded. To preserve accounting integrity, this party will be archived instead of permanently deleted.',
        confirmText: 'Archive Party',
        isDestructive: false,
      );
      if (confirmArchive == true) {
        await _repo.deleteParty(widget.partyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party archived successfully.')),
          );
          Navigator.of(context).pop();
        }
      }
    } else {
      final confirmDelete = await ConfirmationDialog.show(
        context: context,
        title: 'Delete Party',
        message: 'Are you sure you want to permanently delete this party? This action cannot be undone.',
        confirmText: 'Delete Permanently',
        isDestructive: true,
      );
      if (confirmDelete == true) {
        await _repo.deleteParty(widget.partyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party deleted.')),
          );
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Party Ledger')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    if (_party == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Party Not Found')),
        body: const Center(child: Text('Party could not be found.')),
      );
    }

    final balance = _party!.currentBalanceRupees;
    final isReceivable = balance >= 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            PartyAvatar(
              name: _party!.name,
              imagePath: _party!.imagePath,
              size: 32,
              fontSize: 13,
              heroTag: 'party_avatar_${_party!.id}',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _party!.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_party!.phone != null && _party!.phone!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call_rounded, color: AppColors.goldLight),
              tooltip: 'कॉल करें (Call)',
              onPressed: () => _makePhoneCall(_party!.phone!),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4ADE80)),
              tooltip: 'व्हाट्सएप्प (WhatsApp)',
              onPressed: _openWhatsAppChat,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFDE047)),
            tooltip: 'UPI QR कोड (भुगतान लें)',
            onPressed: () {
              UpiQrDialog.show(
                context,
                partyName: _party!.name,
                amountRupees: balance > 0 ? balance.abs() : 0,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.goldLight),
            onPressed: _shareLedgerSummary,
            tooltip: 'Share Statement',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.goldLight),
            onSelected: (val) async {
              if (val == 'edit') {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddEditPartyScreen(party: _party)),
                );
                if (res == true) _loadLedger();
              } else if (val == 'delete') {
                _deleteParty();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Details')],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [Icon(Icons.delete_outline, size: 18, color: AppColors.payableRed), SizedBox(width: 8), Text('Delete / Archive', style: TextStyle(color: AppColors.payableRed))],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card with Outstanding Status
          Container(
            color: AppColors.primaryNavy,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_party!.phone != null && _party!.phone!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => _copyPhone(_party!.phone!),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_android_rounded, size: 13, color: AppColors.primaryGold),
                                        const SizedBox(width: 4),
                                        Text(
                                          _party!.phone!,
                                          style: const TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy_rounded, size: 11, color: AppColors.textMuted),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _makePhoneCall(_party!.phone!),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.call_rounded, size: 10, color: Colors.lightBlueAccent),
                                          SizedBox(width: 3),
                                          Text('कॉल', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _openWhatsAppChat,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.chat_bubble_rounded, size: 10, color: Color(0xFF4ADE80)),
                                          SizedBox(width: 3),
                                          Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_party!.address != null && _party!.address!.isNotEmpty)
                            Text(
                              _party!.address!,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.navySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReceivable ? 'NET RECEIVABLE (लेना बाकी)' : 'NET PAYABLE (देना बाकी)',
                            style: const TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(balance.abs()),
                            style: TextStyle(
                              color: isReceivable ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFDE047),
                              side: const BorderSide(color: Color(0xFFD4AF37)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                            label: const Text('UPI QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: () {
                              UpiQrDialog.show(
                                context,
                                partyName: _party!.name,
                                amountRupees: balance > 0 ? balance.abs() : 0,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGold,
                              foregroundColor: AppColors.primaryNavy,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.currency_rupee_rounded, size: 16),
                            label: Text(
                              isReceivable ? 'Receive' : 'Pay',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: () async {
                              final txType = isReceivable ? 'customer_receipt' : 'supplier_payment';
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PaymentEntryScreen(
                                    initialPartyId: _party!.id,
                                    initialTxType: txType,
                                  ),
                                ),
                              );
                              _loadLedger();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons Bar
          Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long, size: 15),
                    label: const Text('बिल (Bill)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateEditBillScreen(initialPartyId: _party!.id),
                        ),
                      );
                      _loadLedger();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_shipping_outlined, size: 15),
                    label: const Text('चालान', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateEditChallanScreen(initialPartyId: _party!.id),
                        ),
                      );
                      _loadLedger();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.currency_rupee_rounded, size: 15),
                    label: const Text('पेमेंट / जमा', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () async {
                      final txType = isReceivable ? 'customer_receipt' : 'supplier_payment';
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaymentEntryScreen(
                            initialPartyId: _party!.id,
                            initialTxType: txType,
                          ),
                        ),
                      );
                      _loadLedger();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Ledger Table / List Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceMuted,
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Date & Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Debit (+)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Credit (-)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              ],
            ),
          ),

          // Ledger Entries
          Expanded(
            child: _ledgerEntries.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No Ledger Entries',
                    message: 'No bills, challans, or payments recorded for this party yet.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _ledgerEntries.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = _ledgerEntries[index];
                      final isChallan = item['is_challan'] == true;
                      final debitPaise = item['debit_paise'] as int;
                      final creditPaise = item['credit_paise'] as int;
                      final runningPaise = item['running_balance_paise'] as int;
                      final dateStr = item['date'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date & Description
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormatter.format(DateFormatter.parse(dateStr)),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['description'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isChallan ? AppColors.secondaryNavy : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Debit
                            Expanded(
                              flex: 2,
                              child: Text(
                                debitPaise > 0 ? CurrencyFormatter.formatPaise(debitPaise, showDecimals: false) : '-',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),

                            // Credit
                            Expanded(
                              flex: 2,
                              child: Text(
                                creditPaise > 0 ? CurrencyFormatter.formatPaise(creditPaise, showDecimals: false) : '-',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successGreen),
                              ),
                            ),

                            // Running Balance
                            Expanded(
                              flex: 2,
                              child: Text(
                                isChallan ? '(Challan)' : CurrencyFormatter.formatPaise(runningPaise.abs(), showDecimals: false),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isChallan
                                      ? AppColors.textMuted
                                      : (runningPaise >= 0 ? AppColors.receivableGreen : AppColors.payableRed),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
