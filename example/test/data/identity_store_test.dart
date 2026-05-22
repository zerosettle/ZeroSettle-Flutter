import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';

void main() {
  group('SavedIdentity', () {
    test('toMap / fromMap round-trips', () {
      const identity = SavedIdentity(userId: 'u_1', displayName: 'Alice');
      final restored = SavedIdentity.fromMap(identity.toMap());
      expect(restored, identity);
    });

    test('equality and hashCode', () {
      const a = SavedIdentity(userId: 'u_1', displayName: 'Alice');
      const b = SavedIdentity(userId: 'u_1', displayName: 'Alice');
      const c = SavedIdentity(userId: 'u_1', displayName: 'Bob');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('IdentityStore — basics', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts empty', () async {
      final store = await IdentityStore.create();
      expect(store.identitiesFor('local'), isEmpty);
      expect(store.activeIdentityFor('local'), isNull);
    });

    test('upsert adds an identity', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      expect(store.identitiesFor('local'),
          [const SavedIdentity(userId: 'u_1', displayName: 'Alice')]);
    });

    test('upsert updates an existing identity by userId', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alicia'),
      );
      expect(store.identitiesFor('local'),
          [const SavedIdentity(userId: 'u_1', displayName: 'Alicia')]);
    });

    test('setActive resolves the active identity', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.setActive('local', 'u_1');
      expect(store.activeIdentityFor('local'),
          const SavedIdentity(userId: 'u_1', displayName: 'Alice'));
    });

    test('setActive is a no-op for an unknown userId', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.setActive('local', 'u_unknown');
      expect(store.activeIdentityFor('local'), isNull);
    });

    test('clearActive keeps the identity but drops the active marker',
        () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.setActive('local', 'u_1');
      await store.clearActive('local');
      expect(store.activeIdentityFor('local'), isNull);
      expect(store.identitiesFor('local'), hasLength(1));
    });

    test('removeIdentity drops it and clears active if it was active',
        () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_2', displayName: 'Bob'),
      );
      await store.setActive('local', 'u_1');
      await store.removeIdentity('local', 'u_1');
      expect(store.identitiesFor('local'),
          [const SavedIdentity(userId: 'u_2', displayName: 'Bob')]);
      expect(store.activeIdentityFor('local'), isNull);
    });

    test('removeIdentity keeps active if a different identity was active',
        () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_2', displayName: 'Bob'),
      );
      await store.setActive('local', 'u_2');
      await store.removeIdentity('local', 'u_1');
      expect(store.activeIdentityFor('local'),
          const SavedIdentity(userId: 'u_2', displayName: 'Bob'));
    });
  });

  group('IdentityStore — per-environment isolation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('identities and active selection are isolated per env', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_local', displayName: 'Local User'),
      );
      await store.upsertIdentity(
        'staging',
        const SavedIdentity(userId: 'u_staging', displayName: 'Staging User'),
      );
      await store.setActive('local', 'u_local');
      await store.setActive('staging', 'u_staging');

      expect(store.identitiesFor('local'), hasLength(1));
      expect(store.identitiesFor('staging'), hasLength(1));
      expect(store.activeIdentityFor('local')?.userId, 'u_local');
      expect(store.activeIdentityFor('staging')?.userId, 'u_staging');

      // Removing from one env does not touch the other.
      await store.removeIdentity('local', 'u_local');
      expect(store.identitiesFor('local'), isEmpty);
      expect(store.identitiesFor('staging'), hasLength(1));
    });
  });

  group('IdentityStore — persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('survives a reload via SharedPreferences', () async {
      final store = await IdentityStore.create();
      await store.upsertIdentity(
        'local',
        const SavedIdentity(userId: 'u_1', displayName: 'Alice'),
      );
      await store.setActive('local', 'u_1');

      // Recreate from the same backing store — data must persist.
      final reloaded = await IdentityStore.create();
      expect(reloaded.identitiesFor('local'),
          [const SavedIdentity(userId: 'u_1', displayName: 'Alice')]);
      expect(reloaded.activeIdentityFor('local')?.userId, 'u_1');
    });
  });

  group('IdentityStore — legacy migration', () {
    test('seeds a legacy UserPrefs identity into the given env', () async {
      SharedPreferences.setMockInitialValues({
        'userId': 'u_legacy',
        'displayName': 'Ryan Flutter Android',
      });
      final legacyPrefs = await UserPrefs.create();
      final store = await IdentityStore.create(
        legacyPrefs: legacyPrefs,
        legacyEnvId: 'local',
      );

      expect(store.identitiesFor('local'), [
        const SavedIdentity(
          userId: 'u_legacy',
          displayName: 'Ryan Flutter Android',
        ),
      ]);
      expect(store.activeIdentityFor('local')?.userId, 'u_legacy');
    });

    test('migration result persists across reloads', () async {
      SharedPreferences.setMockInitialValues({
        'userId': 'u_legacy',
        'displayName': 'Ryan Flutter Android',
      });
      final legacyPrefs = await UserPrefs.create();
      await IdentityStore.create(
        legacyPrefs: legacyPrefs,
        legacyEnvId: 'local',
      );

      // A reload without legacy args must still see the migrated identity.
      final reloaded = await IdentityStore.create();
      expect(reloaded.activeIdentityFor('local')?.userId, 'u_legacy');
    });

    test('migration falls back to userId when displayName is absent',
        () async {
      SharedPreferences.setMockInitialValues({'userId': 'u_legacy'});
      final legacyPrefs = await UserPrefs.create();
      final store = await IdentityStore.create(
        legacyPrefs: legacyPrefs,
        legacyEnvId: 'local',
      );
      expect(store.activeIdentityFor('local')?.displayName, 'u_legacy');
    });

    test('no migration when there is no legacy userId', () async {
      SharedPreferences.setMockInitialValues({});
      final legacyPrefs = await UserPrefs.create();
      final store = await IdentityStore.create(
        legacyPrefs: legacyPrefs,
        legacyEnvId: 'local',
      );
      expect(store.identitiesFor('local'), isEmpty);
    });

    test('does not migrate over an already-populated store', () async {
      // First: a populated store.
      SharedPreferences.setMockInitialValues({});
      final first = await IdentityStore.create();
      await first.upsertIdentity(
        'staging',
        const SavedIdentity(userId: 'u_existing', displayName: 'Existing'),
      );

      // Now a legacy userId appears — migration must NOT run because the
      // store is no longer empty.
      await SharedPreferences.getInstance()
          .then((p) => p.setString('userId', 'u_legacy'));
      final legacyPrefs = await UserPrefs.create();
      final reloaded = await IdentityStore.create(
        legacyPrefs: legacyPrefs,
        legacyEnvId: 'local',
      );
      expect(reloaded.identitiesFor('local'), isEmpty);
      expect(reloaded.identitiesFor('staging'), hasLength(1));
    });
  });
}
