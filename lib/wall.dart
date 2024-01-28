import 'package:flame/components.dart';
import 'item.dart';

enum WallType { invisible, visible }
enum WallState { empty, wall }

class Wall extends Item<WallState, WallType> {
  Wall(super.X, super.Y, super.type);

  @override
  Future<void> onLoad() async {
    if (type == WallType.invisible) return;
    animations = {
      WallState.empty: loadSprite("3_0.png", 1, Vector2(160, 240)),
      WallState.wall: loadSprite("3_1.png", 1, Vector2(160, 240)),
    };
    current = WallState.empty;
    size = Vector2(64, 96);
    anchor = const Anchor(0.5, 1 - 16 / 96);
  }

  @override
  void updateSprite() {
    if (type == WallType.invisible) return;
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      current = WallState.wall;
    } else {
      current = WallState.empty;
    }
  }
}
