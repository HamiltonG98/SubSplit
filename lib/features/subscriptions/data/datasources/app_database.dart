import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ── Table Definitions ──────────────────────────────────────────

class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().withLength(min: 4, max: 9)();
  RealColumn get totalCost => real()();
  IntColumn get billingDay => integer()();
  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subscriptionId => integer().references(Subscriptions, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Periods extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subscriptionId => integer().references(Subscriptions, #id)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get periodId => integer().references(Periods, #id)();
  IntColumn get memberId => integer().references(Members, #id)();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidAt => dateTime().nullable()();
}

// ── Database ───────────────────────────────────────────────────

@DriftDatabase(tables: [Subscriptions, Members, Periods, Payments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(subscriptions, subscriptions.currency);
      }
    },
  );

  // ── Subscription CRUD ──

  Future<List<Subscription>> getAllSubscriptions() =>
      select(subscriptions).get();

  Future<Subscription> getSubscriptionById(int id) =>
      (select(subscriptions)..where((s) => s.id.equals(id))).getSingle();

  Future<int> insertSubscription(SubscriptionsCompanion entry) =>
      into(subscriptions).insert(entry);

  Future<bool> updateSubscription(SubscriptionsCompanion entry) =>
      update(subscriptions).replace(entry);

  Future<int> removeSubscription(int id) =>
      (delete(subscriptions)..where((s) => s.id.equals(id))).go();

  // ── Member CRUD ──

  Future<List<Member>> getMembersForSubscription(int subscriptionId) => (select(
    members,
  )..where((m) => m.subscriptionId.equals(subscriptionId))).get();

  Future<int> insertMember(MembersCompanion entry) =>
      into(members).insert(entry);

  Future<int> removeMember(int id) =>
      (delete(members)..where((m) => m.id.equals(id))).go();

  Future<void> updateMemberData(int id, String name, double amount) =>
      (update(members)..where((m) => m.id.equals(id))).write(
        MembersCompanion(name: Value(name), amount: Value(amount)),
      );

  Future<void> updateMemberName(int id, String name) => (update(
    members,
  )..where((m) => m.id.equals(id))).write(MembersCompanion(name: Value(name)));

  Future<void> updateAmountForAllMembers(
    int subscriptionId,
    double amount,
  ) async {
    (update(members)..where((m) => m.subscriptionId.equals(subscriptionId)))
        .write(MembersCompanion(amount: Value(amount)));
  }

  Future<int> removeMembersForSubscription(int subscriptionId) => (delete(
    members,
  )..where((m) => m.subscriptionId.equals(subscriptionId))).go();

  // ── Period CRUD ──

  Future<Period?> getOpenPeriod(int subscriptionId) =>
      (select(periods)..where(
            (p) =>
                p.subscriptionId.equals(subscriptionId) &
                p.status.equals('open'),
          ))
          .getSingleOrNull();

  Future<List<Period>> getPeriodsForSubscription(int subscriptionId) =>
      (select(periods)
            ..where((p) => p.subscriptionId.equals(subscriptionId))
            ..orderBy([
              (p) => OrderingTerm(
                expression: p.startDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  Future<int> insertPeriod(PeriodsCompanion entry) =>
      into(periods).insert(entry);

  Future<void> closePeriodById(int periodId) =>
      (update(periods)..where((p) => p.id.equals(periodId))).write(
        const PeriodsCompanion(status: Value('closed')),
      );

  Future<int> removePeriodsForSubscription(int subscriptionId) => (delete(
    periods,
  )..where((p) => p.subscriptionId.equals(subscriptionId))).go();

  // ── Payment CRUD ──

  Future<List<Payment>> getPaymentsForPeriod(int periodId) =>
      (select(payments)..where((p) => p.periodId.equals(periodId))).get();

  Future<int> insertPayment(PaymentsCompanion entry) =>
      into(payments).insert(entry);

  Future<void> togglePaymentStatus(int paymentId, bool isPaid) =>
      (update(payments)..where((p) => p.id.equals(paymentId))).write(
        PaymentsCompanion(
          isPaid: Value(isPaid),
          paidAt: Value(isPaid ? DateTime.now() : null),
        ),
      );

  Future<int> removePaymentsForPeriod(int periodId) =>
      (delete(payments)..where((p) => p.periodId.equals(periodId))).go();

  Future<int> removePaymentsForMember(int memberId) =>
      (delete(payments)..where((p) => p.memberId.equals(memberId))).go();

  // ── Aggregate Queries ──

  /// Count of paid members for a subscription's open period.
  Future<int> getPaidCountForSubscription(int subscriptionId) async {
    final openPeriod = await getOpenPeriod(subscriptionId);
    if (openPeriod == null) return 0;
    final pays = await getPaymentsForPeriod(openPeriod.id);
    return pays.where((p) => p.isPaid).length;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'subscriptions.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
