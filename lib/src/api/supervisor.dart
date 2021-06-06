import 'package:darctor/src/api/context.dart';
import 'package:darctor/src/api/path.dart';


abstract class SupervisorStrategy {
  void onFailed(Context<Object?> supervisor, Supervised supervised, Object? error);
}


abstract class Supervisor {
    void childFailed(Supervised supervised, Object? error);
    void childStarted(Supervised supervised);
    void childStopped(Supervised supervised);
}


abstract class Supervised {

  Path get path;

  void start();
  void restart();
  void stop();

}