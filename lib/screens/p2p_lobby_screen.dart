// ignore_for_file: library_private_types_in_public_api

import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/minesweeper.dart';
// import 'package:network_info_plus/network_info_plus.dart';
import 'package:udp/udp.dart';
import '../duo_udp_ms.dart';
import 'package:minesweeper_duo/utils/get_local_ip.dart';

class P2PLobbyScreen extends StatefulWidget {
  const P2PLobbyScreen({super.key});

  @override
  _P2PLobbyScreenState createState() => _P2PLobbyScreenState();
}

class _P2PLobbyScreenState extends State<P2PLobbyScreen> {
  final ipController = TextEditingController();
  final portController = TextEditingController();
  final gameIdController = TextEditingController();
  String? localIp;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    final ip = await getLocalIp();
    setState(() => localIp = ip);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Minesweeper')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Local Game', style: TextStyle(fontSize: 20)),
                    ElevatedButton(
                      onPressed: () {
                        final game = Minesweeper();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameWidget(game: game),
                          ),
                        );
                      },
                      child: const Text('Play locally'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Host Game', style: TextStyle(fontSize: 20)),
                    if (localIp != null) Text('Your IP: $localIp'),
                    TextField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: 'Hosting port',
                        hintText: '3000',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => GameWidget(
                                  game: MinesweeperGame(
                                    isHost: true,
                                    localIp: InternetAddress.tryParse(localIp!),
                                    port: Port(
                                      int.parse(
                                        portController.text.isNotEmpty
                                            ? portController.text
                                            : '3000',
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        );
                      },
                      child: const Text('Start as Host'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Join Game', style: TextStyle(fontSize: 20)),
                    TextField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'Host IP Address',
                      ),
                    ),
                    TextField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: 'Hosting port',
                        hintText: '3000',
                      ),
                    ),
                    TextField(
                      controller: gameIdController,
                      decoration: const InputDecoration(
                        labelText: 'Game ID (if required)',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => GameWidget(
                                  game: MinesweeperGame(
                                    isHost: false,
                                    localIp: InternetAddress.tryParse(localIp!),
                                    port: Port(
                                      int.parse(
                                        portController.text.isNotEmpty
                                            ? portController.text
                                            : '3000',
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        );
                      },
                      child: const Text('Join Game'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
