import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/share_helper.dart';
import '../models/upi_qr_account.dart';
import '../services/upi_qr_service.dart';
import '../screens/upi/upi_qr_management_screen.dart';

class UpiQrDialog extends StatefulWidget {
  final String partyName;
  final double amountRupees;
  final String upiId;
  final String businessName;
  final String? note;
  final UpiQrAccount? account;

  const UpiQrDialog({
    super.key,
    required this.partyName,
    required this.amountRupees,
    this.upiId = 'dmlace@upi',
    this.businessName = 'DM LACE SURAT',
    this.note,
    this.account,
  });

  static Future<void> show(
    BuildContext context, {
    required String partyName,
    double? amount,
    double amountRupees = 0,
    String upiId = 'dmlace@upi',
    String businessName = 'DM LACE SURAT',
    String? note,
    UpiQrAccount? account,
  }) {
    HapticFeedback.lightImpact();
    final effectiveAmount = amount ?? amountRupees;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpiQrDialog(
        partyName: partyName,
        amountRupees: effectiveAmount,
        upiId: upiId,
        businessName: businessName,
        note: note,
        account: account,
      ),
    );
  }

  @override
  State<UpiQrDialog> createState() => _UpiQrDialogState();
}

class _UpiQrDialogState extends State<UpiQrDialog> {
  late double _currentAmount;
  late TextEditingController _amountController;
  bool _isEditingAmount = false;
  List<UpiQrAccount> _accounts = [];
  UpiQrAccount? _activeAccount;
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.amountRupees;
    _amountController = TextEditingController(
      text: _currentAmount > 0 ? _currentAmount.toStringAsFixed(0) : '',
    );
    _activeAccount = widget.account;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await UpiQrService.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = list;
        _isLoadingAccounts = false;
        if (_activeAccount == null && list.isNotEmpty) {
          _activeAccount = list.firstWhere((a) => a.isPrimary, orElse: () => list.first);
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String get _currentUpiId => _activeAccount?.upiId ?? widget.upiId;
  String get _currentBusinessName => _activeAccount?.accountHolderName ?? widget.businessName;
  String get _currentAccountTitle => _activeAccount?.title ?? 'दुकान काउंटर';
  String get _currentBankName => _activeAccount?.bankName ?? 'Bank';

  String get _upiUrl {
    final note = Uri.encodeComponent(widget.note ?? 'Payment from ${widget.partyName} to $_currentBusinessName');
    final name = Uri.encodeComponent(_currentBusinessName);
    if (_currentAmount > 0) {
      return 'upi://pay?pa=$_currentUpiId&pn=$name&am=${_currentAmount.toStringAsFixed(2)}&cu=INR&tn=$note';
    } else {
      // Flexible amount - customer enters amount on their phone
      return 'upi://pay?pa=$_currentUpiId&pn=$name&cu=INR&tn=$note';
    }
  }

  void _shareViaWhatsApp() async {
    final amtText = _currentAmount > 0
        ? '₹ ${CurrencyFormatter.format(_currentAmount, includeSymbol: false)}'
        : 'आवश्यक राशि (खुली राशि)';

    final text = '''
🧵 *$_currentBusinessName • UPI भुगतान लिंक*
━━━━━━━━━━━━━━━━━━━━
👤 *पार्टी:* ${widget.partyName}
💰 *राशि:* $amtText
🏦 *खाता:* $_currentAccountTitle ($_currentBankName)
📲 *UPI ID:* $_currentUpiId
━━━━━━━━━━━━━━━━━━━━
🔗 *GPay / PhonePe / Paytm से भुगतान हेतु लिंक दबाएं:*
$_upiUrl

🙏 धन्यवाद • $_currentBusinessName
''';
    await ShareHelper.shareText(text, subject: 'Payment Request - $_currentBusinessName');
  }

  void _copyUpiUrl() {
    Clipboard.setData(ClipboardData(text: _upiUrl));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI भुगतान लिंक कॉपी हो गया!'),
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openManageQr() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpiQrManagementScreen()),
    );
    _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboardPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ UPI QR कोड भुगतान',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        Text(
                          'GPay • PhonePe • Paytm • BHIM QR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20, color: Color(0xFF64748B)),
                      tooltip: 'Manage QRs',
                      onPressed: _openManageQr,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Multi-QR Account Selector Tabs (PhonePe Style)
            if (!_isLoadingAccounts && _accounts.length > 1) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final acc = _accounts[index];
                    final isSelected = _activeAccount?.id == acc.id;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeAccount = acc);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.4 : 0.9,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (acc.isPrimary) ...[
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFDE047)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              acc.title,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFFFDE047) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Active Account & Amount Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentAccountTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _currentBankName,
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'UPI ID: $_currentUpiId',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() => _isEditingAmount = !_isEditingAmount);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentAmount > 0
                                    ? CurrencyFormatter.format(_currentAmount)
                                    : 'खुली राशि (Any Amt)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: _currentAmount > 0 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Amount quick editor
                  if (_isEditingAmount) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              hintText: 'रकम दर्ज करें (0 = खुली राशि)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: () {
                            final parsed = double.tryParse(_amountController.text.trim()) ?? 0.0;
                            setState(() {
                              _currentAmount = parsed;
                              _isEditingAmount = false;
                            });
                          },
                          child: const Text('लागू करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // High-Resolution Surat Gold Border QR Code Frame
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _UpiQrPainter(_upiUrl),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              _currentAmount > 0
                  ? 'ग्राहक किसी भी UPI ऐप (GPay, PhonePe, Paytm) से स्कैन कर सकता है'
                  : 'ग्राहक स्कैन करके अपनी पसंद की राशि भर सकता है',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primaryNavy, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _copyUpiUrl,
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primaryNavy),
                    label: const Text(
                      'लिंक कॉपी करें',
                      style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _shareViaWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'WhatsApp भेजें',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpiQrPainter extends CustomPainter {
  final String data;

  _UpiQrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );

    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final pixelSize = size.width / moduleCount;

    final darkPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          final rect = Rect.fromLTWH(
            x * pixelSize,
            y * pixelSize,
            pixelSize,
            pixelSize,
          );
          canvas.drawRect(rect, darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UpiQrPainter oldDelegate) => oldDelegate.data != data;
}
