import 'package:flutter/material.dart';
import 'package:minesweeper_duo/screens/main_game.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text('Minesweeper Duo'),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainGame()),
                );
              },
              child: Text('Play'),
            ),
            ElevatedButton(onPressed: () {}, child: Text('Options')),
          ],
        ),
      ),
    );
  }
}
