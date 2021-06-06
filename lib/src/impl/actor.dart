import 'dart:async';
import 'dart:collection';

import 'package:darctor/src/api/Functions.dart';
import 'package:darctor/src/api/actor_ref.dart';
import 'package:darctor/src/api/actor_system.dart';
import 'package:darctor/src/api/behavior.dart';
import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/interceptor.dart';
import 'package:darctor/src/api/mailbox.dart';
import 'package:darctor/src/api/path.dart';
import 'package:darctor/src/api/signals.dart';
import 'package:darctor/src/api/supervisor.dart';
import 'package:darctor/src/core/mailbox.dart';
import 'package:darctor/src/core/supervisor_strategy.dart';

class _Actor<Message> implements Supervisor, Supervised, Context<Message> {
  final List<Supervised> _children = List.empty(growable: true);

  late final List<Interceptor<Message>>? _interceptors;
  late final Behavior<Message> _initialBehavior;
  late final Supervisor? _supervisor;
  late final Mailbox<Message> _mailbox;
  late final ActorRef<Message> _self;
  late final Path _path;
  late final Zone _actorZone;
  late final ActorSystem _system;

  late Behavior<Message> _currentBehavior;
  late Setup<Message> _composedSetupHandler;
  late ReceiveMessage<Message> _composedMessageHandler;
  late ChildFailed<Message> _composedChildFailureHandler;

  _Actor({
    required String name,
    required Behavior<Message> initialBehavior,
    required Zone parentZone,
    ActorSystem? system,
    Path? parentPath,
    List<Interceptor<Message>>? interceptors,
    Supervisor? supervisor,
  }) {
    if (system != null) _system = system;
    _interceptors = interceptors;
    _initialBehavior = initialBehavior;
    _supervisor = supervisor;
    _path = parentPath == null ? _RootPath(name) : _PathImpl(name, parentPath);
    _currentBehavior = _initialBehavior;
    _actorZone = _createZone(parentZone);
    _mailbox = BoundedMailbox.dropNewest<Message>(10);
    _self = _ActorRefImpl(_mailbox);
    _prepareInterceptors();
  }

  @override
  void become(Behavior<Message> newBehavior) => _changeBehavior(newBehavior);

  @override
  ActorRef<Message> get self => _self;

  @override
  ActorRef<R> spawn<R>(String name, Behavior<R> behavior,
      [List<Interceptor<R>>? interceptors]) {
    for (var child in children) {
      if (child.path.name == name) {
        throw Exception('Child with name $name already exists');
      }
    }
    final actor = _Actor<R>(
        name: name,
        initialBehavior: behavior,
        parentZone: _actorZone,
        system: _system,
        parentPath: _path,
        interceptors: interceptors,
        supervisor: this);
    final ref = actor.self;
    actor.start();
    return ref;
  }

  @override
  ActorSystem get system => _system;

  @override
  Iterable<Supervised> get children => _children;

  @override
  void start() => _actorZone.run(_mainLoop);

  @override
  void stop() => _actorZone.run(() async {
        _mailbox.close();
        for (var child in _children) {
          child.stop();
        }
        await Stream.periodic(Duration(milliseconds: 1))
            .map((event) => children.isEmpty)
            .takeWhile((isEmpty) => !isEmpty)
            .last;
        _currentBehavior.stopped();
      });

  @override
  void restart() {
    _actorZone.run(() {
      _changeBehavior(_initialBehavior);
    });
  }

  @override
  void childFailed(Supervised supervised, Object? error) => _actorZone.run(() {
        try {
          final strategy =
              _composedChildFailureHandler(this, supervised, error) ??
                  SupervisorStrategies.delegate;
          strategy.onFailed(this, supervised, error);
        } catch (e) {
          _failWithError(e);
        }
      });

  @override
  void childStarted(Supervised supervised) =>
      _actorZone.run(() => _children.add(supervised));

  @override
  void childStopped(Supervised supervised) => _actorZone.run(
      () => _children.removeWhere((child) => child.path == supervised.path));

  @override
  Path get path => _path;

  void _handleSetup(Context<Message> context) {
    _currentBehavior.setup(context);
  }

  void _handleMessage(Context<Message> context, Message message) {
    _currentBehavior.receiveMessage(context, message);
  }

  SupervisorStrategy? _handleChildFailure(
      Context<Message> context, Supervised supervised, Object? error) {
    return _currentBehavior.childFailed(context, supervised, error);
  }

  void _changeBehavior(Behavior<Message> behavior) =>
      _actorZone.run(() => _runCaching(() {
            _currentBehavior = behavior;
            _composedSetupHandler(this);
          }));

  void _mainLoop() async {
    _changeBehavior(_currentBehavior);
    while (_mailbox.isActive) {
      try {
        final message = await _mailbox.pop();
        _composedMessageHandler(this, message);
      } on MailboxClosed {
        break;
      } catch (e) {
        _failWithError(e);
      }
    }
  }

  void _prepareInterceptors() {
    var interceptors = _interceptors;
    if (interceptors != null && interceptors.isNotEmpty) {
      // Setup
      _composedSetupHandler =
          interceptors.fold<Setup<Message>>(_handleSetup, (func, element) {
        return element.toSetupFunction(func);
      });
      // Message
      _composedMessageHandler = interceptors
          .fold<ReceiveMessage<Message>>(_handleMessage, (func, element) {
        return element.toMessageFunction(func);
      });
      // Child failure
      _composedChildFailureHandler = interceptors
          .fold<ChildFailed<Message>>(_handleChildFailure, (func, element) {
        return element.toChildFailedFunction(func);
      });
    } else {
      // Setup
      _composedSetupHandler = _handleSetup;
      // Message
      _composedMessageHandler = _handleMessage;
      // Child failure
      _composedChildFailureHandler = _handleChildFailure;
    }
  }

  void _runCaching(void Function() f) {
    try {
      f();
    } catch (e) {
      _failWithError(e);
    }
  }

  Zone _createZone(Zone parent) {
    return parent.fork(
      specification: ZoneSpecification(),
    );
  }

  void _failWithError(Object? error) {
    _actorZone.run(() {
      _supervisor?.childFailed(this, error);
    });
  }
}

extension _InterceptorToFunction<Message> on Interceptor<Message> {
  Setup<Message> toSetupFunction(Setup<Message> previous) {
    return (c) => aroundSetup(c, previous);
  }

  ReceiveMessage<Message> toMessageFunction(ReceiveMessage<Message> previous) {
    return (c, m) => aroundMessage(c, m, previous);
  }

  ChildFailed<Message> toChildFailedFunction(ChildFailed<Message> previous) {
    return (c, s, e) => aroundChildFailed(c, s, e, previous);
  }
}

class _ActorRefImpl<T> extends ActorRef<T> {
  final Mailbox<T> _mailbox;

  _ActorRefImpl(this._mailbox);

  @override
  void tell(T msg) {
    _mailbox.enqueue(msg);
  }
}

class _PathImpl extends Path {
  final String _name;
  final Path _parent;

  _PathImpl(this._name, this._parent);

  @override
  String get name => _name;

  @override
  Path get parent => _parent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PathImpl &&
          runtimeType == other.runtimeType &&
          _name == other._name &&
          _parent == other._parent;

  @override
  int get hashCode => _name.hashCode ^ _parent.hashCode;

  @override
  String toString() {
    return '$_parent/$_name';
  }
}

class _RootPath extends Path {
  final String _name;

  _RootPath(this._name);

  @override
  // TODO: implement name
  String get name => throw UnimplementedError();

  @override
  Path get parent => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RootPath &&
          runtimeType == other.runtimeType &&
          _name == other._name;

  @override
  int get hashCode => _name.hashCode;

  @override
  String toString() {
    return '$_name';
  }
}

class _ActorSystemImpl<GM> extends Behavior<_RootGuardianCommand>
    implements ActorSystem<GM> {
  final String _systemGuardianName = 'system';
  final String _userGuardianName = 'user';
  final String _deadLetterActorName = 'dead_letters';

  late final _Actor<_RootGuardianCommand> _rootActor;
  late final Behavior<GM> _userGuardianBehavior;

  late final ActorRef<_SystemGuardianCommand> _systemGuardianRef;
  late final ActorRef<GM> _userGuardianRef;

  _ActorSystemImpl({required String name, required Behavior<GM> guardian}) {
    _userGuardianBehavior = guardian;
    _rootActor = _Actor<_RootGuardianCommand>(
      name: name,
      initialBehavior: this,
      parentZone: Zone.current,
      system: this,
    );
    _rootActor.start();
  }

  @override
  void setup(Context<_RootGuardianCommand> context) {
    _systemGuardianRef = context.spawn(
        _systemGuardianName, _SystemGuardianBehavior(context.self));
    _userGuardianRef = context.spawn(_userGuardianName, _userGuardianBehavior);
  }

  @override
  void receiveMessage(
      Context<_RootGuardianCommand> context, _RootGuardianCommand message) {
    if (message is _SystemGuardianResponseRootCommand) {
      final response = message.response;
      if (response is _SystemActorSpawned<String>) {
        response.name;
      }
    }
  }

  @override
  ActorRef<GM> get guardian => _userGuardianRef;

  @override
  ActorRef get deadLetter => throw UnimplementedError();

  @override
  Future<void> terminate() {
    // TODO: implement terminate
    throw UnimplementedError();
  }
}

ActorSystem actorSystemOf<T>(
    {required String name,
    required Behavior<T> guardian,
    List<Interceptor>? interceptors}) {
  return _ActorSystemImpl(name: name, guardian: guardian);
}

//////////////////////////////// Root guardian ////////////////////////////////

abstract class _RootGuardianCommand {}

class _SystemGuardianResponseRootCommand extends _RootGuardianCommand {
  final _SystemGuardianResponse response;

  _SystemGuardianResponseRootCommand(this.response);
}

/////////////////////////////// System guardian ///////////////////////////////

/// Requests
abstract class _SystemGuardianCommand {}

class _SpawnSystemActor<T> extends _SystemGuardianCommand {
  _SpawnSystemActor(this.name, this.behavior);

  final String name;
  final Behavior<T> behavior;
}

/// Responses
abstract class _SystemGuardianResponse {}

class _SystemActorSpawned<T> extends _SystemGuardianResponse {
  _SystemActorSpawned(this.name, this.ref);

  final String name;
  final ActorRef<T> ref;
}

class _SystemGuardianBehavior extends Behavior<_SystemGuardianCommand> {
  final ActorRef<_RootGuardianCommand> _root;

  _SystemGuardianBehavior(this._root);

  @override
  void receiveMessage(
      Context<_SystemGuardianCommand> context, _SystemGuardianCommand message) {
    if (message is _SpawnSystemActor) {
      var ref = context.spawn(message.name, message.behavior);
      _root.tell(_SystemGuardianResponseRootCommand(
          _SystemActorSpawned(message.name, ref)));
    }
  }

  @override
  SupervisorStrategy? childFailed(Context<_SystemGuardianCommand> context,
      Supervised supervised, Object? error) {
    return SupervisorStrategies.restart;
  }
}
