import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum FinishType { base }
enum FinishState { empty, wall, robot }

class Finish extends Item<FinishState, FinishType> {
  Finish(int X, int Y) : super(X, Y, FinishType.base);

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
  void update(double dt) {
    super.update(dt);
    var index = 0;
    var wall = game.myWorld.getWallAt(X + 1, Y);
    if (X + 1 == game.myWorld.width) {
      index = 0;
    } else if (wall != null && wall.type != WallType.wall) {
      index = 1;
    } else if (game.myWorld.getRobotAt(X + 1, Y) != null) {
      index = 2;
    } else if (game.myWorld.player.X == X + 1 && game.myWorld.player.Y == Y) {
      index = 2;
    }
    current = FinishState.values[index];
  }
}
