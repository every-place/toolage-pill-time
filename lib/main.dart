import 'package:flutter/material.dart';

import 'services/reminders.dart';
import 'services/store.dart';
import 'ui/home_screen.dart';
import 'ui/store_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final reminders = Reminders.instance;
  await reminders.init();
  store.onChanged = reminders.reschedule;
  runApp(PillTimeApp(store: store));
}

class PillTimeApp extends StatefulWidget {
  const PillTimeApp({super.key, required this.store});
  final Store store;

  @override
  State<PillTimeApp> createState() => _PillTimeAppState();
}

class _PillTimeAppState extends State<PillTimeApp> {
  @override
  void initState() {
    super.initState();
    // Ask for alarm and notification permission once the first screen is up,
    // then make sure alarms match the current schedule.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Reminders.instance.requestPermissions();
      await Reminders.instance.reschedule(widget.store.statuses());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A3A));
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        title: 'Pill Time',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B8A3A),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
