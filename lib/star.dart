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
    anchor = Anchor.center;
    sprite = Sprite(game.images.fromCache("11.png"));
  }

  @override
  void update(double dt) {
    position += speed * dt;
    Vector2 viewportSize = game.myCamera.viewport.size;
    if (y > viewportSize.y) y -= viewportSize.y;
    if (x > viewportSize.x) x -= viewportSize.x;
    if (x < 0) x += viewportSize.x;
    size = Vector2.all(ratio * (1 - y / viewportSize.y));
  }
}