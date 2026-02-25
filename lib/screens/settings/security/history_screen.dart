import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:crypto_sync/providers/sync_provider.dart';
import 'package:crypto_sync/theme/app_colors.dart';
import 'package:crypto_sync/widgets/common_widgets.dart';
import 'package:crypto_sync/core/api_config.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final userId = context.read<SyncProvider>().lastUserId;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/logs/$userId'));
      if (response.statusCode == 200) {
        setState(() {
          _logs = jsonDecode(response.body)['logs'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login History')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              return _HistoryTile(
                status: log['status'],
                device: log['device_name'],
                ip: log['ip_address'],
                time: log['timestamp'],
              );
            },
          ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String status;
  final String device;
  final String ip;
  final String time;

  const _HistoryTile({
    required this.status,
    required this.device,
    required this.ip,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == 'success';
    final parsedTime = DateTime.parse(time);
    final formattedTime = DateFormat('MMM d, HH:mm').format(parsedTime);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isSuccess ? Icons.check_circle_outline : Icons.error_outline,
          color: isSuccess ? AppColors.success : AppColors.danger,
        ),
        title: Text(device, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('$ip • $formattedTime', style: const TextStyle(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isSuccess ? AppColors.success : AppColors.danger).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSuccess ? AppColors.success : AppColors.danger,
            ),
          ),
        ),
      ),
    );
  }
}

