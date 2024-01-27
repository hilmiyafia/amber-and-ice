import 'package:flame/components.dart';
import 'item.dart';

enum WallType { wall, ice }
enum WallState { empty, wall }

class Wall extends Item<WallState, WallType> {
  Wall(super.X, super.Y, super.type);

  @override
  Future<void> onLoad() async {
    if (type == WallType.wall) return;
    animations = {
      WallState.empty: loadSprite("3_0.png", 1, Vector2(160, 240)),
      WallState.wall: loadSprite("3_1.png", 1, Vector2(160, 240)),
    };
    current = WallState.empty;
    size = Vector2(64, 96);
    anchor = const Anchor(0.5, 1 - 16 / 96);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (type == WallType.wall) return;
    var index = 0;
    var wall = game.myWorld.getWallAt(X + 1, Y);
    if (X + 1 == game.myWorld.width) {
      index = 0;
    } else if (wall != null && wall.type != WallType.wall) {
      index = 1;
    }
    current = WallState.values[index];
  }
}
