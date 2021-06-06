import 'package:darctor/darctor.dart';

final printerBehavior =
Behaviors.receive<String>((context, message) => print(message));

Behavior<String> senderBehavior(ActorRef<String> sendTo) =>
    Behaviors.setup((context) async {
      for (var i = 0; i < 10; i++) {
        await Future.delayed(Duration(milliseconds: 200));
        sendTo.tell('Number: $i');
      }
    });

void main() {
  var system = actorSystemOf(
      name: 'root',
      guardian: Behaviors.setup((context) {
        final printer = context.spawn('printer', printerBehavior);
        context.spawn('sender', senderBehavior(printer));
      }));
}
