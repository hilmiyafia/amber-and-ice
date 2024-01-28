import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum FinishType { normal }
enum FinishState { empty, wall, robot }

class Finish extends Item<FinishState, FinishType> {
  Finish(int X, int Y) : super(X, Y, FinishType.normal);

  @override
  Future<void> onLoad() async {
    animations = {
      FinishState.empty: loadSprite("10_0.png", 1, Vector2(160, 200)),
      FinishState.wall: loadSprite("10_1.png", 1, Vector2(160, 200)),
      FinishState.robot: loadSprite("10_2.png", 1, Vector2(160, 200)),
    };
    current = FinishState.empty;
    size = Vector2(64, 80);
    anchor = Anchor.bottomCenter;
  }

  @override
  void updateSprite() {
    if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      current = FinishState.wall;
    } else if (game.myWorld.getRobotAt(X + 1, Y, withPlayer: true) != null) {
      current = FinishState.robot;
    } else {
      current = FinishState.empty;
    }
  }
}
