import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum FinishSprite { noShadow, wallShadow, robotShadow }

class Finish extends Item<FinishSprite> {
  Finish(int X, int Y) : super(X, Y);

  @override
  Future<void> onLoad() async {
    animations = {
      FinishSprite.noShadow: loadSprite("10_0.png", 1, Vector2(160, 200)),
      FinishSprite.wallShadow: loadSprite("10_1.png", 1, Vector2(160, 200)),
      FinishSprite.robotShadow: loadSprite("10_2.png", 1, Vector2(160, 200)),
    };
    size = Vector2(64, 80);
    anchor = Anchor.bottomCenter;
  }

  @override
  void updateSprite() {
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      current = FinishSprite.wallShadow;
    } else if (game.myWorld.getRobotAt(X + 1, Y, withPlayer: true) != null) {
      current = FinishSprite.robotShadow;
    } else {
      current = FinishSprite.noShadow;
    }
  }
}
