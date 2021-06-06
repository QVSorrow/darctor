
abstract class Mailbox<T> {
  bool get isActive;
  void enqueue(T msg);
  Future<T> pop();
  void close();
}



class MailboxClosed implements Exception {}


