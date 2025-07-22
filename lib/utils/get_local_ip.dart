import 'dart:io';

Future<String> getLocalIp() async {
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
