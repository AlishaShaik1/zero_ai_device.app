import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/marketplace_service.dart';
import '../automation/models/connector_def.dart';

class ConnectorsScreen extends StatefulWidget {
  const ConnectorsScreen({Key? key}) : super(key: key);
  @override
  State<ConnectorsScreen> createState() => _ConnectorsScreenState();
}

class _ConnectorsScreenState extends State<ConnectorsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _search = TextEditingController();
  ConnectorCategory? _selectedCategory;
  late TabController _tabController;

  static const _categories = [
    null,
    ConnectorCategory.communication,
    ConnectorCategory.productivity,
    ConnectorCategory.social,
    ConnectorCategory.design,
    ConnectorCategory.developer,
    ConnectorCategory.ai,
    ConnectorCategory.entertainment,
    ConnectorCategory.shopping,
    ConnectorCategory.foodDelivery,
    ConnectorCategory.finance,
    ConnectorCategory.travel,
    ConnectorCategory.utilities,
  ];

  static const _categoryLabels = [
    'All', 'Messages', 'Productivity', 'Social', 'Design',
    'Developer', 'AI', 'Entertainment', 'Shopping', 'Food',
    'Finance', 'Travel', 'Utilities',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedCategory = _categories[_tabController.index]);
        _reload();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    MarketplaceService.instance.loadCatalog(
      query: _search.text.trim().isEmpty ? null : _search.text.trim(),
      category: _selectedCategory?.name,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: MarketplaceService.instance,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Column(children: [
            _Header(onBack: () => Navigator.pop(context)),
            _SearchBar(controller: _search, onSearch: _reload),
            _CategoryTabs(
                controller: _tabController, labels: _categoryLabels),
            Expanded(child: _ConnectorGrid(onConnect: _handleConnect)),
          ]),
        ),
      ),
    );
  }

  Future<void> _handleConnect(ConnectorDef connector) async {
    HapticFeedback.mediumImpact();
    final status = MarketplaceService.instance.authStatusFor(connector.id);

    if (status == 'connected') {
      // Show disconnect dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: 'Disconnect ${connector.displayName}?',
          body: 'Zero will no longer be able to use ${connector.displayName} for you.',
          confirmLabel: 'Disconnect',
          isDanger: true,
        ),
      );
      if (confirm == true) {
        await MarketplaceService.instance.disconnect(connector.id);
      }
      return;
    }

    // Accessibility-only connectors don't need OAuth
    if (connector.feasibility == FeasibilityTier.accessibilityOnly) {
      showDialog(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: '${connector.displayName} — Accessibility Mode',
          body: connector.tosRisk
              ? '⚠️ This connector uses Android Accessibility to control the app. It\'s limited to single, user-initiated actions only.'
              : 'Zero will use Android Accessibility to automate ${connector.displayName}. Grant accessibility permission in Android settings.',
          confirmLabel: 'Enable',
          isDanger: connector.tosRisk,
        ),
      );
      return;
    }

    if (connector.feasibility == FeasibilityTier.partnershipOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${connector.displayName} requires a business partnership. Coming soon!'),
          backgroundColor: const Color(0xFF1E1E2E),
        ),
      );
      return;
    }

    // Launch OAuth flow
    final url = MarketplaceService.instance.buildOAuthStartUrl(connector.id);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // The OAuth callback will deep-link back to the app
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the sign-in page.')),
      );
    }
  }
}

// ── HEADER ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Connector Marketplace',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Connect apps. Expand what Zero can do.',
                style: TextStyle(fontSize: 13, color: Colors.white38)),
          ]),
        ),
      ]),
    ).animate().fadeIn().slideX(begin: -0.05, duration: 300.ms);
  }
}

// ── SEARCH BAR ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: 'Search 150+ connectors…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 20),
            suffixIcon: IconButton(
              icon: Icon(Icons.tune_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
              onPressed: onSearch,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 80.ms);
  }
}

// ── CATEGORY TABS ─────────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  const _CategoryTabs({required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        indicatorColor: const Color(0xFF00C9C8),
        indicatorWeight: 2,
        labelColor: const Color(0xFF00C9C8),
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: labels.map((l) => Tab(text: l)).toList(),
      ),
    ).animate().fadeIn(delay: 120.ms);
  }
}

// ── CONNECTOR GRID ─────────────────────────────────────────────────────────────

class _ConnectorGrid extends StatelessWidget {
  final Future<void> Function(ConnectorDef) onConnect;
  const _ConnectorGrid({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceService>(
      builder: (ctx, svc, _) {
        if (svc.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00C9C8)),
          );
        }
        if (svc.error != null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(svc.error!, style: const TextStyle(color: Colors.white38)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => svc.loadCatalog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00C9C8).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Retry', style: TextStyle(color: Color(0xFF00C9C8))),
                ),
              ),
            ]),
          );
        }
        if (svc.catalog.isEmpty) {
          return const Center(
            child: Text('No connectors found', style: TextStyle(color: Colors.white38)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: svc.catalog.length,
          itemBuilder: (ctx, i) {
            final c = svc.catalog[i];
            final status = svc.authStatusFor(c.id);
            return _ConnectorCard(
              connector: c,
              authStatus: status,
              index: i,
              onTap: () => onConnect(c),
            );
          },
        );
      },
    );
  }
}

// ── CONNECTOR CARD ────────────────────────────────────────────────────────────

class _ConnectorCard extends StatelessWidget {
  final ConnectorDef connector;
  final String authStatus;
  final int index;
  final VoidCallback onTap;

  const _ConnectorCard({
    required this.connector,
    required this.authStatus,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = authStatus == 'connected';
    final isTosRisk = connector.tosRisk;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        decoration: BoxDecoration(
          color: isConnected
              ? const Color(0xFF00C9C8).withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected
                ? const Color(0xFF00C9C8).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
            width: 1.2,
          ),
          boxShadow: isConnected
              ? [BoxShadow(
                  color: const Color(0xFF00C9C8).withValues(alpha: 0.12),
                  blurRadius: 20, spreadRadius: -4)]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isConnected
                        ? [const Color(0xFF00C9C8), const Color(0xFF007070)]
                        : [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.06)],
                  ),
                ),
                child: connector.iconAsset != null
                    ? ClipOval(child: Image.network(connector.iconAsset!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackIcon(isConnected)))
                    : _fallbackIcon(isConnected),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF00C9C8).withValues(alpha: 0.15)
                      : isTosRisk
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConnected ? '✓ On' : isTosRisk ? '⚠️ Limited' : '+ Add',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isConnected
                        ? const Color(0xFF00C9C8)
                        : isTosRisk ? Colors.orange : Colors.white54,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Text(connector.displayName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Text(connector.description,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5, height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const Spacer(),
            // Feasibility pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _feasibilityColor(connector.feasibility).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _feasibilityLabel(connector.feasibility),
                style: TextStyle(
                  fontSize: 10,
                  color: _feasibilityColor(connector.feasibility),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 30).ms, duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _fallbackIcon(bool connected) {
    return Icon(
      _categoryIcon(connector.category),
      size: 22,
      color: connected ? Colors.white : Colors.white38,
    );
  }

  Color _feasibilityColor(FeasibilityTier tier) {
    switch (tier) {
      case FeasibilityTier.selfServe: return const Color(0xFF00C9C8);
      case FeasibilityTier.selfServeLimited: return const Color(0xFF3B82F6);
      case FeasibilityTier.inviteGated: return const Color(0xFFF59E0B);
      case FeasibilityTier.partnershipOnly: return Colors.orange;
      case FeasibilityTier.accessibilityOnly: return Colors.white38;
    }
  }

  String _feasibilityLabel(FeasibilityTier tier) {
    switch (tier) {
      case FeasibilityTier.selfServe: return 'Free API';
      case FeasibilityTier.selfServeLimited: return 'Free (limited)';
      case FeasibilityTier.inviteGated: return 'Apply for access';
      case FeasibilityTier.partnershipOnly: return 'Business only';
      case FeasibilityTier.accessibilityOnly: return 'Screen automation';
    }
  }

  IconData _categoryIcon(ConnectorCategory cat) {
    switch (cat) {
      case ConnectorCategory.communication: return Icons.chat_bubble_rounded;
      case ConnectorCategory.social: return Icons.people_rounded;
      case ConnectorCategory.productivity: return Icons.check_circle_rounded;
      case ConnectorCategory.design: return Icons.brush_rounded;
      case ConnectorCategory.developer: return Icons.code_rounded;
      case ConnectorCategory.ai: return Icons.auto_awesome_rounded;
      case ConnectorCategory.entertainment: return Icons.play_circle_rounded;
      case ConnectorCategory.shopping: return Icons.shopping_bag_rounded;
      case ConnectorCategory.foodDelivery: return Icons.fastfood_rounded;
      case ConnectorCategory.finance: return Icons.account_balance_wallet_rounded;
      case ConnectorCategory.travel: return Icons.directions_car_rounded;
      case ConnectorCategory.health: return Icons.favorite_rounded;
      case ConnectorCategory.smartHome: return Icons.home_rounded;
      case ConnectorCategory.utilities: return Icons.build_rounded;
      default: return Icons.extension_rounded;
    }
  }
}

// ── CONFIRM DIALOG ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final bool isDanger;
  const _ConfirmDialog({
    required this.title, required this.body,
    required this.confirmLabel, this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: Text(body, style: const TextStyle(color: Colors.white60, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: isDanger ? Colors.redAccent : const Color(0xFF00C9C8),
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
