import 'package:flame/components.dart';
import 'item.dart';
import 'wall.dart';

enum RobotType { player, hot, cold }
enum RobotState { empty, wall, robot }

class Robot extends UndoableItem<RobotState, RobotType, ({int x, int y})> {
  Robot(super.X, super.Y, super.type);

  @override
  Future<void> onLoad() async {
    animations = {
      RobotState.empty: loadSprite("${type.index}_0.png", 1, Vector2(160, 240)),
      RobotState.wall: loadSprite("${type.index}_1.png", 1, Vector2(160, 240)),
      RobotState.robot: loadSprite("${type.index}_2.png", 1, Vector2(160, 240)),
    };
    current = RobotState.empty;
    size = Vector2(64, 96);
    anchor = Anchor.bottomCenter;
    priorityOffset = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    var index = 0;
    var wall = game.myWorld.getWallAt(X + 1, Y);
    if (X + 1 == game.myWorld.width) {
      index = 0;
    } else if (game.myWorld.player.X == X + 1 && game.myWorld.player.Y == Y) {
      index = 2;
    } else if (game.myWorld.getRobotAt(X + 1, Y) != null) {
      index = 2;
    } else if (wall != null && wall.type != WallType.wall) {
      index = 1;
    }
    current = RobotState.values[index];
  }

  @override
  void record() {
    records.add((x: X, y: Y));
    if (records.length > 3) records.removeAt(0);
  }

  @override
  void undo() {
    records.removeLast();
    X = records.last.x;
    Y = records.last.y;
  }
}
