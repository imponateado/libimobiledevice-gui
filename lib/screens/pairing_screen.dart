import 'package:flutter/material.dart';
import 'package:imobilegui/services/device_service.dart';

class PairingScreen extends StatefulWidget {
  final String udid;

  const PairingScreen({super.key, required this.udid});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final DeviceService _deviceService = DeviceService();
  late Future<bool> _isPairedFuture;

  @override
  void initState() {
    super.initState();
    _isPairedFuture = _deviceService.isPaired(widget.udid);
  }

  Future<void> _pair() async {
    try {
      await _deviceService.pair(widget.udid);
      setState(() {
        _isPairedFuture = _deviceService.isPaired(widget.udid);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pairing: $e')),
        );
      }
    }
  }

  Future<void> _unpair() async {
    try {
      await _deviceService.unpair(widget.udid);
      setState(() {
        _isPairedFuture = _deviceService.isPaired(widget.udid);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unpairing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing'),
      ),
      body: FutureBuilder<bool>(
        future: _isPairedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final isPaired = snapshot.data!;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isPaired ? 'Device is Paired' : 'Device is not Paired'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: isPaired ? null : _pair,
                        child: const Text('Pair'),
                      ),
                      ElevatedButton(
                        onPressed: isPaired ? _unpair : null,
                        child: const Text('Unpair'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text('Could not get pairing status.'));
          }
        },
      ),
    );
  }
}
