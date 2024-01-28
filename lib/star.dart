import 'package:flame/components.dart';
import 'main.dart';

class Star extends SpriteComponent with HasGameRef<MyGame> {
  Vector2 speed;
  double ratio;

  Star(position, this.speed, this.ratio) {
    this.position = position;
  }

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache("11.png"));
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    position += speed * dt;
    if (y > game.myCamera.viewport.size.y) y -= game.myCamera.viewport.size.y;
    if (x > game.myCamera.viewport.size.x) x -= game.myCamera.viewport.size.x;
    if (x < 0) x += game.myCamera.viewport.size.x;
    size = Vector2.all(ratio * (1 - y / game.myCamera.viewport.size.y));
  }
}