import 'package:flame/components.dart';
import 'item.dart';

enum WallType { invisible, visible }
enum WallSprite { noShadow, wallShadow }

class Wall extends TypedItem<WallType, WallSprite> {
  Wall(super.X, super.Y, super.type);

  @override
  Future<void> onLoad() async {
    if (type == WallType.invisible) return;
    animations = {
      WallSprite.noShadow: loadSprite("3_0.png", 1, Vector2(160, 240)),
      WallSprite.wallShadow: loadSprite("3_1.png", 1, Vector2(160, 240)),
    };
    size = Vector2(64, 96);
    anchor = const Anchor(0.5, 1 - 16 / 96);
  }

  @override
  void updateSprite() {
    if (type == WallType.invisible) return;
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      current = WallSprite.wallShadow;
    } else {
      current = WallSprite.noShadow;
    }
  }
}
