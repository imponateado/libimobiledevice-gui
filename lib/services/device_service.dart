import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:imobilegui/models/device_details.dart';
import 'package:path/path.dart' as path;
import 'package:imobilegui/models/device.dart';
import 'package:imobilegui/models/device_info.dart';

class DeviceService {
  Process? _syslogProcess;
  Process? _backupProcess;

  Future<List<Device>> getConnectedDevices() async {
    try {
      final result = await Process.run('idevice_id', ['-l']);
      if (result.exitCode == 0) {
        final udids = (result.stdout as String)
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toList();
        
        final devices = await Future.wait(udids.map((udid) async {
          final name = await getDeviceName(udid);
          return Device(udid: udid, name: name);
        }));

        return devices;
      } else {
        // Handle error
        print('Error getting connected devices: ${result.stderr}');
        return [];
      }
    } catch (e) {
      // Handle error
      print('Error getting connected devices: $e');
      return [];
    }
  }

  Future<DeviceInfo> getDeviceInfo(String udid) async {
    try {
      final result = await Process.run('ideviceinfo', ['-u', udid]);
      if (result.exitCode == 0) {
        final properties = <String, String>{};
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          final parts = line.split(':');
          if (parts.length == 2) {
            properties[parts[0].trim()] = parts[1].trim();
          }
        }
        return DeviceInfo(properties: properties);
      } else {
        throw Exception('Error getting device info: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Error getting device info: $e');
    }
  }

  Future<DeviceDetails> getDeviceDetails(String udid) async {
    try {
      final results = await Future.wait([
        getDeviceInfo(udid),
        getDeviceName(udid),
        getDeviceDate(udid),
      ]);
      return DeviceDetails(
        deviceInfo: results[0] as DeviceInfo,
        deviceName: results[1] as String,
        deviceDate: results[2] as DateTime,
      );
    } catch (e) {
      throw Exception('Error getting device details: $e');
    }
  }

  Future<String> takeScreenshot(String udid) async {
    try {
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
      final result = await Process.run('idevicescreenshot', ['-u', udid, filePath]);
      if (result.exitCode == 0) {
        return filePath;
      } else {
        throw Exception('Error taking screenshot: ${result.stderr}');
      }
    }
    catch (e) {
      throw Exception('Error taking screenshot: $e');
    }
  }

  Future<String> getDeviceName(String udid) async {
    try {
      final result = await Process.run('idevicename', ['-u', udid]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      } else {
        throw Exception('Error getting device name: ${result.stderr}');
      }
    }
    catch (e) {
      throw Exception('Error getting device name: $e');
    }
  }

  Future<bool> setDeviceName(String udid, String newName) async {
    try {
      final result = await Process.run('idevicename', ['-u', udid, newName]);
      return result.exitCode == 0;
    }
    catch (e) {
      throw Exception('Error setting device name: $e');
    }
  }

  Future<DateTime> getDeviceDate(String udid) async {
    try {
      final result = await Process.run('idevicedate', ['-u', udid]);
      if (result.exitCode == 0) {
        final dateString = result.stdout as String;
        // Example: Fri Nov 21 14:00:00 UTC 2025
        final parts = dateString.split(' ');
        final month = _monthNumber(parts[1]);
        final day = int.parse(parts[2]);
        final timeParts = parts[3].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = int.parse(timeParts[2]);
        final year = int.parse(parts[5]);
        return DateTime.utc(year, month, day, hour, minute, second);
      } else {
        throw Exception('Error getting device date: ${result.stderr}');
      }
    }
    catch (e) {
      throw Exception('Error getting device date: $e');
    }
  }

  Future<bool> setDeviceDate(String udid, DateTime newDate) async {
    try {
      final timestamp = (newDate.toUtc().millisecondsSinceEpoch / 1000).round().toString();
      final result = await Process.run('idevicedate', ['-u', udid, timestamp]);
      return result.exitCode == 0;
    }
    catch (e) {
      throw Exception('Error setting device date: $e');
    }
  }

  Stream<String> startSyslogListener(String udid) {
    final controller = StreamController<String>();
    Process.start('idevicesyslog', ['-u', udid]).then((process) {
      _syslogProcess = process;
      process.stdout.transform(utf8.decoder).listen((data) {
        controller.add(data);
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        controller.addError(data);
      });
    }).catchError((e) {
      controller.addError(e);
    });
    return controller.stream;
  }

  void stopSyslogListener() {
    _syslogProcess?.kill();
    _syslogProcess = null;
  }

  Stream<String> backupDevice(String udid, String backupPath) {
    final controller = StreamController<String>();
    Process.start('idevicebackup2', ['-u', udid, 'backup', '--full', backupPath]).then((process) {
      _backupProcess = process;
      process.stdout.transform(utf8.decoder).listen((data) {
        controller.add(data);
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        controller.add(data);
      });
      process.exitCode.then((exitCode) {
        if (exitCode != 0) {
          controller.addError('Backup failed with exit code $exitCode');
        }
        controller.close();
      });
    }).catchError((e) {
      controller.addError(e);
    });
    return controller.stream;
  }

  void stopBackup() {
    _backupProcess?.kill();
    _backupProcess = null;
  }

  Future<bool> enterRecoveryMode(String udid) async {
    try {
      final result = await Process.run('ideviceenterrecovery', [udid]);
      return result.exitCode == 0;
    } catch (e) {
      throw Exception('Error entering recovery mode: $e');
    }
  }

  Future<bool> isPaired(String udid) async {
    try {
      final result = await Process.run('idevicepair', ['-u', udid, 'validate']);
      return result.stdout.toString().contains('SUCCESS');
    } catch (e) {
      throw Exception('Error validating pairing: $e');
    }
  }

  Future<bool> pair(String udid) async {
    try {
      final result = await Process.run('idevicepair', ['-u', udid, 'pair']);
      return result.exitCode == 0;
    } catch (e) {
      throw Exception('Error pairing device: $e');
    }
  }

  Future<bool> unpair(String udid) async {
    try {
      final result = await Process.run('idevicepair', ['-u', udid, 'unpair']);
      return result.exitCode == 0;
    } catch (e) {
      throw Exception('Error unpairing device: $e');
    }
  }

  Future<String> runDiagnostics(String udid) async {
    try {
      final result = await Process.run('idevicediagnostics', ['-u', udid]);
      if (result.exitCode == 0) {
        return result.stdout as String;
      } else {
        throw Exception('Error running diagnostics: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Error running diagnostics: $e');
    }
  }

  int _monthNumber(String month) {
    switch (month) {
      case 'Jan': return 1;
      case 'Feb': return 2;
      case 'Mar': return 3;
      case 'Apr': return 4;
      case 'May': return 5;
      case 'Jun': return 6;
      case 'Jul': return 7;
      case 'Aug': return 8;
      case 'Sep': return 9;
      case 'Oct': return 10;
      case 'Nov': return 11;
      case 'Dec': return 12;
      default: return 1;
    }
  }
}
