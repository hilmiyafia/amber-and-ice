import 'package:flame/components.dart';
import 'main.dart';

class Item<T1, T2> extends SpriteAnimationGroupComponent<T1> with HasGameRef<MyGame> {
  double timer = 1;
  double start = -1000;
  double stop = -1000;
  int X, Y;
  T2 type;
  int priorityOffset = 0;

  Item(this.X, this.Y, this.type);

  @override
  void update(double dt) {
    super.update(dt);
    if (timer < 1) {
      timer += 4 * dt;
      if (timer >= 1) {
        timer = 1;
        game.myWorld.counter--;
      }
    }
    x = X * 64;
    if (game.myWorld.animating) {
      y = start + (stop - start) * timer;
    } else {
      y = Y * 48;
    }
    priority = Y * 2 + priorityOffset;
  }

  void fadeIn(int delay) {
    Future.delayed(Duration(milliseconds: delay), () {
      start = game.myCamera.visibleWorldRect.top - 64;
      stop = Y * 48;
      timer = 0;
    });
  }

  void fadeOut(int delay) {
    Future.delayed(Duration(milliseconds: delay), () {
      start = Y * 48;
      stop = game.myCamera.visibleWorldRect.top - 64;
      timer = 0;
    });
  }

  SpriteAnimation loadSprite(name, amount, size) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache(name),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: 0.25,
        textureSize: size,
      ),
    );
  }
}

class UndoableItem<T1, T2, T3> extends Item<T1, T2> {
  List<T3> records = List<T3>.empty(growable: true);

  UndoableItem(super.X, super.Y, super.type);

  void record() {}

  void undo() {}
}