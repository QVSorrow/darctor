import 'package:darctor/src/api/Functions.dart';
import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/supervisor.dart';

abstract class Interceptor<Message> {
  void aroundSetup(
    Context<Message> context,
    Setup<Message> start,
  ) =>
      start(context);

  void aroundMessage(
    Context<Message> context,
    Message message,
    ReceiveMessage<Message> receiveMessage,
  ) =>
      receiveMessage(context, message);

  SupervisorStrategy? aroundChildFailed(
    Context<Message> context,
    Supervised supervised,
    Object? error,
    ChildFailed<Message> childFailed,
  ) =>
      childFailed(context, supervised, error);
}
