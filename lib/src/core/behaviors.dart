import 'package:darctor/src/api/Functions.dart';
import 'package:darctor/src/api/behavior.dart';
import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/supervisor.dart';

class Behaviors {
  Behaviors._();

  static SetupBehavior<T> setup<T>(Setup<T> onSetup) => SetupBehavior(onSetup);

  static Behavior<T> receive<T>(ReceiveMessage<T> onReceive) =>
      _CompositeBehavior(onReceiveMessage: onReceive);
}

class SetupBehavior<T> extends Behavior<T> {
  final Setup<T> _onSetup;

  SetupBehavior(this._onSetup);

  @override
  void setup(Context<T> context) => _onSetup.call(context);

  Behavior<T> onChildFailed(ChildFailed<T> f) {
    return _CompositeBehavior(
      onSetup: _onSetup,
      onChildFailed: f,
    );
  }
}

class _CompositeBehavior<T> extends Behavior<T> {
  late final Setup<T>? _onSetup;
  late final ReceiveMessage<T>? _onReceiveMessage;
  late final ChildFailed<T>? _onChildFailed;

  _CompositeBehavior({
    Setup<T>? onSetup,
    ReceiveMessage<T>? onReceiveMessage,
    ChildFailed<T>? onChildFailed,
  }) {
    _onSetup = onSetup;
    _onReceiveMessage = onReceiveMessage;
    _onChildFailed = onChildFailed;
  }

  @override
  void setup(Context<T> context) => _onSetup?.call(context);

  @override
  void receiveMessage(Context<T> context, T message) =>
      _onReceiveMessage?.call(context, message);

  @override
  SupervisorStrategy? childFailed(
      Context<T> context, Supervised supervised, Object? error) {
    return _onChildFailed?.call(context, supervised, error);
  }
}
