import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum FloorSprite {
  emptyNoShadow, emptyWallShadow, emptyRobotShadow, emptyKeyShadow,
  steppedNoShadow, steppedWallShadow, steppedRobotShadow, steppedKeyShadow,
  hasKeyNoShadow, hasKeyWallShadow, hasKeyRobotShadow
}

class Floor extends UndoableItem<FloorSprite, int> {
  int state;

  Floor(int X, int Y, this.state) : super(X, Y);

  @override
  Future<void> onLoad() async {
    animations = {
      FloorSprite.emptyNoShadow: loadSprite("4_0.png", 1, Vector2(160, 160)),
      FloorSprite.emptyWallShadow: loadSprite("4_1.png", 1, Vector2(160, 160)),
      FloorSprite.emptyRobotShadow: loadSprite("4_2.png", 1, Vector2(160, 160)),
      FloorSprite.emptyKeyShadow: loadSprite("4_3.png", 1, Vector2(160, 160)),
      FloorSprite.steppedNoShadow: loadSprite("5_0.png", 1, Vector2(160, 160)),
      FloorSprite.steppedWallShadow: loadSprite("5_1.png", 1, Vector2(160, 160)),
      FloorSprite.steppedRobotShadow: loadSprite("5_2.png", 1, Vector2(160, 160)),
      FloorSprite.steppedKeyShadow: loadSprite("5_3.png", 1, Vector2(160, 160)),
      FloorSprite.hasKeyNoShadow: loadSprite("6_0.png", 1, Vector2(160, 160)),
      FloorSprite.hasKeyWallShadow: loadSprite("6_1.png", 1, Vector2(160, 160)),
      FloorSprite.hasKeyRobotShadow: loadSprite("6_2.png", 1, Vector2(160, 160)),
    };
    size = Vector2(64, 64);
    anchor = const Anchor(0.5, 1 - 16 / 64);
  }

  @override
  void updateSprite() {
    var index = 0;
    if (game.myWorld.getRobotAt(X, Y, withPlayer: true) != null) {
      index = 4;
    } else if (game.myWorld.finish.X == X && game.myWorld.finish.Y == Y) {
      index = 8;
    }
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      index += 1;
    } else if (game.myWorld.getRobotAt(X + 1, Y, withPlayer: true) != null) {
      index += 2;
    } else if (game.myWorld.finish.X == X + 1 && game.myWorld.finish.Y == Y) {
      index += 3;
    }
    current = FloorSprite.values[index];
  }

  @override
  void record() {
    records.add(state);
    state = 0;
    if (records.length > 3) records.removeAt(0);
  }

  @override
  void undo() {
    if (records.last == 1) {
      game.myWorld.walls.add(Wall(X, Y, WallType.visible));
      game.myWorld.add(game.myWorld.walls.last);
      game.myWorld.remove(this);
      game.myWorld.floors.remove(this);
    } else {
      records.removeLast();
    }
  }
}
