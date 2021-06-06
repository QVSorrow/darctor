import 'dart:async';

import 'package:darctor/src/api/mailbox.dart';
import 'package:darctor/src/core/mailbox.dart';
import 'package:test/test.dart';


void main() {
  group('basic operations', () {
    test('put values and get values', () {
      final mailbox = BoundedMailbox.dropNewest<int>(10);
      mailbox.enqueue(1);
      mailbox.enqueue(2);
      mailbox.enqueue(3);

      expect(mailbox.pop(), completion(equals(1)));
      expect(mailbox.pop(), completion(equals(2)));
      expect(mailbox.pop(), completion(equals(3)));
    });
    test('get values and put values', () {
      final mailbox = BoundedMailbox.dropNewest<int>(10);
      expect(mailbox.popTimeout(), completion(equals(1)));
      expect(mailbox.popTimeout(), completion(equals(2)));
      expect(mailbox.popTimeout(), completion(equals(3)));

      mailbox.enqueue(1);
      mailbox.enqueue(2);
      mailbox.enqueue(3);
    });
  });

  group('policy drop new', () {
    test('overflowed', () {
      final mailbox = BoundedMailbox.dropNewest<int>(10);
      Iterable.generate(20, (i) => i)
          .forEach((element) => mailbox.enqueue(element));

      Iterable.generate(10, (i) => i).forEach((element) =>
          expect(mailbox.popTimeout(), completion(equals(element))));

      expect(mailbox.popTimeout(), doesNotComplete);
    });
  });

  group('policy drop old', () {
    test('overflowed', () {
      final mailbox = BoundedMailbox.dropOldest<int>(10);
      Iterable.generate(20, (i) => i)
          .forEach((element) => mailbox.enqueue(element));

      Iterable.generate(10, (i) => i + 10).forEach((element) =>
          expect(mailbox.popTimeout(), completion(equals(element))));

      expect(mailbox.popTimeout(), doesNotComplete);
    });
  });
}

extension MailboxPopTimeout<T> on Mailbox<T> {
  Future<T> popTimeout(
          {Duration duration = const Duration(milliseconds: 50)}) =>
      pop().timeout(duration);
}
