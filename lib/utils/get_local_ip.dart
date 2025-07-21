import 'dart:io';
// import 'package:network_info_plus/network_info_plus.dart';

Future<String> getLocalIp() async {
  // final info = NetworkInfo();
  // final ip = await info.getWifiIP();
  var ip = '';
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: false,
  );
  for (var interface in interfaces) {
    for (var address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4) {
        ip = address.address;
      }
    }
  }
  print("!!!!! Local IP: ${ip}");
  return ip;
}

