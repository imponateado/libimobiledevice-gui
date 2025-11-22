import 'package:flutter/material.dart';
import 'package:imobilegui/services/device_service.dart';

class BackupScreen extends StatefulWidget {
  final String udid;

  const BackupScreen({super.key, required this.udid});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final DeviceService _deviceService = DeviceService();
  final List<String> _backupLog = [];
  Stream<String>? _backupStream;
  bool _isBackingUp = false;

  Future<void> _startBackup() async {
    final TextEditingController controller = TextEditingController();
    final backupPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Backup Path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., /home/user/backups'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Start Backup'),
          ),
        ],
      ),
    );

    if (backupPath != null && backupPath.isNotEmpty) {
      setState(() {
        _isBackingUp = true;
        _backupLog.clear();
        _backupStream = _deviceService.backupDevice(widget.udid, backupPath);
      });
    }
  }

  void _stopBackup() {
    _deviceService.stopBackup();
    setState(() {
      _isBackingUp = false;
    });
  }

  @override
  void dispose() {
    _deviceService.stopBackup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Device'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isBackingUp ? null : _startBackup,
                  child: const Text('Start Backup'),
                ),
                ElevatedButton(
                  onPressed: _isBackingUp ? _stopBackup : null,
                  child: const Text('Stop Backup'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<String>(
              stream: _backupStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _backupLog.add('Error: ${snapshot.error}');
                }
                if (snapshot.hasData) {
                  _backupLog.addAll(snapshot.data!.split('\n').where((line) => line.isNotEmpty));
                }
                return ListView.builder(
                  itemCount: _backupLog.length,
                  itemBuilder: (context, index) {
                    return Text(_backupLog[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
