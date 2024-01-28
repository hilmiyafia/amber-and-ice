import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum WaterType { liquid, frozen }
enum WaterState { frozenEmpty, frozenWall, frozenRobot, liquidEmpty, liquidWall, liquidRobot, stepEmpty, stepWall, stepRobot }

class Water extends UndoableItem<WaterState, WaterType, ({WaterType type, int counter})> {
  int counter = 0;

  Water(int X, int Y) : super(X, Y, WaterType.liquid);

  @override
  Future<void> onLoad() async {
    animations = {
      WaterState.frozenEmpty: loadSprite("8_0.png", 1, Vector2(160, 160)),
      WaterState.frozenWall: loadSprite("8_1.png", 1, Vector2(160, 160)),
      WaterState.frozenRobot: loadSprite("8_2.png", 1, Vector2(160, 160)),
      WaterState.liquidEmpty: loadSprite("7_0.png", 8, Vector2(160, 160)),
      WaterState.liquidWall: loadSprite("7_1.png", 8, Vector2(160, 160)),
      WaterState.liquidRobot: loadSprite("7_2.png", 8, Vector2(160, 160)),
      WaterState.stepEmpty: loadSprite("9_0.png", 1, Vector2(160, 160)),
      WaterState.stepWall: loadSprite("9_1.png", 1, Vector2(160, 160)),
      WaterState.stepRobot: loadSprite("9_2.png", 1, Vector2(160, 160)),
    };
    current = WaterState.liquidEmpty;
    size = Vector2(64, 64);
    anchor = const Anchor(0.5, 1 - 16 / 64);
  }

  @override
  void updateSprite() {
    var index = 0;
    if (type == WaterType.liquid) {
      index = 3;
    } else if (game.myWorld.getRobotAt(X, Y, withPlayer: true) != null) {
      index = 6;
    }
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      index += 1;
    } else if (game.myWorld.getRobotAt(X + 1, Y, withPlayer: true) != null) {
      index += 2;
    }
    current = WaterState.values[index];
  }

  @override
  void record() {
    records.add((type: type, counter: counter));
    if (records.length > 3) records.removeAt(0);
  }

  @override
  void undo() {
    records.removeLast();
    counter = records.last.counter;
    type = records.last.type;
  }
}
