import 'dart:math';
import 'dart:ui';
import 'package:flame/extensions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

enum RobotType { player, hot, cold }
enum BlockType { wall, ice }
enum WaterType { liquid, frozen }
enum RobotState { empty, wall, robot }
enum BlockState { empty, wall }
enum FinishState { empty, wall, robot }
enum WaterState {
  liquidEmpty, liquidWall, liquidRobot,
  frozenEmpty, frozenWall, frozenRobot,
  stepEmpty, stepWall, stepRobot
}
enum FloorState {
  stepEmpty, stepWall, stepRobot, stepKey,
  baseEmpty, baseWall, baseRobot, baseKey,
  keyEmpty, keyWall, keyRobot,
}

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
        initialActiveOverlays: const ["Menu"],
        overlayBuilderMap: {
          "Menu": (_, myGame) => OverlayMenu(myGame: myGame),
          "Game": (_, myGame) => OverlayGame(myGame: myGame),
          "Zoom": (_, myGame) => OverlayZoom(myGame: myGame),
        },
      ))),
    );
  }
}

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
    return Padding(padding: const EdgeInsets.all(30), child: Row(children: [
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
    ]));
  }
}

class OverlayZoom extends StatelessWidget {
  final MyGame myGame;
  const OverlayZoom({super.key, required this.myGame});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(30), child:
    ElevatedButton(
      onPressed: myGame.zoom,
      child: const Icon(Icons.zoom_in, color: Colors.green, size: 50),
    ));
  }
}

class MyGame extends FlameGame with KeyboardEvents {
  late MyWorld myWorld;
  late CameraComponent myCamera;
  bool zooming = false;

  @override
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    await images.loadAllImages();
    myWorld = MyWorld();
    myCamera = CameraComponent(world: myWorld);
    addAll([myWorld, myCamera]);
    FlameAudio.bgm.initialize();
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
    myWorld.removeAll(myWorld.stars);
    myWorld.stars.clear();
    myWorld.nextLevel = 1;
    myWorld.unloadLevel();
    overlays.remove("Menu");
    overlays.add("Game");
    myWorld.win = false;
  }

  void restart() {
    FlameAudio.play("button.ogg");
    if (zooming) return;
    myWorld.nextLevel = myWorld.level;
    myWorld.unloadLevel();
  }

  void menu() {
    FlameAudio.play("button.ogg");
    myWorld.nextLevel = 0;
    myWorld.unloadLevel();
    overlays.remove("Game");
    overlays.add("Menu");
  }

  void zoom() {
    FlameAudio.play("button.ogg");
    if (myWorld.animating) return;
    zooming = !zooming;
    overlays.remove(zooming ? "Game" : "Zoom");
    overlays.add(zooming ? "Zoom" : "Game");
  }

  void undo() {
    FlameAudio.play("button.ogg");
    if (zooming || myWorld.animating) return;
    if (myWorld.player.previousX.length > 1) {
      myWorld.player.undo();
      for (Water water in myWorld.waters) water.undo();
      for (Robot robot in myWorld.robots) robot.undo();
      for (Floor floor in myWorld.floors) {
        if (floor.previousState.last == 1) {
          myWorld.blocks.add(Block(floor._x, floor._y, BlockType.ice, -1));
          myWorld.add(myWorld.blocks.last);
          myWorld.remove(floor);
          myWorld.floors.remove(floor);
          break;
        } else {
          floor.previousState.removeLast();
        }
      }
    }
  }
}

class Item<T> extends SpriteAnimationGroupComponent<T> with HasGameRef<MyGame> {
  double timer = 0.5, start = -1000, stop = -1000, yOffset = 0;
  int _x, _y, _type, priorityOffset = 0;
  bool sent = true;

  Item(this._x, this._y, this._type, int delay) {
    anchor = Anchor.bottomCenter;
    y = -1000;
    fadeIn(delay);
  }

  void fadeIn(int delay) {
    if (delay < 0) return;
    Future.delayed(Duration(milliseconds: delay), () {
      start = game.myCamera.visibleWorldRect.top - 64;
      stop = _y * 48;
      sent = false;
      timer = 0;
    });
  }

  void fadeOut(int delay) {
    Future.delayed(Duration(milliseconds: delay), () {
      start = _y * 48;
      stop = game.myCamera.visibleWorldRect.top - 64;
      sent = false;
      timer = 0;
    });
  }

  SpriteAnimation loadAnimation(name, amount, size) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache(name),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: 0.25,
        textureSize: size,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer = min(timer + dt, 0.25);
    if (timer == 0.25 && sent == false) {
      sent = true;
      game.myWorld.counter--;
    }
    x = _x * 64;
    y = yOffset + (game.myWorld.animating ? lerpDouble(start, stop, 4 * timer)! : _y * 48);
    priority = _y * 2 + priorityOffset;
  }
}

class Robot extends Item<RobotState> {
  RobotType get type => RobotType.values[_type];
  List<int> previousX = List.empty(growable: true);
  List<int> previousY = List.empty(growable: true);

  Robot(int x, int y, RobotType type, int delay) : super(x, y, type.index, delay) { record(); }

  void record() {
    previousX.add(_x);
    previousY.add(_y);
    if (previousX.length > 3) {
      previousX.removeAt(0);
      previousY.removeAt(0);
    }
  }

  void undo() {
    previousX.removeLast();
    previousY.removeLast();
    _x = previousX.last;
    _y = previousY.last;
  }

  @override
  Future<void> onLoad() async {
    animations = {
      RobotState.empty: loadAnimation("${_type}_0.png", 1, Vector2(160, 240)),
      RobotState.wall: loadAnimation("${_type}_1.png", 1, Vector2(160, 240)),
      RobotState.robot: loadAnimation("${_type}_2.png", 1, Vector2(160, 240)),
    };
    current = RobotState.empty;
    size = Vector2(64, 96);
    priorityOffset = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    int i = 0;
    Block? b = game.myWorld.getBlockAt(_x + 1, _y);
    if (_x + 1 == game.myWorld.width) i = 0;
    else if (game.myWorld.player._x == _x + 1 && game.myWorld.player._y == _y) i = 2;
    else if (game.myWorld.getRobotAt(_x + 1, _y) != null) i = 2;
    else if (b != null && b.type != BlockType.wall) i = 1;
    current = RobotState.values[i];
  }
}

class Block extends Item<BlockState> {
  BlockType get type => BlockType.values[_type];

  Block(int x, int y, BlockType type, int delay) : super(x, y, type.index, delay);

  @override
  Future<void> onLoad() async {
    if (type == BlockType.wall) return;
    animations = {
      BlockState.empty: loadAnimation("3_0.png", 1, Vector2(160, 240)),
      BlockState.wall: loadAnimation("3_1.png", 1, Vector2(160, 240)),
    };
    current = BlockState.empty;
    size = Vector2(64, 96);
    yOffset = 16;
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (type == BlockType.wall) return;
    int i = 0;
    Block? b = game.myWorld.getBlockAt(_x + 1, _y);
    if (_x + 1 == game.myWorld.width) i = 0;
    else if (b != null && b.type != BlockType.wall) i = 1;
    current = BlockState.values[i];
  }
}

class Floor extends Item<FloorState> {
  List<int> previousState = List.empty(growable: true);

  Floor(int x, int y, int delay, int state) : super(x, y, 0, delay) { record(state); }

  void record(int state) {
    previousState.add(state);
    if (previousState.length > 3) previousState.removeAt(0);
  }

  @override
  Future<void> onLoad() async {
    animations = {
      FloorState.baseEmpty: loadAnimation("4_0.png", 1, Vector2(160, 160)),
      FloorState.baseWall: loadAnimation("4_1.png", 1, Vector2(160, 160)),
      FloorState.baseRobot: loadAnimation("4_2.png", 1, Vector2(160, 160)),
      FloorState.baseKey: loadAnimation("4_3.png", 1, Vector2(160, 160)),
      FloorState.stepEmpty: loadAnimation("5_0.png", 1, Vector2(160, 160)),
      FloorState.stepWall: loadAnimation("5_1.png", 1, Vector2(160, 160)),
      FloorState.stepRobot: loadAnimation("5_2.png", 1, Vector2(160, 160)),
      FloorState.stepKey: loadAnimation("5_3.png", 1, Vector2(160, 160)),
      FloorState.keyEmpty: loadAnimation("6_0.png", 1, Vector2(160, 160)),
      FloorState.keyWall: loadAnimation("6_1.png", 1, Vector2(160, 160)),
      FloorState.keyRobot: loadAnimation("6_2.png", 1, Vector2(160, 160)),
    };
    current = FloorState.baseEmpty;
    size = Vector2(64, 64);
    yOffset = 16;
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    int i = 4;
    if (game.myWorld.player._x == _x && game.myWorld.player._y == _y) i = 0;
    else if (game.myWorld.getRobotAt(_x, _y) != null) i = 0;
    else if (game.myWorld.finish._x == _x && game.myWorld.finish._y == _y) i = 8;
    Block? b = game.myWorld.getBlockAt(_x + 1, _y);
    if (_x + 1 == game.myWorld.width) i += 0;
    else if (b != null && b.type != BlockType.wall) i += 1;
    else if (game.myWorld.getRobotAt(_x + 1, _y) != null) i += 2;
    else if (game.myWorld.player._x == _x + 1 && game.myWorld.player._y == _y) i += 2;
    else if (game.myWorld.finish._x == _x + 1 && game.myWorld.finish._y == _y) i += 3;
    current = FloorState.values[i];
  }
}

class Water extends Item<WaterState> {
  int temperature = 0;
  WaterType get type => WaterType.values[_type];
  set type (WaterType value) => _type = value.index;
  List<WaterType> previousType = List.empty(growable: true);
  List<int> previousTemperature = List.empty(growable: true);

  Water(int x, int y, int delay) : super(x, y, 0, delay) { record(); }

  void record() {
    previousTemperature.add(temperature);
    previousType.add(type);
    if (previousTemperature.length > 3) {
      previousTemperature.removeAt(0);
      previousType.removeAt(0);
    }
  }

  void undo() {
    previousTemperature.removeLast();
    previousType.removeLast();
    temperature = previousTemperature.last;
    type = previousType.last;
  }

  @override
  Future<void> onLoad() async {
    animations = {
      WaterState.liquidEmpty: loadAnimation("7_0.png", 8, Vector2(160, 160)),
      WaterState.liquidWall: loadAnimation("7_1.png", 8, Vector2(160, 160)),
      WaterState.liquidRobot: loadAnimation("7_2.png", 8, Vector2(160, 160)),
      WaterState.frozenEmpty: loadAnimation("8_0.png", 1, Vector2(160, 160)),
      WaterState.frozenWall: loadAnimation("8_1.png", 1, Vector2(160, 160)),
      WaterState.frozenRobot: loadAnimation("8_2.png", 1, Vector2(160, 160)),
      WaterState.stepEmpty: loadAnimation("9_0.png", 1, Vector2(160, 160)),
      WaterState.stepWall: loadAnimation("9_1.png", 1, Vector2(160, 160)),
      WaterState.stepRobot: loadAnimation("9_2.png", 1, Vector2(160, 160)),
    };
    current = WaterState.liquidEmpty;
    size = Vector2(64, 64);
    yOffset = 16;
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    int i = 3;
    if (type != WaterType.frozen) i = 0;
    else if (game.myWorld.getRobotAt(_x, _y) != null) i = 6;
    else if (game.myWorld.player._x == _x && game.myWorld.player._y == _y) i = 6;
    Block? b = game.myWorld.getBlockAt(_x + 1, _y);
    if (_x + 1 == game.myWorld.width) i += 0;
    else if (b != null && b.type != BlockType.wall) i += 1;
    else if (game.myWorld.getRobotAt(_x + 1, _y) != null) i += 2;
    else if (game.myWorld.player._x == _x + 1 && game.myWorld.player._y == _y) i += 2;
    current = WaterState.values[i];
  }
}

class Finish extends Item<FinishState> {
  Finish(int x, int y, int delay) : super(x, y, 0, delay);

  @override
  Future<void> onLoad() async {
    animations = {
      FinishState.empty: loadAnimation("10_0.png", 1, Vector2(160, 200)),
      FinishState.wall: loadAnimation("10_1.png", 1, Vector2(160, 200)),
      FinishState.robot: loadAnimation("10_2.png", 1, Vector2(160, 200)),
    };
    current = FinishState.empty;
    size = Vector2(64, 80);
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    int i = 0;
    Block? b = game.myWorld.getBlockAt(_x + 1, _y);
    if (_x + 1 == game.myWorld.width) i = 0;
    else if (b != null && b.type != BlockType.wall) i = 1;
    else if (game.myWorld.getRobotAt(_x + 1, _y) != null) i = 2;
    else if (game.myWorld.player._x == _x + 1 && game.myWorld.player._y == _y) i = 2;
    current = FinishState.values[i];
  }
}

class Star extends SpriteComponent with HasGameRef<MyGame> {
  Vector2 speed = Vector2.zero();
  double ratio = 1;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    priority = 1000;
    sprite = Sprite(game.images.fromCache("11.png"));
  }

  @override
  void update(double dt) {
    position += speed * dt;
    Rect r = game.myCamera.visibleWorldRect;
    if (position.y > r.bottom) position.y -= r.height;
    if (position.x > r.right) position.x -= r.width;
    if (position.x < r.left) position.x += r.width;
    size = Vector2.all(ratio * (r.bottom - y) / r.height);
  }
}

class MyWorld extends World with HasGameRef<MyGame> {
  List<Block> blocks = List.empty(growable: true);
  List<Floor> floors = List.empty(growable: true);
  List<Robot> robots = List.empty(growable: true);
  List<Water> waters = List.empty(growable: true);
  List<Star> stars = List.empty(growable: true);
  int get width => maps[level][0].length;
  int get height => maps[level].length;
  int level = 0, nextLevel = 0, state = 0, counter = 0;
  double timer = 0;
  SpriteComponent? sky;
  late AudioPool audioFreeze, audioMove, audioMelt, audioIce;
  late Robot player;
  late Finish finish;
  bool animating = true, win = false;
  Random random = Random();
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
    loadLevel();
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
      if (!game.zooming) {
        game.myCamera.viewfinder.zoom = 1;
        game.myCamera.viewfinder.position = Vector2(player._x * 64, player._y * 48 - 48);
      } else {
        double r1 = width * 64 / (height * 48);
        double r2 = game.canvasSize.x / game.canvasSize.y;
        if (r1 < r2) game.myCamera.viewfinder.zoom = game.canvasSize.y / (height * 48);
        else game.myCamera.viewfinder.zoom = game.canvasSize.x / (width * 64);
        game.myCamera.viewfinder.position = Vector2(width * 32 - 32, height * 24 - 48);
      }
    }
    updateSky();
    if (state == 1 && counter == 0) {
      state = 0;
      animating = false;
    }
    if (state == 2 && counter == 0) {
      state = 0;
      removeAll([...blocks, ...floors, ...robots, ...waters, player, finish]);
      blocks.clear();
      floors.clear();
      robots.clear();
      waters.clear();
      level = nextLevel;
      loadLevel();
    }
  }

  void loadLevel() {
    for (int y = height - 1, delay = 0; y >= 0; y--) {
      for (int x = 0; x < width; x++, delay = random.nextInt(500)) {
        if (maps[level][y][x] == "2") {
          blocks.add(Block(x, y, BlockType.ice, delay));
        } else if (maps[level][y][x] == "x") {
          player = Robot(x, y, RobotType.player, delay);
          floors.add(Floor(x, y, delay, 0));
        } else if (maps[level][y][x] == "h") {
          robots.add(Robot(x, y, RobotType.hot, delay));
          floors.add(Floor(x, y, delay, 0));
        } else if (maps[level][y][x] == "c") {
          robots.add(Robot(x, y, RobotType.cold, delay));
          floors.add(Floor(x, y, delay, 0));
        } else if (maps[level][y][x] == "f") {
          finish = Finish(x, y, delay);
          floors.add(Floor(x, y, delay, 0));
        } else if (maps[level][y][x] == "+") {
          waters.add(Water(x, y, delay));
        } else if (maps[level][y][x] == "-") {
          floors.add(Floor(x, y, delay, 0));
        } else if (maps[level][y][x] == " ") {
          blocks.add(Block(x, y, BlockType.wall, delay));
        }
      }
    }
    counter = blocks.length + floors.length + waters.length + robots.length + 2;
    state = 1;
    addAll([...blocks, ...floors, ...robots, ...waters, player, finish]);
    int y = player._y - (level == 0 ? 2 : 0);
    game.myCamera.viewfinder.position = Vector2(player._x * 64, y * 48 - 48);
    updateSky();
    if (win) createStars();
  }

  void updateSky() {
    if (sky == null) return;
    sky!.size = game.myCamera.visibleWorldRect.size.toVector2();
    sky!.position = game.myCamera.viewfinder.position;
  }

  void unloadLevel() {
    if (animating == true) return;
    animating = true;
    player.fadeOut(0);
    finish.fadeOut(0);
    for (Block e in blocks) e.fadeOut(random.nextInt(500));
    for (Floor e in floors) e.fadeOut(random.nextInt(500));
    for (Robot e in robots) e.fadeOut(random.nextInt(500));
    for (Water e in waters) e.fadeOut(random.nextInt(500));
    counter = blocks.length + floors.length + waters.length + robots.length + 2;
    state = 2;
  }

  void createStars() {
    for (int i = 0; i < 100; i++) {
      Rect r = game.myCamera.visibleWorldRect;
      stars.add(Star()
        ..position = Vector2(r.left + random.nextDouble() * r.width, r.top)
        ..ratio = random.nextDouble() * 100 + 10
        ..speed = Vector2(random.nextDouble(), 1 + random.nextDouble()) * 100
      );
    }
    addAll(stars);
  }

  void movePlayer(int dx, int dy) {
    if (animating || level == 0 || timer > 0 || game.zooming) return;
    timer = 0.1;
    var x1 = player._x + dx, y1 = player._y + dy;
    if (x1 < 0 || x1 >= width || y1 < 0 || y1 >= height) return;
    if (getBlockAt(x1, y1) != null) return;
    if (getWaterAt(x1, y1, WaterType.liquid) != null) return;
    Robot? r = getRobotAt(x1, y1);
    int n = floors.length;
    if (r != null) {
      var x2 = x1 + dx, y2 = y1 + dy;
      if (finish._x == x2 && finish._y == y2) return;
      if (getRobotAt(x2, y2) != null) return;
      Block? b = getBlockAt(x2, y2);
      if (b != null) {
        if (b.type != BlockType.ice || r.type != RobotType.hot) return;
        blocks.remove(b);
        remove(b);
        floors.add(Floor(b._x, b._y, -1, 1));
        add(floors.last);
        audioMelt.start(volume: 0.2);
      }
      Water? w = getWaterAt(x2, y2, WaterType.liquid);
      if (r.type != RobotType.cold) {
        if (w != null) return;
      } else if (w != null) {
        w.type = WaterType.frozen;
        audioFreeze.start(volume: 0.3);
      }
      if (x2 < 0 || x2 >= width || y2 < 0 || y2 >= height) return;
      w = getWaterAt(x1, y1, WaterType.frozen);
      if (w != null && r.type == RobotType.hot) w.temperature = 3;
      r.._x = x2.._y = y2;
    }
    for (Water e in waters) {
      e.temperature--;
      if (e.type == WaterType.liquid || e.temperature != 1) continue;
      e.temperature = 0;
      e.type = WaterType.liquid;
      audioMelt.start(volume: 0.2);
    }
    if (getWaterAt(x1, y1, WaterType.frozen) == null) audioMove.start(volume: 0.1);
    else audioIce.start(volume: 0.1);
    player.._x = x1.._y = y1;
    if (finish._x == x1 && finish._y == y1) {
      if (level == maps.length - 1) {
        FlameAudio.bgm.stop();
        FlameAudio.playLongAudio("win.ogg", volume: 0.25);
        win = true;
        game.menu();
      } else {
        nextLevel = level + 1;
        unloadLevel();
        FlameAudio.play("key.ogg", volume: 0.1);
      }
    } else {
      for (Water e in waters) e.record();
      for (Robot e in robots) e.record();
      for (int i = 0; i < n; i++) floors[i].record(0);
      player.record();
    }
  }

  Block? getBlockAt(int x, int y) {
    for (Block e in blocks) if (e._x == x && e._y == y) return e;
    return null;
  }

  Robot? getRobotAt(int x, int y) {
    for (Robot e in robots) if (e._x == x && e._y == y) return e;
    return null;
  }

  Water? getWaterAt(int x, int y, WaterType type) {
    for (Water e in waters) if (e._x == x && e._y == y && e.type == type) return e;
    return null;
  }
}
