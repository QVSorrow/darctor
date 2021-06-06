import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/supervisor.dart';

typedef Setup<T> = void Function(Context<T> context);
typedef ReceiveMessage<T> = void Function(Context<T> context, T message);
typedef ChildFailed<T> = SupervisorStrategy? Function(
    Context<T> context, Supervised supervised, Object? error);
