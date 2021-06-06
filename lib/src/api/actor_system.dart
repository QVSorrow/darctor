import 'package:darctor/src/api/actor_ref.dart';
import 'package:darctor/src/api/behavior.dart';

abstract class ActorSystem<GM> {

  ActorRef<GM> get guardian;
  ActorRef<dynamic> get deadLetter;

  Future<void> terminate();
}
