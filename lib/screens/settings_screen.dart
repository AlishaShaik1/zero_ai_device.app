import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/download_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DownloadService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('AI Models', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 10),
          ...ds.items.map((m) => _buildModelTile(context, m)).toList(),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C9C8).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF00C9C8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => ds.downloadAll(),
            child: const Text('Download All'),
          ),
          const Divider(height: 40, color: Colors.white24),
          Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
          SwitchListTile(
            title: Text('Wake Word', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
            value: true,
            onChanged: (val) {},
            activeColor: const Color(0xFF00C9C8),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTile(BuildContext context, ModelDownloadItem model) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        title: Text(model.displayName, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
        subtitle: model.status == DownloadStatus.downloading
            ? LinearProgressIndicator(value: model.progress, color: const Color(0xFF00C9C8), backgroundColor: Colors.white12)
            : Text(model.status == DownloadStatus.completed ? 'Ready' : 'Not Downloaded', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        trailing: model.status == DownloadStatus.completed
            ? const Icon(Icons.check_circle, color: Color(0xFF34D399))
            : model.status == DownloadStatus.downloading
                ? Text('${(model.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF00C9C8)))
                : Icon(Icons.cloud_download, color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }
}
