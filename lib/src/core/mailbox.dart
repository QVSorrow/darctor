import 'dart:async';
import 'dart:collection';

import 'package:darctor/src/api/mailbox.dart';

enum _Policy {
  DropOld,
  DropNew,
}

class BoundedMailbox {

  BoundedMailbox._();

  static Mailbox<T> dropOldest<T>(int size) {
    return _BoundedMailbox(size: size, policy: _Policy.DropOld);
  }

  static Mailbox<T> dropNewest<T>(int size) {
    return _BoundedMailbox(size: size, policy: _Policy.DropNew);
  }


}

class _BoundedMailbox<T> extends Mailbox<T> {
  late final int _maxSize;
  late final _Policy _policy;
  late final Queue<T> _queue;

  final DoubleLinkedQueue<Completer<T>> _pendingQueue = DoubleLinkedQueue();

  var _size = 0;
  var _isActive = true;

  _BoundedMailbox({
    required int size,
    required _Policy policy,
  }) {
    _maxSize = size;
    _policy = policy;
    _queue = ListQueue(size);
  }

  @override
  void enqueue(msg) {
    Future.delayed(Duration(microseconds: 1), () => _enqueue(msg));
  }

  void _enqueue(T msg) {
    if (!_isActive) return;
    if (_size >= _maxSize) {
      if (_policy == _Policy.DropNew) {
        return;
      } else if (_policy == _Policy.DropOld) {
        _queue.removeFirst();
        _queue.add(msg);
      }
    } else {
      if (_pendingQueue.isNotEmpty) {
        _pendingQueue.removeFirst().complete(msg);
      } else {
        _queue.add(msg);
        _size += 1;
      }
    }
  }

  @override
  bool get isActive => _isActive;

  @override
  void close() {
    _isActive = false;
    if (_pendingQueue.isNotEmpty) {
      for (var value in _pendingQueue) {
        value.completeError(MailboxClosed(), StackTrace.current);
      }
      _pendingQueue.clear();
    }
  }

  @override
  Future<T> pop() {
    return _popOld();
  }

  Future<T> _popNew() {
    if (!isActive) {
      return Future.error(MailboxClosed(), StackTrace.current);
    }
    final completer = Completer<T>();
    _pendingQueue.add(completer);
    Zone.current.scheduleMicrotask(() => _popInner());
    return completer.future;
  }

  Future<T> _popOld() {
    if (_queue.isNotEmpty) {
      final t = _queue.removeFirst();
      _size -= 1;
      return Future.value(t);
    } else if (!_isActive) {
      return Future.error(MailboxClosed(), StackTrace.current);
    } else {
      final completer = Completer<T>();
      _pendingQueue.add(completer);
      return completer.future;
    }
  }


  void _popInner() {
    while (_queue.isNotEmpty && _pendingQueue.isNotEmpty) {
      _pendingQueue.removeFirst().complete(_queue.removeFirst());
    }
  }
}

