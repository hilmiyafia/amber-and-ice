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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SafeArea(child: Scaffold(
        body: GameWidget<Engine>.controlled(
          gameFactory: Engine.new,
          initialActiveOverlays: const ["Menu"],
          overlayBuilderMap: {
            "Menu": (_, engine) => Menu(engine: engine),
            "Game": (_, engine) => Game(engine: engine),
          },
        ),
      )),
    );
  }
}

class Engine extends FlameGame with KeyboardEvents {
  late Scene scene;
  late CameraComponent cameraComponent;

  @override
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    await images.loadAllImages();
    scene = Scene();
    cameraComponent = CameraComponent(world: scene);
    addAll([scene, cameraComponent]);
    FlameAudio.bgm.initialize();
  }

  @override
  KeyEventResult onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      scene.movePlayer(0, -1);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      scene.movePlayer(-1, 0);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      scene.movePlayer(0, 1);
    } else if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      scene.movePlayer(1, 0);
    }
    return KeyEventResult.handled;
  }

  void play() {
    FlameAudio.play("button.ogg");
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm.ogg');
    scene.removeAll(scene.stars);
    scene.stars.clear();
    scene.unloadLevel(1);
    overlays.remove("Menu");
    overlays.add("Game");
  }

  void replay() {
    FlameAudio.play("button.ogg");
    scene.unloadLevel(scene.level);
  }

  void menu() {
    scene.unloadLevel(0);
    overlays.remove("Game");
    overlays.add("Menu");
  }
}

class Menu extends StatelessWidget {
  final Engine engine;
  const Menu({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: engine.play,
        child: const Icon(Icons.play_arrow, color: Colors.green, size: 100),
      ),
    );
  }
}

class Game extends StatelessWidget {
  final Engine engine;
  const Game({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(30), child: ElevatedButton(
      onPressed: engine.replay,
      child: const Icon(Icons.replay, color: Colors.green, size: 50),
    ));
  }
}

class Item<T> extends SpriteAnimationGroupComponent<T> with HasGameRef<Engine> {
  late int idx, idy, idtype;
  double timer = 0;
  double start = -1000;
  double stop = -1000;
  int state = -1;
  int priorityOffset = 0;
  double yOffset = 0;
  Item(this.idx, this.idy, this.idtype) {
    anchor = Anchor.bottomCenter;
    y = -1000;
  }

  void fadeIn(int delay) {
    Future.delayed(Duration(milliseconds: delay), () {
      state = 0;
      timer = 0;
      start = -1000;
      stop = idy * 48;
    });
  }

  void fadeOut(int delay) {
    Future.delayed(Duration(milliseconds: delay), () {
      state = 1;
      timer = 0;
      start = y;
      stop = -1000;
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
    timer = min(1, timer + dt);
    x = idx * 64;
    y = yOffset + (game.scene.animating ? lerpDouble(start, stop, timer)! : idy * 48);
    priority = idy * 2 + priorityOffset;
  }
}

class Robot extends Item<RobotState> {
  Robot(idx, idy, z, type) : super(idx, idy, type.index) { fadeIn(z); }
  RobotType get type => RobotType.values[idtype];

  @override
  Future<void> onLoad() async {
    animations = {
      RobotState.empty: loadAnimation("${idtype}_0.png", 1, Vector2(160, 240)),
      RobotState.wall: loadAnimation("${idtype}_1.png", 1, Vector2(160, 240)),
      RobotState.robot: loadAnimation("${idtype}_2.png", 1, Vector2(160, 240)),
    };
    current = RobotState.empty;
    size = Vector2(64, 96);
    priorityOffset = 1;
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    Block? block = game.scene.checkBlock(idx + 1, idy);
    if (idx + 1 == game.scene.width) {
      current = RobotState.empty;
    } else if (game.scene.checkPlayer(idx + 1, idy)) {
      current = RobotState.robot;
    } else if (game.scene.checkRobot(idx + 1, idy) != null) {
      current = RobotState.robot;
    } else if (block != null && block.type != BlockType.wall) {
      current = RobotState.wall;
    } else {
      current = RobotState.empty;
    }
  }
}

class Block extends Item<BlockState> {
  Block(idx, idy, z, type) : super(idx, idy, type.index) { fadeIn(z); }
  BlockType get type => BlockType.values[idtype];

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
    if (type == BlockType.wall) return;
    super.update(dt);
    Block? block = game.scene.checkBlock(idx + 1, idy);
    if (idx + 1 == game.scene.width) {
      current = BlockState.empty;
    } else if (block != null && block.type != BlockType.wall) {
      current = BlockState.wall;
    } else {
      current = BlockState.empty;
    }
  }
}

class Floor extends Item<FloorState> {
  Floor(idx, idy, z) : super(idx, idy, 0) { fadeIn(z); }

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
    int offset = 4;
    if (game.scene.checkPlayer(idx, idy)) {
      offset = 0;
    } else if (game.scene.checkRobot(idx, idy) != null) {
      offset = 0;
    } else if (game.scene.checkFinish(idx, idy)) {
      offset = 8;
    }
    Block? block = game.scene.checkBlock(idx + 1, idy);
    if (idx + 1 == game.scene.width) {
      current = FloorState.values[offset + 0];
    } else if (block != null && block.type != BlockType.wall) {
      current = FloorState.values[offset + 1];
    } else if (game.scene.checkRobot(idx + 1, idy) != null) {
      current = FloorState.values[offset + 2];
    } else if (game.scene.checkPlayer(idx + 1, idy)) {
      current = FloorState.values[offset + 2];
    } else if (game.scene.checkFinish(idx + 1, idy)) {
      current = FloorState.values[offset + 3];
    } else {
      current = FloorState.values[offset + 0];
    }
  }
}

class Water extends Item<WaterState> {
  Water(idx, idy, z) : super(idx, idy, WaterType.liquid.index) { fadeIn(z); }
  WaterType get type => WaterType.values[idtype];
  set type (WaterType value) => idtype = value.index;
  int count = 0;

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
    int offset = 0;
    if (type == WaterType.frozen) {
      if (game.scene.checkRobot(idx, idy) != null) {
        offset = 6;
      } else if (game.scene.checkPlayer(idx, idy)) {
        offset = 6;
      } else {
        offset = 3;
      }
    }
    Block? block = game.scene.checkBlock(idx + 1, idy);
    if (idx + 1 == game.scene.width) {
      current = WaterState.values[offset + 0];
    } else if (block != null && block.type != BlockType.wall) {
      current = WaterState.values[offset + 1];
    } else if (game.scene.checkRobot(idx + 1, idy) != null) {
      current = WaterState.values[offset + 2];
    } else if (game.scene.checkPlayer(idx + 1, idy)) {
      current = WaterState.values[offset + 2];
    } else {
      current = WaterState.values[offset + 0];
    }
  }
}

class Finish extends Item<FinishState> {
  Finish(idx, idy, z) : super(idx, idy, 0) { fadeIn(z); }

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
    Block? block = game.scene.checkBlock(idx + 1, idy);
    if (idx + 1 == game.scene.width) {
      current = FinishState.empty;
    } else if (block != null && block.type != BlockType.wall) {
      current = FinishState.wall;
    } else if (game.scene.checkRobot(idx + 1, idy) != null) {
      current = FinishState.robot;
    } else if (game.scene.checkPlayer(idx + 1, idy)) {
      current = FinishState.robot;
    } else {
      current = FinishState.empty;
    }
  }
}

class Star extends SpriteComponent with HasGameRef<Engine> {
  Vector2 speed = Vector2.zero();
  double baseSize = 1;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    priority = 1000;
    sprite = Sprite(game.images.fromCache("11.png"));
  }

  @override
  void update(double dt) {
    position += speed * dt * 100;
    Vector2 center = -game.cameraComponent.viewport.position;
    Rect rect = game.cameraComponent.visibleWorldRect;
    if (position.y > center.y + rect.height / 2) {
      position.y -= rect.height;
    }
    if (position.x > center.x + rect.width / 2) {
      position.x -= rect.width;
    }
    if (position.x < center.x - rect.width / 2) {
      position.x += rect.width;
    }
    size = Vector2.all(baseSize * (center.y + rect.height / 2 - y) / rect.width);
  }
}

class Scene extends World with HasGameRef<Engine> {
  List<Block> blocks = List.empty(growable: true);
  List<Floor> floors = List.empty(growable: true);
  List<Robot> robots = List.empty(growable: true);
  List<Water> waters = List.empty(growable: true);
  List<Star> stars = List.empty(growable: true);
  int get width => maps[level][0].length;
  int get height => maps[level].length;
  int level = 0;
  double timer = 0;
  late SpriteComponent sky;
  late AudioPool audioFreeze;
  late AudioPool audioMove;
  late AudioPool audioMelt;
  late AudioPool audioIce;
  late Robot player;
  late Finish finish;
  bool animating = true;
  Random random = Random();
  List<List<String>> maps = [
    [
      "-----------",
      "-----f-----",
      "+++++++++++",
      "+++++++++++",
      "-----------",
      "--c--x--h--",
    ],
    [
      "--------++---                              ",
      "--------++---                      -----   ",
      "-x---c--++-----------              --f--   ",
      "--------++---       -              -----   ",
      "--------++---  ------              -----   ",
      "               -                   -----   ",
      "               -                     +     ",
      "             -----                   +     ",
      "             -----                   +     ",
      "             -----                   +     ",
      "             -----h-          -+++++++     ",
      "             -------          -+    --     ",
      "             -----             +           ",
      "             22+++  --------   +           ",
      "             22+++  -      -   +           ",
      "             ----- --- --- h -------++-----",
      "             ----- -+- -+- - -------++-----",
      "             -------+---+-----------++-----",
      "             ----- -+- -+- - -------22--c--",
      "             ----- --- --- - -------22-----",
    ],
    [
      "            --    -   ",
      "            --    --  ",
      "--------    ++++++-h- ",
      "-  -   -    +     -x--",
      "-----22-- ----    c-- ",
      "  ---  +  ----    --  ",
      "  ++  ---   2     -   ",
      " ---- ---   2         ",
      " ---- -f-   2         ",
      " ----       2-        ",
      " ----22222222-        ",
      " ----                 ",
    ],
    [
      "    ---+-22222222    ",
      "    ---+-      -     ",
      "       +      ---    ",
      "  ---  +      -f-    ",
      "-c- -  +      ---    ",
      "- ---  +  --         ",
      "---x+++-++----       ",
      " -  -  +   2 -       ",
      " -h--  +   2--       ",
      " --    +   2         ",
      "       +  ---        ",
      "       +++---        ",
      "       -- ---        ",
      "          --         ",
    ],
  ];

  @override
  Future<void> onLoad() async {
    loadLevel();
    audioFreeze = await FlameAudio.createPool("freeze.ogg", maxPlayers: 10);
    audioMove = await FlameAudio.createPool("move.ogg", maxPlayers: 10);
    audioMelt = await FlameAudio.createPool("melt.ogg", maxPlayers: 10);
    audioIce = await FlameAudio.createPool("ice.ogg", maxPlayers: 10);
    sky = SpriteComponent.fromImage(game.images.fromCache("12.png"));
    sky.anchor = Anchor.center;
    sky.priority = -1000;
    add(sky);
  }

  @override
  Future<void> update(double dt) async {
    if (timer > 0) timer -= dt;
    if (timer < 0) timer = 0;
    sky.size = game.cameraComponent.visibleWorldRect.size.toVector2();
    sky.position = -game.cameraComponent.viewport.position;
  }

  void loadLevel() {
    for (int y = height - 1, z = 0; y >= 0; y--) {
      for (int x = 0; x < width; x++, z = random.nextInt(500)) {
        if (maps[level][y][x] == "2") {
          blocks.add(Block(x, y, z, BlockType.ice));
        } else if (maps[level][y][x] == "x") {
          player = Robot(x, y, z, RobotType.player);
          floors.add(Floor(x, y, z));
        } else if (maps[level][y][x] == "h") {
          robots.add(Robot(x, y, z, RobotType.hot));
          floors.add(Floor(x, y, z));
        } else if (maps[level][y][x] == "c") {
          robots.add(Robot(x, y, z, RobotType.cold));
          floors.add(Floor(x, y, z));
        } else if (maps[level][y][x] == "f") {
          finish = Finish(x, y, z);
          floors.add(Floor(x, y, z));
        } else if (maps[level][y][x] == "+") {
          waters.add(Water(x, y, z));
        } else if (maps[level][y][x] == "-") {
          floors.add(Floor(x, y, z));
        } else if (maps[level][y][x] == " ") {
          blocks.add(Block(x, y, z, BlockType.wall));
        }
      }
    }
    addAll(blocks);
    addAll(floors);
    addAll(robots);
    addAll(waters);
    add(player);
    add(finish);
    int y = level == 0 ? 2 - player.idy : -player.idy;
    Vector2 position = Vector2(-player.idx * 64, y * 48 + 48);
    game.cameraComponent.viewport.position = position;
    Future.delayed(const Duration(milliseconds: 2000), () => animating = false);
  }

  void unloadLevel(int nextLevel) {
    if (animating == true) return;
    animating = true;
    player.fadeOut(0);
    finish.fadeOut(0);
    for (Block block in blocks) {
      block.fadeOut(random.nextInt(500));
    }
    for (Floor floor in floors) {
      floor.fadeOut(random.nextInt(500));
    }
    for (Robot robot in robots) {
      robot.fadeOut(random.nextInt(500));
    }
    for (Water water in waters) {
      water.fadeOut(random.nextInt(500));
    }
    Future.delayed(const Duration(milliseconds: 2000), () {
      removeAll(blocks);
      removeAll(floors);
      removeAll(robots);
      removeAll(waters);
      remove(player);
      remove(finish);
      blocks.clear();
      floors.clear();
      robots.clear();
      waters.clear();
      level = nextLevel;
      loadLevel();
    });
  }

  void createStars() {
    for (int i = 0; i < 100; i++) {
      Star star = Star();
      Vector2 center = -game.cameraComponent.viewport.position;
      Rect rect = game.cameraComponent.visibleWorldRect;
      double x = center.x + (2 * random.nextDouble() - 1) * rect.width;
      double y = center.y - rect.height / 2;
      star.position = Vector2(x, y);
      star.baseSize = random.nextDouble() * 100 + 10;
      star.speed = Vector2(random.nextDouble(), 1 + random.nextDouble());
      stars.add(star);
    }
    addAll(stars);
  }

  void movePlayer(int dx, int dy) {
    if (animating || level == 0 || timer > 0) return;
    timer = 0.1;
    int newX = player.idx + dx;
    int newY = player.idy + dy;
    if (newX < 0 || newX >= width || newY < 0 || newY >= height) return;
    if (checkBlock(newX, newY) != null) return;
    if (checkWater(newX, newY) != null) return;
    Robot? robot = checkRobot(newX, newY);
    if (robot != null) {
      int nextX = newX + dx;
      int nextY = newY + dy;
      if (checkFinish(nextX, nextY)) return;
      if (checkRobot(nextX, nextY) != null) return;
      Block? block = checkBlock(nextX, nextY);
      if (block != null) {
        if (block.type != BlockType.ice || robot.type != RobotType.hot) return;
        blocks.remove(block);
        remove(block);
        floors.add(Floor(block.idx, block.idy, 0));
        add(floors.last);
        audioMelt.start(volume: 0.2);
      }
      Water? water = checkWater(nextX, nextY);
      if (robot.type != RobotType.cold) {
        if (water != null) return;
      } else if (water != null) {
        water.type = WaterType.frozen;
        audioFreeze.start(volume: 0.3);
      }
      if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) return;
      Water? frozen = checkFrozen(newX, newY);
      if (frozen != null && robot.type == RobotType.hot) frozen.count = 3;
      robot.idx = nextX;
      robot.idy = nextY;
    }
    for (Water frozen in waters) {
      frozen.count--;
      if (frozen.type != WaterType.frozen || frozen.count != 1) continue;
      frozen.count = 0;
      frozen.type = WaterType.liquid;
      audioMelt.start(volume: 0.2);
    }
    if (checkFrozen(newX, newY) == null) {
      audioMove.start(volume: 0.1);
    } else {
      audioIce.start(volume: 0.1);
    }
    player.idx = newX;
    player.idy = newY;
    if (checkFinish(newX, newY)) {
      if (level == 3) {
        FlameAudio.bgm.stop();
        FlameAudio.playLongAudio("win.ogg", volume: 0.25);
        createStars();
        game.menu();
      } else {
        unloadLevel(level + 1);
        FlameAudio.play("key.ogg", volume: 0.1);
      }
    } else {
      Vector2 position = Vector2(-newX * 64, -newY * 48 + 48);
      game.cameraComponent.viewport.position = position;
    }
  }

  Block? checkBlock(int idx, int idy) {
    for (Block block in blocks) {
      if (idx == block.idx && idy == block.idy) return block;
    }
    return null;
  }

  Robot? checkRobot(int idx, int idy) {
    for (Robot robot in robots) {
      if (idx == robot.idx && idy == robot.idy) return robot;
    }
    return null;
  }

  Water? checkWater(int idx, int idy) {
    for (Water water in waters) {
      if (water.type != WaterType.liquid) continue;
      if (idx == water.idx && idy == water.idy) return water;
    }
    return null;
  }

  Water? checkFrozen(int idx, int idy) {
    for (Water water in waters) {
      if (water.type != WaterType.frozen) continue;
      if (idx == water.idx && idy == water.idy) return water;
    }
    return null;
  }

  bool checkFinish(int idx, idy) {
    return idx == finish.idx && idy == finish.idy;
  }

  bool checkPlayer(int idx, int idy) {
    return idx == player.idx && idy == player.idy;
  }
}