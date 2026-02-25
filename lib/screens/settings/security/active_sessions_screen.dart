import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/core/api_config.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  bool _isLoading = true;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    final userId = context.read<SyncProvider>().lastUserId;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/sessions/$userId'));
      if (response.statusCode == 200) {
        setState(() {
          _sessions = jsonDecode(response.body)['sessions'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _terminateSession(String sessionId) async {
    try {
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/auth/sessions/logout?session_id=$sessionId'));
      if (response.statusCode == 200) {
        _fetchSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session terminated')),
          );
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Sessions')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final sess = _sessions[index];
              return _SessionTile(
                device: sess['device_name'],
                ip: sess['ip_address'],
                time: sess['login_time'],
                onTerminate: () => _terminateSession(sess['id']),
              );
            },
          ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String device;
  final String ip;
  final String time;
  final VoidCallback onTerminate;

  const _SessionTile({
    required this.device,
    required this.ip,
    required this.time,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    final parsedTime = DateTime.parse(time);
    final formattedTime = DateFormat('MMM d, HH:mm').format(parsedTime);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.devices, color: AppColors.primary),
        title: Text(device, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$ip • $formattedTime', style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.logout_outlined, color: AppColors.danger),
          onPressed: onTerminate,
          tooltip: 'Revoke Access',
        ),
      ),
    );
  }
}

