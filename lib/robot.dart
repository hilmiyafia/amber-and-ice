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
  void updateSprite() {
    if (game.myWorld.getRobotAt(X + 1, Y, withPlayer: true) != null) {
      current = RobotState.robot;
    } else if (game.myWorld.getWallAt(X + 1, Y, type: WallType.visible) != null) {
      current = RobotState.wall;
    } else {
      current = RobotState.empty;
    }
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
