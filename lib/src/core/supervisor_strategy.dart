import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/supervisor.dart';

class SupervisorStrategies {

  static SupervisorStrategy delegate = _Delegate();
  static SupervisorStrategy stop = _Stop();
  static SupervisorStrategy restart = _Restart();
  static SupervisorStrategy restartAll = _RestartAll();

}


class _Delegate extends SupervisorStrategy {
  @override
  void onFailed(Context<Object?> supervisor, Supervised supervised,
      Object? error) {
    throw Exception(error);
  }
}

class _Stop extends SupervisorStrategy {
  @override
  void onFailed(Context<Object?> supervisor, Supervised supervised,
      Object? error) {
    supervised.stop();
  }
}

class _Restart extends SupervisorStrategy {
  @override
  void onFailed(Context<Object?> supervisor, Supervised supervised,
      Object? error) {
    supervised.restart();
  }
}

class _RestartAll extends SupervisorStrategy {
  @override
  void onFailed(Context<Object?> supervisor, Supervised supervised,
      Object? error) {
    for (var child in supervisor.children) {
      child.restart();
    }
  }
}