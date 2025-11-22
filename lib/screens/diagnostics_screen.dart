import 'package:flutter/material.dart';
import 'package:imobilegui/services/device_service.dart';

class DiagnosticsScreen extends StatelessWidget {
  final String udid;

  const DiagnosticsScreen({super.key, required this.udid});

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
      ),
      body: FutureBuilder<String>(
        future: deviceService.runDiagnostics(udid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(snapshot.data!),
              ),
            );
          } else {
            return const Center(child: Text('No diagnostics information available.'));
          }
        },
      ),
    );
  }
}
