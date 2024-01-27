import 'package:flutter/material.dart';
import 'main.dart';

class OverlayMenu extends StatelessWidget {
  final MyGame myGame;

  const OverlayMenu({super.key, required this.myGame});

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center, child: ElevatedButton(
      onPressed: myGame.play,
      child: const Icon(Icons.play_arrow, color: Colors.green, size: 100),
    ));
  }
}

class OverlayGame extends StatelessWidget {
  final MyGame myGame;

  const OverlayGame({super.key, required this.myGame});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(30), child: Row(
      children: <Widget>[
        ElevatedButton(
          onPressed: myGame.restart,
          child: const Icon(Icons.replay, color: Colors.green, size: 50),
        ),
        const SizedBox(width: 30),
        ElevatedButton(
          onPressed: myGame.zoom,
          child: const Icon(Icons.zoom_out, color: Colors.green, size: 50),
        ),
        const SizedBox(width: 30),
        ElevatedButton(
          onPressed: myGame.undo,
          child: const Icon(Icons.undo, color: Colors.green, size: 50),
        ),
      ],
    ));
  }
}

class OverlayZoom extends StatelessWidget {
  final MyGame myGame;

  const OverlayZoom({super.key, required this.myGame});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(30), child: ElevatedButton(
      onPressed: myGame.zoom,
      child: const Icon(Icons.zoom_in, color: Colors.green, size: 50),
    ));
  }
}
