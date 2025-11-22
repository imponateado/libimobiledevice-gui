import 'dart:io';

import 'package:flutter/material.dart';
import 'package:imobilegui/models/device_details.dart';
import 'package:imobilegui/screens/backup_screen.dart';
import 'package:imobilegui/screens/category_screen.dart';
import 'package:imobilegui/screens/diagnostics_screen.dart';
import 'package:imobilegui/screens/pairing_screen.dart';
import 'package:imobilegui/screens/syslog_screen.dart';
import 'package:imobilegui/services/device_service.dart';
import 'package:intl/intl.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final String udid;

  const DeviceDetailsScreen({super.key, required this.udid});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final DeviceService _deviceService = DeviceService();
  Future<DeviceDetails>? _deviceDetailsFuture;
  bool _isTakingScreenshot = false;

  @override
  void initState() {
    super.initState();
    _deviceDetailsFuture = _deviceService.getDeviceDetails(widget.udid);
  }

  Future<void> _takeScreenshot() async {
    setState(() {
      _isTakingScreenshot = true;
    });
    try {
      final imagePath = await _deviceService.takeScreenshot(widget.udid);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Screenshot'),
            content: Image.file(File(imagePath)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking screenshot: $e')),
        );
      }
    } finally {
      setState(() {
        _isTakingScreenshot = false;
      });
    }
  }

  Future<void> _showEditDeviceNameDialog(String currentName) async {
    final TextEditingController controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        await _deviceService.setDeviceName(widget.udid, newName);
        setState(() {
          _deviceDetailsFuture = _deviceService.getDeviceDetails(widget.udid);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error setting device name: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditDeviceDateDialog(DateTime currentDate) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (newDate != null) {
      final newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDate),
      );

      if (newTime != null) {
        final newDateTime = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          newTime.hour,
          newTime.minute,
        );
        try {
          await _deviceService.setDeviceDate(widget.udid, newDateTime);
          setState(() {
            _deviceDetailsFuture = _deviceService.getDeviceDetails(widget.udid);
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error setting device date: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _showEnterRecoveryModeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Recovery Mode'),
        content: const Text('Are you sure you want to put this device into recovery mode? This action is not easily reversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deviceService.enterRecoveryMode(widget.udid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error entering recovery mode: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
      ),
      body: FutureBuilder<DeviceDetails>(
        future: _deviceDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final deviceDetails = snapshot.data!;
            final properties = deviceDetails.deviceInfo.properties;
            final sortedKeys = properties.keys.toList()..sort();

            final categories = [
              Category(
                name: 'General',
                icon: Icons.info_outline,
                children: [
                  ListTile(
                    title: const Text('Device Name'),
                    subtitle: Text(deviceDetails.deviceName),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDeviceNameDialog(deviceDetails.deviceName),
                    ),
                  ),
                  ListTile(
                    title: const Text('Device Date'),
                    subtitle: Text(DateFormat.yMd().add_jms().format(deviceDetails.deviceDate.toLocal())),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDeviceDateDialog(deviceDetails.deviceDate),
                    ),
                  ),
                ],
              ),
              Category(
                name: 'Actions',
                icon: Icons.play_circle_outline,
                children: [
                  ListTile(
                    title: const Text('System Log'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SyslogScreen(udid: widget.udid),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Backup'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BackupScreen(udid: widget.udid),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Pairing'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PairingScreen(udid: widget.udid),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Enter Recovery Mode'),
                    trailing: const Icon(Icons.warning, color: Colors.red),
                    onTap: _showEnterRecoveryModeDialog,
                  ),
                ],
              ),
              Category(
                name: 'Diagnostics',
                icon: Icons.healing,
                children: [
                  ListTile(
                    title: const Text('Run Diagnostics'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiagnosticsScreen(udid: widget.udid),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Category(
                name: 'Device Properties',
                icon: Icons.list,
                children: sortedKeys.map((key) {
                  final value = properties[key];
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(value ?? ''),
                  );
                }).toList(),
              ),
            ];

            return GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
                            title: category.name,
                            children: category.children,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(category.icon, size: 48.0),
                        const SizedBox(height: 8.0),
                        Text(category.name, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text('No information available.'));
          }
        },
      ),
      floatingActionButton: _isTakingScreenshot
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : FloatingActionButton(
              onPressed: _takeScreenshot,
              child: const Icon(Icons.camera_alt),
            ),
    );
  }
}

class Category {
  final String name;
  final IconData icon;
  final List<Widget> children;

  Category({required this.name, required this.icon, required this.children});
}