import 'package:darctor/src/api/actor_system.dart';
import 'package:darctor/src/api/behavior.dart';
import 'package:darctor/src/api/interceptor.dart';
import 'package:darctor/src/api/supervisor.dart';

import 'actor_ref.dart';

abstract class Context<T> {
  ActorRef<T> get self;
  ActorSystem get system;

  Iterable<Supervised> get children;

  ActorRef<R> spawn<R>(String name, Behavior<R> behavior,
      [List<Interceptor<R>>? interceptors]);

  void become(Behavior<T> newBehavior);
}
