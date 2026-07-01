import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../automation/connector_catalog.dart';
import '../automation/models/connector_def.dart';

class ConnectorsScreen extends StatefulWidget {
  const ConnectorsScreen({Key? key}) : super(key: key);

  @override
  State<ConnectorsScreen> createState() => _ConnectorsScreenState();
}

class _ConnectorsScreenState extends State<ConnectorsScreen> {
  String _searchQuery = '';
  ConnectorCategory? _selectedCategory;

  List<ConnectorDef> get _filteredConnectors {
    return ConnectorCatalog.defaultConnectors.where((c) {
      final matchesSearch = c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            c.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || c.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            _buildCategoryFilter(),
            Expanded(
              child: _buildConnectorGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketplace',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Add skills and tools to Zero',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search connectors...',
            hintStyle: TextStyle(color: Colors.white30),
            prefixIcon: Icon(Icons.search, color: Colors.white54),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ConnectorCategory.values.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilterChip('All', null);
          }
          final category = ConnectorCategory.values[index - 1];
          final label = category.name[0].toUpperCase() + category.name.substring(1);
          return _buildFilterChip(label, category);
        },
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildFilterChip(String label, ConnectorCategory? category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = category);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C9C8).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C9C8) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00C9C8) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredConnectors.length,
      itemBuilder: (context, index) {
        final c = _filteredConnectors[index];
        return _buildConnectorCard(c, index);
      },
    );
  }

  Widget _buildConnectorCard(ConnectorDef connector, int index) {
    bool isConnected = connector.authStatus == AuthStatus.connected;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          if (isConnected)
            BoxShadow(
              color: const Color(0xFF00C9C8).withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected 
                    ? [const Color(0xFF00C9C8), const Color(0xFF008080)]
                    : [Colors.white12, Colors.white10],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconForCategory(connector.category),
              color: isConnected ? Colors.white : Colors.white54,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            connector.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              connector.description,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isConnected 
                  ? const Color(0xFF00C9C8).withValues(alpha: 0.2) 
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isConnected ? 'Connected' : 'Connect',
              style: TextStyle(
                color: isConnected ? const Color(0xFF00C9C8) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
  }

  IconData _getIconForCategory(ConnectorCategory cat) {
    switch(cat) {
      case ConnectorCategory.communication: return Icons.chat_bubble_rounded;
      case ConnectorCategory.social: return Icons.people_rounded;
      case ConnectorCategory.productivity: return Icons.check_circle_rounded;
      case ConnectorCategory.design: return Icons.brush_rounded;
      case ConnectorCategory.utilities: return Icons.build_rounded;
      case ConnectorCategory.foodDelivery: return Icons.fastfood_rounded;
      default: return Icons.extension_rounded;
    }
  }
}
