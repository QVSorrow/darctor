import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/supervisor.dart';

abstract class Behavior<T> {
  void setup(Context<T> context) {}

  void receiveMessage(Context<T> context, T message) {}

  SupervisorStrategy? childFailed(
      Context<T> context, Supervised supervised, Object? error) {
    return null;
  }

  void stopped() {}
}
