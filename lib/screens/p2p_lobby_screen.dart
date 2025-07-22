// ignore_for_file: library_private_types_in_public_api
import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/minesweeper.dart';
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

  // Define retro-style colors
  static const Color retroGreen = Color(0xFF6B8E23); // Olive Green
  static const Color retroDarkGreen = Color(0xFF35441C); // Darker Green
  static const Color retroBrown = Color(0xFF8B4513); // Saddle Brown
  static const Color retroLightGray = Color(0xFFD3D3D3); // Light Gray
  static const Color retroDarkGray = Color(0xFF36454F); // Charcoal Gray
  static const Color retroBlue = Color(0xFF00008B); // Dark Blue

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    final ip = await getLocalIp();
    setState(() => localIp = ip);
  }

  TextStyle _retroTextStyle({
    double fontSize = 20,
    Color color = Colors.white,
  }) {
    return TextStyle(
      fontFamily: 'PixelFont',
      fontSize: fontSize,
      color: color,
      shadows: const [
        Shadow(
          offset: Offset(2.0, 2.0),
          blurRadius: 3.0,
          color: Colors.black54,
        ),
      ],
    );
  }

  ButtonStyle _retroButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: retroGreen, // Green button background
      foregroundColor: Colors.white, // White text
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Slightly rounded corners
        side: const BorderSide(
          color: retroDarkGreen,
          width: 3.0,
        ), // Darker border
      ),
      textStyle: _retroTextStyle(fontSize: 18),
      elevation: 5,
    );
  }

  InputDecoration _retroInputDecoration(String labelText, String hintText) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: _retroTextStyle(fontSize: 16, color: retroLightGray),
      hintStyle: _retroTextStyle(
        fontSize: 16,
        color: retroLightGray.withOpacity(0.7),
      ),
      filled: true,
      fillColor: retroDarkGray.withOpacity(
        0.7,
      ), // Semi-transparent dark gray fill
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: retroGreen, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.cyanAccent,
          width: 3.0,
        ), // Brighter focus
        borderRadius: BorderRadius.circular(8.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          retroDarkGreen, // Darker green background for the entire screen
      appBar: AppBar(
        title: Text(
          'MINESWEEPER DUO',
          style: _retroTextStyle(
            fontSize: 24,
            color: Colors.cyanAccent,
          ), // Brighter title
        ),
        centerTitle: true,
        backgroundColor: retroBrown, // Brown app bar for a distinct header
        elevation: 10,
      ),
      body: SingleChildScrollView(
        // Allow scrolling if content is too long
        padding: const EdgeInsets.all(24.0), // More padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Stretch cards horizontally
          children: [
            // Local Game Card
            _buildRetroCard(
              title: 'LOCAL GAME',
              children: [
                ElevatedButton(
                  onPressed: () {
                    final game =
                        Minesweeper(); // Assuming Minesweeper is your local game class
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameWidget(game: game),
                      ),
                    );
                  },
                  style: _retroButtonStyle(),
                  child: const Text('PLAY LOCALLY'),
                ),
              ],
            ),
            const SizedBox(height: 24), // Increased spacing
            // Host Game Card
            _buildRetroCard(
              title: 'HOST GAME',
              children: [
                if (localIp != null)
                  Text(
                    'YOUR IP: $localIp',
                    style: _retroTextStyle(fontSize: 16, color: retroLightGray),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final gameInstance = MinesweeperGame(
                      isHost: true,
                      localIp: InternetAddress.tryParse(localIp!),
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => _gameBuilder(context, gameInstance),
                      ),
                    );
                  },
                  style: _retroButtonStyle(),
                  child: const Text('START AS HOST'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Join Game Card
            _buildRetroCard(
              title: 'JOIN GAME',
              children: [
                TextField(
                  controller: ipController,
                  keyboardType: TextInputType.text,
                  style: _retroTextStyle(fontSize: 16),
                  decoration: _retroInputDecoration(
                    'HOST IP ADDRESS',
                    '192.168.1.100',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: portController,
                  keyboardType: TextInputType.number,
                  style: _retroTextStyle(fontSize: 16),
                  decoration: _retroInputDecoration('HOSTING PORT', '3000'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final gameInstance = MinesweeperGame(
                      isHost: false,
                      localIp: InternetAddress.tryParse(ipController.text),
                      port: Port(
                        int.parse(
                          portController.text.isNotEmpty
                              ? portController.text
                              : '3000',
                        ),
                      ),
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => _gameBuilder(context, gameInstance),
                      ),
                    );
                  },
                  style: _retroButtonStyle(),
                  child: const Text('JOIN GAME'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameBuilder(context, gameInstance) {
    final widget = Scaffold(
      appBar: AppBar(
        title: Text(
          'MINESWEEPER GAME',
          style: _retroTextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: retroBrown,
      ),
      body: Center(
        child: Container(
          width: MinesweeperGame.gridSize * MinesweeperGame.cellSize,
          height: MinesweeperGame.gridSize * MinesweeperGame.cellSize + 50,
          color: retroDarkGreen,
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              gameInstance.handleTap(details.localPosition);
            },
            // onLongPressStart: (LongPressStartDetails details) {
            //   gameInstance.handleFlagAction(details.localPosition);
            // },
            onLongPressEnd: (LongPressEndDetails details) {
              gameInstance.handleFlagAction(details.localPosition);
            },
            onSecondaryTapDown: (TapDownDetails details) {
              gameInstance.handleFlagAction(details.localPosition);
            },
            onDoubleTapDown: (TapDownDetails details) {
              gameInstance.handleFlagAction(details.localPosition);
            },
            child: GameWidget(
              game: gameInstance,
              mouseCursor: SystemMouseCursors.basic,
            ),
          ),
        ),
      ),
    );
    return widget;
  }

  // Helper widget to build consistent retro cards
  Widget _buildRetroCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 8,
      color: retroDarkGray, // Dark gray background for cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(
          color: retroGreen,
          width: 3.0,
        ), // Green border for cards
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          children: [
            Text(
              title,
              style: _retroTextStyle(
                fontSize: 22,
                color: Colors.cyanAccent,
              ), // Brighter titles
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...children, // Spread the children widgets
          ],
        ),
      ),
    );
  }
}
