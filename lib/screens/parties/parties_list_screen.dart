import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/share_helper.dart';
import '../../models/party.dart';
import '../../repositories/party_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/party_avatar.dart';
import '../../widgets/compact_fab.dart';
import '../../widgets/upi_qr_dialog.dart';
import 'add_edit_party_screen.dart';
import 'party_ledger_screen.dart';

class PartiesListScreen extends StatefulWidget {
  final PartyRepository? repository;

  const PartiesListScreen({super.key, this.repository});

  @override
  State<PartiesListScreen> createState() => _PartiesListScreenState();
}

class _PartiesListScreenState extends State<PartiesListScreen> {
  late PartyRepository _repo;
  List<Party> _parties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PartyRepository();
    _loadParties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    final list = await _repo.getAllParties(
      type: 'all',
      searchQuery: _searchQuery,
    );

    // Auto-heal: If phone number was saved in address, migrate it to phone in DB
    for (final p in list) {
      if ((p.phone == null || p.phone!.trim().isEmpty) && p.address != null) {
        final clean = p.address!.trim();
        final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 5 && !RegExp(r'[a-zA-Z\u0900-\u097F]').hasMatch(clean)) {
          try {
            await _repo.updateParty(p.copyWith(phone: clean, address: ''));
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      setState(() {
        _parties = list;
        _isLoading = false;
      });
    }
  }

  String? _resolvePhone(Party party) {
    if (party.phone != null && party.phone!.trim().isNotEmpty) {
      return party.phone!.trim();
    }
    if (party.address != null) {
      final clean = party.address!.trim();
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 5 && !RegExp(r'[a-zA-Z\u0900-\u097F]').hasMatch(clean)) {
        return clean;
      }
    }
    return null;
  }

  String? _resolveAddress(Party party, String? resolvedPhone) {
    if (party.address == null || party.address!.trim().isEmpty) return null;
    final clean = party.address!.trim();
    if (resolvedPhone != null &&
        clean.replaceAll(RegExp(r'[^0-9]'), '') == resolvedPhone.replaceAll(RegExp(r'[^0-9]'), '')) {
      return null;
    }
    return clean;
  }

  List<Party> get _filteredParties {
    if (_searchQuery.trim().isEmpty) return _parties;
    final q = _searchQuery.toLowerCase().trim();
    return _parties.where((p) {
      final phone = _resolvePhone(p) ?? '';
      final address = _resolveAddress(p, phone) ?? '';
      final matchesName = p.name.toLowerCase().contains(q);
      final matchesPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').contains(q);
      final matchesAddress = address.toLowerCase().contains(q);
      return matchesName || matchesPhone || matchesAddress;
    }).toList();
  }

  Future<void> _makePhoneCall(String phone, String name, LanguageProvider lang) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri callUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        _copyContact(phone, name, lang);
      }
    } catch (_) {
      _copyContact(phone, name, lang);
    }
  }

  Future<void> _openWhatsAppChat(Party party, LanguageProvider lang, [String? overridePhone]) async {
    final phoneToUse = overridePhone ?? party.phone;
    if (phoneToUse == null || phoneToUse.isEmpty) return;
    var cleanPhone = phoneToUse.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final message = lang.isHindi
        ? '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
नमस्ते ${party.name} जी,
व्यापारिक संपर्क एवं लेन-देन विवरण हेतु।
----------------------------------------
धन्यवाद! • DM Lace Surat
'''
        : '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Hello ${party.name} ji,
Connecting for business communications & ledger.
----------------------------------------
Thank You! • DM Lace Surat
''';

    final Uri waUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        ShareHelper.shareText(message, subject: '${party.name} - DM Lace Surat');
      }
    } catch (_) {
      ShareHelper.shareText(message, subject: '${party.name} - DM Lace Surat');
    }
  }

  void _handleMissingPhone(Party party, LanguageProvider lang) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.isHindi
            ? 'कॉल/व्हाट्सएप के लिए कृपया पहले "${party.name}" का फ़ोन नंबर जोड़ें।'
            : 'Please add phone number for "${party.name}" first.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: lang.isHindi ? 'नंबर जोड़ें' : 'Add Phone',
          textColor: const Color(0xFFFDE047),
          onPressed: () => _navigateToPartyForm(party),
        ),
      ),
    );
    _navigateToPartyForm(party);
  }

  void _copyContact(String phone, String name, LanguageProvider lang) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.isHindi ? '$name का नंबर कॉपी हो गया: $phone' : 'Copied $name phone: $phone'),
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _navigateToPartyForm([Party? party]) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditPartyScreen(party: party),
      ),
    );
    if (res == true) {
      _loadParties();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final list = _filteredParties;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryNavy,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.isHindi ? 'पार्टी संपर्क' : 'Party Contacts',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
            Text(
              lang.isHindi
                  ? 'DM LACE SURAT • ${_parties.length} संपर्क'
                  : 'DM Lace Surat • ${_parties.length} Contacts',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.goldLight),
            tooltip: lang.isHindi ? 'दुकान का UPI QR' : 'Shop UPI QR',
            onPressed: () {
              UpiQrDialog.show(
                context,
                partyName: lang.isHindi ? 'दुकान काउंटर' : 'Shop Counter',
                amountRupees: 0,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.goldLight),
            tooltip: lang.isHindi ? 'रिफ्रेश' : 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadParties();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _isLoading
              ? const _ShimmerContactList()
              : RefreshIndicator(
                  color: AppColors.primaryGold,
                  onRefresh: _loadParties,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Sleek Direct Search Bar
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: lang.isHindi
                                    ? 'नाम, फ़ोन नंबर या मार्केट से खोजें...'
                                    : 'Search by name, phone or market...',
                                hintStyle: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.primaryNavy,
                                  size: 20,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchQuery.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                          _loadParties();
                                        },
                                      ),
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                      ),
                                      child: Text(
                                        '${list.length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                              },
                            ),
                          ),
                        ),
                      ),

                      // 2. High-Density Contact List (Responsive 3 cols / 2 cols / 1 col)
                      if (list.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.contact_phone_outlined,
                            title: lang.isHindi ? 'कोई संपर्क नहीं मिला' : 'No Contacts Found',
                            message: _searchQuery.isNotEmpty
                                ? (lang.isHindi
                                    ? '"$_searchQuery" से मिलता कोई संपर्क नहीं मिला।'
                                    : 'No contacts matched "$_searchQuery".')
                                : (lang.isHindi
                                    ? 'नया संपर्क जोड़ने के लिए नीचे दिए गए बटन पर टैप करें।'
                                    : 'Tap the button below to add your first contact.'),
                          ),
                        )
                      else
                        SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final isDesktop = width >= 950;
                            final isTablet = width >= 650 && width < 950;

                            if (isDesktop) {
                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 4.8,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _AnimatedPartyCard(
                                      key: ValueKey(list[index].id ?? index),
                                      index: index,
                                      child: _buildPartyCard(list[index], lang),
                                    ),
                                    childCount: list.length,
                                  ),
                                ),
                              );
                            } else if (isTablet) {
                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 4.5,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _AnimatedPartyCard(
                                      key: ValueKey(list[index].id ?? index),
                                      index: index,
                                      child: _buildPartyCard(list[index], lang),
                                    ),
                                    childCount: list.length,
                                  ),
                                ),
                              );
                            }

                            // Mobile View: Single Column List (Super Compact High-Density: fits 7-8 per screen!)
                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: _AnimatedPartyCard(
                                      key: ValueKey(list[index].id ?? index),
                                      index: index,
                                      child: _buildPartyCard(list[index], lang),
                                    ),
                                  ),
                                  childCount: list.length,
                                ),
                              ),
                            );
                          },
                        ),

                      // Bottom clearance for FAB
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 85),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_add_contact',
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'नया संपर्क' : 'Add Contact',
        onTap: () => _navigateToPartyForm(),
      ),
    );
  }

  Widget _buildPartyCard(Party party, LanguageProvider lang) {
    final phone = _resolvePhone(party);
    final address = _resolveAddress(party, phone);
    final hasPhone = phone != null && phone.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: party.id!)),
            );
            _loadParties();
          },
          onLongPress: hasPhone ? () => _copyContact(phone, party.name, lang) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar with Dynamic Gradient / Uploaded Photo + Hero
                PartyAvatar(
                  name: party.name,
                  imagePath: party.imagePath,
                  size: 40,
                  fontSize: 16.5,
                  heroTag: party.id != null ? 'party_avatar_${party.id}' : null,
                ),
                const SizedBox(width: 11),

                // Name & Contact Information
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.5),
                      Row(
                        children: [
                          if (hasPhone) ...[
                            const Icon(Icons.phone_iphone_rounded, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 12.2,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.info_outline_rounded, size: 11.5, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              lang.isHindi ? 'फ़ोन नंबर जोड़ें' : 'Add phone',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (address != null && address.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            const Text('•', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const SizedBox(width: 5),
                            const Icon(Icons.location_on_outlined, size: 11.5, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Uniform Quick Actions Row: Call, WhatsApp, Edit, Chevron!
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Call Button (Always Present!)
                    _BouncingButton(
                      tooltip: hasPhone
                          ? (lang.isHindi ? 'कॉल करें ($phone)' : 'Call ($phone)')
                          : (lang.isHindi ? 'नंबर जोड़ें' : 'Add Phone'),
                      onTap: () {
                        if (hasPhone) {
                          _makePhoneCall(phone, party.name, lang);
                        } else {
                          _handleMissingPhone(party, lang);
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasPhone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasPhone ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.call_rounded,
                          size: 15,
                          color: hasPhone ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    const SizedBox(width: 5),

                    // 2. WhatsApp Button (Always Present!)
                    _BouncingButton(
                      tooltip: hasPhone
                          ? (lang.isHindi ? 'WhatsApp चैट खोलें' : 'Open WhatsApp')
                          : (lang.isHindi ? 'WhatsApp हेतु नंबर जोड़ें' : 'Add Phone for WhatsApp'),
                      onTap: () {
                        if (hasPhone) {
                          _openWhatsAppChat(party, lang, phone);
                        } else {
                          _handleMissingPhone(party, lang);
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasPhone ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasPhone ? const Color(0xFF7DD3FC) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          size: 14,
                          color: hasPhone ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    const SizedBox(width: 5),

                    // 3. Edit Button (Always Present!)
                    _BouncingButton(
                      tooltip: lang.isHindi ? 'एडिट करें' : 'Edit Contact',
                      onTap: () => _navigateToPartyForm(party),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),

                    const SizedBox(width: 3),

                    // 4. Chevron Indicator (›)
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile Bouncing Micro-Interaction Widget
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

/// Smooth Staggered Waterfall Card Entrance Animation
class _AnimatedPartyCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedPartyCard({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delayMs = (index * 35).clamp(0, 350);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, animChild) {
        return Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: animChild,
          ),
        );
      },
      child: child,
    );
  }
}

/// Glowing Shimmer Skeleton Loading Widget (7 Skeleton Cards)
class _ShimmerContactList extends StatefulWidget {
  const _ShimmerContactList();

  @override
  State<_ShimmerContactList> createState() => _ShimmerContactListState();
}

class _ShimmerContactListState extends State<_ShimmerContactList> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: 7, // Displays 7 preview items to demonstrate high-density layout
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: Row(
                children: [
                  // Shimmer Avatar
                  _buildShimmerBox(width: 40, height: 40, isCircle: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(width: 120, height: 13, borderRadius: 4),
                        const SizedBox(height: 6),
                        _buildShimmerBox(width: 170, height: 10, borderRadius: 3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildShimmerBox(width: 32, height: 32, isCircle: true),
                  const SizedBox(width: 5),
                  _buildShimmerBox(width: 32, height: 32, isCircle: true),
                  const SizedBox(width: 5),
                  _buildShimmerBox(width: 32, height: 32, isCircle: true),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    bool isCircle = false,
    double borderRadius = 0,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.2 + (_shimmerController.value * 2.4), 0),
          end: Alignment(0.6 + (_shimmerController.value * 2.4), 0),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
