import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum WaterType { liquid, frozen }
enum WaterSprite {
  frozenNoShadow, frozenWallShadow, frozenRobotShadow,
  liquidNoShadow, liquidWallShadow, liquidRobotShadow,
  steppedNoShadow, steppedWallShadow, steppedRobotShadow
}

class Water extends UndoableTypedItem<WaterType, WaterSprite, ({WaterType type, int counter})> {
  int counter = 0;

  Water(int X, int Y) : super(X, Y, WaterType.liquid);

  @override
  Future<void> onLoad() async {
    animations = {
      WaterSprite.frozenNoShadow: loadSprite("8_0.png", 1, Vector2(160, 160)),
      WaterSprite.frozenWallShadow: loadSprite("8_1.png", 1, Vector2(160, 160)),
      WaterSprite.frozenRobotShadow: loadSprite("8_2.png", 1, Vector2(160, 160)),
      WaterSprite.liquidNoShadow: loadSprite("7_0.png", 8, Vector2(160, 160)),
      WaterSprite.liquidWallShadow: loadSprite("7_1.png", 8, Vector2(160, 160)),
      WaterSprite.liquidRobotShadow: loadSprite("7_2.png", 8, Vector2(160, 160)),
      WaterSprite.steppedNoShadow: loadSprite("9_0.png", 1, Vector2(160, 160)),
      WaterSprite.steppedWallShadow: loadSprite("9_1.png", 1, Vector2(160, 160)),
      WaterSprite.steppedRobotShadow: loadSprite("9_2.png", 1, Vector2(160, 160)),
    };
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
    current = WaterSprite.values[index];
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
