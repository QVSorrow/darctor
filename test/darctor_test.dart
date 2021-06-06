import 'package:darctor/darctor.dart';
import 'package:darctor/src/api/actor_ref.dart';
import 'package:darctor/src/api/behavior.dart';
import 'package:darctor/src/core/behaviors.dart';
import 'package:darctor/src/core/supervisor_strategy.dart';
import 'package:darctor/src/impl/actor.dart';
import 'package:test/test.dart';

void main() {
  test('ping-pong', () async {
    actorSystemOf(name: 'ping-pong', guardian: Behaviors.setup((context) async {
      final ping = context.spawn('ping', pingPong);
      final pong = context.spawn('pong', pingPong);

      ping.tell(Sender(pong));
      pong.tell(Sender(ping));

      print('heating...');
      ping.tell(Ping(0));
      await Future.delayed(Duration(seconds: 5));
      ping.tell(Done((i) { }));

      print('benchmarking...');
      ping.tell(Ping(0));
      await Future.delayed(Duration(seconds: 10));
      ping.tell(Done((i) {
        print('Total: $i');
        print('Avg: ${i / 10.0} ops/s');
      }));

    }));

    await Future.delayed(Duration(seconds: 20));
  });

  test('simple actor', () async {
    var system = actorSystemOf(
        name: 'root',
        guardian: Behaviors.setup((context) {
          final childA = context.spawn('child A',
              Behaviors.receive<String>((context, message) => print(message)));

          final childB =
              context.spawn('child A', Behaviors.setup((context) async {
            for (var i = 0; i < 10; i++) {
              await Future.delayed(Duration(milliseconds: 200));
              childA.tell('Got: $i');
            }
          }));
        }));
    await Future.delayed(Duration(seconds: 5));
  });

  test('restart actor', () async {
    var system = actorSystemOf(
        name: 'system',
        guardian: Behaviors.setup((context) {
          final childA = context.spawn('child A', Behaviors.setup<String>((context) {
            print("I'm happy actor, just started");
            context.become(
                Behaviors.receive<String>((context, message) {
                  if (message == 'kill') {
                    print("I'm dead");
                    throw message;
                  } else {
                    print(message);
                  }
                })
            );
          }));

          final childB =
              context.spawn('child A', Behaviors.setup((context) async {
            for (var i = 0; i < 10; i++) {
              await Future.delayed(Duration(milliseconds: 200));
              if (i % 3 == 0) {
                childA.tell('kill');
                await Future.delayed(Duration(seconds: 1));
              } else {
                childA.tell('Got: $i');
              }
            }
          }));
        })
        .onChildFailed((context, supervised, error) => SupervisorStrategies.restart)
    );
    await Future.delayed(Duration(seconds: 10));
  });
}


abstract class PingPong {}

class Sender extends PingPong {
  final ActorRef<PingPong> sendTo;

  Sender(this.sendTo);
}

class Ping extends PingPong {
  final int value;

  Ping(this.value);
}

class Done extends PingPong {
  final void Function(int) onDone;

  Done(this.onDone);
}


final pingPong = Behaviors.receive<PingPong>((context, message) {
  if (message is Sender) {
    context.become(pingPongReceive(message.sendTo));
  }
});

Behavior<PingPong> pingPongReceive(ActorRef<PingPong> sendTo) =>
    Behaviors.receive<PingPong>((context, message) {
      if (message is Ping) {
        sendTo.tell(Ping(message.value + 1));
      } else if (message is Done) {
        context.become(finalize(sendTo, message.onDone));
      }
    });

Behavior<PingPong> finalize(
    ActorRef<PingPong> sendTo,
    void Function(int) onDone
    ) => Behaviors.receive<PingPong>((context, message) {
  if (message is Ping) {
    onDone(message.value);
    context.become(pingPongReceive(sendTo));
  }
});