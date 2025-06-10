import 'package:flutter/material.dart';
import 'package:minesweeper_duo/screens/main_game.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          spacing: 12.0,
          children: [
            Spacer(),
            const Text('Minesweeper Duo', style: TextStyle(fontSize: 46.0)),
            SizedBox.square(dimension: 16.0),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainGame()),
                );
              },
              child: Text('Join Game', style: TextStyle(fontSize: 24.0)),
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text('Host Game', style: TextStyle(fontSize: 24.0)),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
