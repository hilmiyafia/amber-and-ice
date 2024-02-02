import 'dart:math';
import 'package:flame/extensions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'item.dart';
import 'robot.dart';
import 'wall.dart';
import 'floor.dart';
import 'water.dart';
import 'finish.dart';
import 'star.dart';
import 'overlays.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amber and Ice',
      theme: ThemeData(useMaterial3: true),
      home: SafeArea(child: Scaffold(body: GameWidget<MyGame>.controlled(
        gameFactory: MyGame.new,
        overlayBuilderMap: {
          "Menu": (_, myGame) => OverlayMenu(myGame: myGame),
          "Game": (_, myGame) => OverlayGame(myGame: myGame),
          "Zoom": (_, myGame) => OverlayZoom(myGame: myGame),
        },
      ))),
    );
  }
}

class MyGame extends FlameGame with KeyboardEvents {
  late MyWorld myWorld;
  late CameraComponent myCamera;

  @override
  Future<void> onLoad() async {
    FlameAudio.bgm.initialize();
    await images.loadAllImages();
    myWorld = MyWorld();
    myCamera = CameraComponent(world: myWorld);
    addAll([myWorld, myCamera]);
  }

  @override
  KeyEventResult onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      myWorld.movePlayer(0, -1);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      myWorld.movePlayer(-1, 0);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      myWorld.movePlayer(0, 1);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      myWorld.movePlayer(1, 0);
    }
    return KeyEventResult.handled;
  }

  void play() {
    FlameAudio.play("button.ogg");
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm.ogg');
    myCamera.viewport.removeAll(myWorld.stars);
    myWorld.win = false;
    myWorld.stars.clear();
    myWorld.goToLevel(1);
    overlays.remove("Menu");
    overlays.add("Game");
  }

  void restart() {
    FlameAudio.play("button.ogg");
    if (myWorld.zooming) return;
    myWorld.goToLevel(myWorld.level);
  }

  void menu() {
    FlameAudio.play("button.ogg");
    myWorld.goToLevel(0);
    overlays.remove("Game");
  }

  void zoom() {
    FlameAudio.play("button.ogg");
    if (myWorld.animating) return;
    myWorld.zooming = !myWorld.zooming;
    overlays.remove(myWorld.zooming ? "Game" : "Zoom");
    overlays.add(myWorld.zooming ? "Zoom" : "Game");
  }

  void undo() {
    FlameAudio.play("button.ogg");
    if (myWorld.zooming || myWorld.animating) return;
    if (myWorld.player.records.length > 1) {
      for (var item in myWorld.items) {
        if (item is UndoableItem) item.undo();
      }
    }
  }
}

class MyWorld extends World with HasGameRef<MyGame> {
  late Robot player;
  late Finish finish;
  List<Wall> walls = List.empty(growable: true);
  List<Floor> floors = List.empty(growable: true);
  List<Robot> robots = List.empty(growable: true);
  List<Water> waters = List.empty(growable: true);
  List<Item> get items => [...walls, ...floors, ...robots, ...waters, player, finish];
  List<Star> stars = List.empty(growable: true);
  int level = 0, nextLevel = 0, state = 0, counter = 0;
  double timer = 0;
  SpriteComponent? sky;
  bool animating = true, win = false, zooming = false;
  Random random = Random();
  late AudioPool audioFreeze, audioMove, audioMelt, audioIce;
  int get width => maps[level][0].length;
  int get height => maps[level].length;
  List<List<String>> maps = [
    [
      "-----------", "-----f-----", "+++++++++++",
      "+++++++++++", "-----------", "--c--x--h--",
    ],
    [
      "                          ", " --------++--- -----      ",
      " --------++--- --f--      ", " -x---c--++--- -----      ",
      " --------++--- -----      ", " --------++---   +        ",
      "            -   -+    --- ", "            -   -+++++++- ",
      " -----      -   ---    +- ", " ------------          +  ",
      " -----           ---   +- ", " -----h-         -++++++- ",
      " -------         -+   --- ", " -----            +       ",
      " +2+2+  -------   +       ", " +2+2+  -  -  -   +       ",
      " ----- --- - --- ---++--- ", " ----- -+- h -+- ---22--- ",
      " -------+-----2-----++-c- ", " ----- -+-   -+- ---22--- ",
      " ----- ---   --- ---++--- ", "                          ",
    ],
    [
      "                        ", "                   -    ",
      "             --    --   ", " --------    ++++++-h-  ",
      " -  -   -    +     -x-- ", " -----22-- ----    c--  ",
      "   ---  +  ----    --   ", "   ++  ---   2     -    ",
      "  ---- ---   2          ", "  ---- -f-   2          ",
      "  ----       2-         ", "  ----22222222-         ",
      "  ----                  ", "                        ",
    ],
    [
      "                   ", "     ---+-22222222 ", "     ---+-      -  ",
      "        +      --- ", "   ---  +      -f- ", " -c- -  +      --- ",
      " - ---  +  --      ", " ---x++++++----    ", "  -  -  +   2 -    ",
      "  -h--  +   2--    ", "  --    +   2      ", "        +  ---     ",
      "        +++---     ", "        -- ---     ", "           --      ",
      "                   ",
    ],
    [
      "                   ", "   ----------      ", "   -        h      ",
      "   -        -      ", "  ---      ---     ", " -----++++--x--c-- ",
      "  ---      ---   - ", "   -        -    - ", "   2     ------- - ",
      "   2     -     - - ", "   ------- -f- - - ", "   +     - --- - - ",
      "   ------- --- - - ", "   2     -  2  - - ", "   2     ------- - ",
      "   -        -    - ", "  ---      ---   - ", " -----++++-------- ",
      "  ---      ---     ", "   -        -      ", "                   ",
    ]
  ];

  @override
  Future<void> onLoad() async {
    loadMap();
    audioFreeze = await FlameAudio.createPool("freeze.ogg", maxPlayers: 10);
    audioMove = await FlameAudio.createPool("move.ogg", maxPlayers: 10);
    audioMelt = await FlameAudio.createPool("melt.ogg", maxPlayers: 10);
    audioIce = await FlameAudio.createPool("ice.ogg", maxPlayers: 10);
    sky = SpriteComponent.fromImage(
      game.images.fromCache("12.png"), anchor: Anchor.center, priority: -1000,
    );
    add(sky!);
  }

  @override
  Future<void> update(double dt) async {
    if (timer > 0) timer -= dt;
    if (timer < 0) timer = 0;
    if (level != 0) {
      if (!zooming) {
        game.myCamera.viewfinder.zoom = 1;
        game.myCamera.viewfinder.position = Vector2(player.X * 64, player.Y * 48 - 48);
      } else {
        var r1 = width * 64 / (height * 48);
        var r2 = game.canvasSize.x / game.canvasSize.y;
        if (r1 < r2) {
          game.myCamera.viewfinder.zoom = game.canvasSize.y / (height * 48);
        } else {
          game.myCamera.viewfinder.zoom = game.canvasSize.x / (width * 64);
        }
        game.myCamera.viewfinder.position = Vector2(width * 32 - 32, height * 24 - 48);
      }
    }
    if (state == 1 && counter == 0) {
      state = 0;
      animating = false;
      if (level == 0) gameRef.overlays.add("Menu");
      for (var item in items) {
        if (item is UndoableItem) item.record();
      }
    }
    if (state == 2 && counter == 0) {
      state = 0;
      removeAll(items);
      walls.clear();
      floors.clear();
      robots.clear();
      waters.clear();
      level = nextLevel;
      loadMap();
    }
    moveSky();
  }

  void loadMap() {
    for (int y = height - 1; y >= 0; y--) {
      for (int x = 0; x < width; x++) {
        switch (maps[level][y][x]) {
          case "2":
            walls.add(Wall(x, y, WallType.visible));
          case "x":
            player = Robot(x, y, RobotType.player);
            floors.add(Floor(x, y, 0));
          case "h":
            robots.add(Robot(x, y, RobotType.amber));
            floors.add(Floor(x, y, 0));
          case "c":
            robots.add(Robot(x, y, RobotType.ice));
            floors.add(Floor(x, y, 0));
          case "f":
            finish = Finish(x, y);
            floors.add(Floor(x, y, 0));
          case "+":
            waters.add(Water(x, y));
          case "-":
            floors.add(Floor(x, y, 0));
          case " ":
            walls.add(Wall(x, y, WallType.invisible));
        }
      }
    }
    if (level == 0) {
      game.myCamera.viewfinder.position = Vector2(player.X * 64, player.Y * 48 - 144);
    } else {
      game.myCamera.viewfinder.position = Vector2(player.X * 64, player.Y * 48 - 48);
    }
    for (var item in items) {
      item.fadeIn(random.nextInt(500));
    }
    counter = items.length;
    state = 1;
    addAll(items);
    moveSky();
  }

  void goToLevel(int nextLevel) {
    if (animating == true) return;
    this.nextLevel = nextLevel;
    animating = true;
    counter = items.length;
    state = 2;
    if (win) {
      for (int i = 0; i < 100; i++) {
        Vector2 size = game.myCamera.viewport.size;
        stars.add(Star(
          Vector2(random.nextDouble() * size.x, -random.nextDouble() * size.y),
          Vector2(random.nextDouble(), 1 + random.nextDouble()) * 100,
          random.nextDouble() * 100 + 10,
        ));
      }
      game.myCamera.viewport.addAll(stars);
    }
    for (var item in items) {
      item.fadeOut(random.nextInt(500));
    }
  }

  void movePlayer(int dx, int dy) {
    if (animating || level == 0 || timer > 0 || zooming) return;
    timer = 0.1;
    var x1 = player.X + dx, y1 = player.Y + dy;
    if (x1 < 0 || x1 >= width || y1 < 0 || y1 >= height) return;
    var wall1 = getWallAt(x1, y1);
    if (wall1 != null) return;
    var water1 = getWaterAt(x1, y1);
    if (water1 != null && water1.type == WaterType.liquid) return;
    var robot1 = getRobotAt(x1, y1);
    if (robot1 != null) {
      var x2 = x1 + dx, y2 = y1 + dy;
      if (x2 < 0 || x2 >= width || y2 < 0 || y2 >= height) return;
      var wall2 = getWallAt(x2, y2);
      if (wall2 != null) {
        if (wall2.type == WallType.invisible) return;
        if (robot1.type != RobotType.amber) return;
        walls.remove(wall2);
        remove(wall2);
        floors.add(Floor(wall2.X, wall2.Y, 1));
        add(floors.last);
        floors.last.record();
        audioMelt.start(volume: 0.2);
      }
      var water2 = getWaterAt(x2, y2);
      if (water2 != null) {
        if (water2.type == WaterType.liquid) {
          if (robot1.type != RobotType.ice) return;
          water2.type = WaterType.frozen;
          audioFreeze.start(volume: 0.3);
        }
      }
      if (water1 != null && robot1.type == RobotType.amber) water1.counter = 2;
      var robot2 = getRobotAt(x2, y2);
      if (robot2 != null) return;
      if (finish.X == x2 && finish.Y == y2) return;
      robot1..X = x2..Y = y2;
    }
    if (finish.X == x1 && finish.Y == y1) {
      if (level == maps.length - 1) {
        FlameAudio.bgm.stop();
        FlameAudio.playLongAudio("win.ogg", volume: 0.25);
        win = true;
        game.menu();
      } else {
        FlameAudio.play("key.ogg", volume: 0.1);
        goToLevel(level + 1);
      }
      return;
    }
    player..X = x1..Y = y1;
    for (var water in waters) {
      if (water.counter > 0) {
        water.counter--;
        if (water.counter == 0) {
          water.type = WaterType.liquid;
          audioMelt.start(volume: 0.2);
        }
      }
    }
    if (water1 == null) {
      audioMove.start(volume: 0.1);
    } else {
      audioIce.start(volume: 0.1);
    }
    for (var item in items) {
      if (item is UndoableItem) item.record();
    }
  }

  void moveSky() {
    if (sky == null) return;
    sky!.size = game.myCamera.visibleWorldRect.size.toVector2();
    sky!.position = game.myCamera.viewfinder.position;
  }

  Wall? getWallAt(int x, int y, {WallType? type}) {
    for (var wall in walls) {
      if (wall.X == x && wall.Y == y && (type == null || wall.type == type)) return wall;
    }
    return null;
  }

  Robot? getRobotAt(int x, int y, {bool withPlayer = false}) {
    for (var robot in robots) {
      if (robot.X == x && robot.Y == y) return robot;
    }
    return withPlayer && player.X == x && player.Y == y ? player : null;
  }

  Water? getWaterAt(int x, int y) {
    for (var water in waters) {
      if (water.X == x && water.Y == y) return water;
    }
    return null;
  }
}
