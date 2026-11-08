import 'package:flutter/widgets.dart';

import '../services/store.dart';

/// Makes the [Store] available to every screen and rebuilds them on changes.
class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child})
    : super(notifier: store);

  static Store of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Reads the store without rebuilding when it changes (for callbacks).
  static Store read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Like [read], but null when there is no store (as in widget tests).
  static Store? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()?.notifier;
}
