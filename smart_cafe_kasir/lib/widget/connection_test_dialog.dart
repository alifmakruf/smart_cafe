import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ConnectionTestDialog extends StatefulWidget {
  final String baseUrl;

  const ConnectionTestDialog({
    Key? key,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<ConnectionTestDialog> createState() => _ConnectionTestDialogState();
}

class _ConnectionTestDialogState extends State<ConnectionTestDialog> {
  bool _isTesting = false;
  String _status = 'Ready to test';
  Color _statusColor = Colors.grey;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  Future<void> _startTest() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing connection...';
      _statusColor = Colors.orange;
      _logs.clear();
    });

    try {
      // Test 1: Ping base URL
      _addLog('🔍 Testing: ${widget.baseUrl}');

      final testUrls = [
        '${widget.baseUrl}/menus',
        '${widget.baseUrl.replaceAll('/v1', '')}/auth/login',
        widget.baseUrl,
      ];

      for (var url in testUrls) {
        _addLog('Testing endpoint: $url');

        try {
          final startTime = DateTime.now();
          final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Timeout after 5 seconds');
            },
          );

          final duration = DateTime.now().difference(startTime);

          _addLog('✓ Response: ${response.statusCode} (${duration.inMilliseconds}ms)');

          if (response.statusCode == 200) {
            setState(() {
              _status = 'Connection successful! ✓';
              _statusColor = Colors.green;
            });
            _addLog('✅ Connection OK!');
            break;
          }
        } catch (e) {
          _addLog('❌ Failed: $e');
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (_statusColor != Colors.green) {
        setState(() {
          _status = 'Connection failed ✗';
          _statusColor = Colors.red;
        });
        _addLog('❌ All endpoints failed');
      }

    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _statusColor = Colors.red;
      });
      _addLog('❌ Test error: $e');
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isTesting
                ? Icons.network_check
                : (_statusColor == Colors.green ? Icons.check_circle : Icons.error),
            color: _statusColor,
          ),
          const SizedBox(width: 12),
          const Text('Connection Test'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  if (_isTesting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _statusColor == Colors.green ? Icons.check : Icons.close,
                      size: 16,
                      color: _statusColor,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logs
            const Text(
              'Logs:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!_isTesting)
          ElevatedButton.icon(
            onPressed: _startTest,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D4C41),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}