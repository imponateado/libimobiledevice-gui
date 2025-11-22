import 'package:flutter/material.dart';
import 'package:imobilegui/services/device_service.dart';

class SyslogScreen extends StatefulWidget {
  final String udid;

  const SyslogScreen({super.key, required this.udid});

  @override
  State<SyslogScreen> createState() => _SyslogScreenState();
}

class _SyslogScreenState extends State<SyslogScreen> {
  final DeviceService _deviceService = DeviceService();
  final List<String> _logMessages = [];
  Stream<String>? _syslogStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syslogStream = _deviceService.startSyslogListener(widget.udid);
  }

  @override
  void dispose() {
    _deviceService.stopSyslogListener();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Log'),
      ),
      body: StreamBuilder<String>(
        stream: _syslogStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            final newMessages = snapshot.data!.split('\n').where((line) => line.isNotEmpty);
            if (newMessages.isNotEmpty) {
              _logMessages.addAll(newMessages);
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          }
          return ListView.builder(
            controller: _scrollController,
            itemCount: _logMessages.length,
            itemBuilder: (context, index) {
              return Text(_logMessages[index]);
            },
          );
        },
      ),
    );
  }
}
