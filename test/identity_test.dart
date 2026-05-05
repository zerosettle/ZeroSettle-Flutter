import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/models/identity.dart';

void main() {
  group('Identity.user', () {
    test('toMap with id, name, and email', () {
      final identity = Identity.user(id: 'u1', name: 'A', email: 'a@b.c');
      expect(identity.toMap(), {
        'type': 'user',
        'id': 'u1',
        'name': 'A',
        'email': 'a@b.c',
      });
    });

    test('toMap with only id (no null keys)', () {
      final identity = Identity.user(id: 'u1');
      final map = identity.toMap();
      expect(map, {'type': 'user', 'id': 'u1'});
      expect(map.containsKey('name'), isFalse);
      expect(map.containsKey('email'), isFalse);
    });

    test('toMap with id and name only', () {
      final identity = Identity.user(id: 'u1', name: 'Alice');
      final map = identity.toMap();
      expect(map, {'type': 'user', 'id': 'u1', 'name': 'Alice'});
      expect(map.containsKey('email'), isFalse);
    });

    test('toMap with id and email only', () {
      final identity = Identity.user(id: 'u1', email: 'a@b.c');
      final map = identity.toMap();
      expect(map, {'type': 'user', 'id': 'u1', 'email': 'a@b.c'});
      expect(map.containsKey('name'), isFalse);
    });
  });

  group('Identity.anonymous', () {
    test('toMap returns only type=anonymous', () {
      final identity = Identity.anonymous();
      expect(identity.toMap(), {'type': 'anonymous'});
    });

    test('toMap has no id/name/email keys', () {
      final identity = Identity.anonymous();
      final map = identity.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('name'), isFalse);
      expect(map.containsKey('email'), isFalse);
    });
  });

  group('Identity.deferred', () {
    test('toMap returns only type=deferred', () {
      final identity = Identity.deferred();
      expect(identity.toMap(), {'type': 'deferred'});
    });

    test('toMap has no id/name/email keys', () {
      final identity = Identity.deferred();
      final map = identity.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('name'), isFalse);
      expect(map.containsKey('email'), isFalse);
    });
  });

  group('Identity factories produce sealed subtypes', () {
    test('Identity.user produces IdentityUser', () {
      final identity = Identity.user(id: 'u1');
      expect(identity, isA<Identity>());
    });

    test('Identity.anonymous produces IdentityAnonymous', () {
      final identity = Identity.anonymous();
      expect(identity, isA<Identity>());
    });

    test('Identity.deferred produces IdentityDeferred', () {
      final identity = Identity.deferred();
      expect(identity, isA<Identity>());
    });
  });
}
