import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/connection_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/trace_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // macOS 窗口初始化
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(960, 680),
    minimumSize: Size(800, 560),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const BlockTraceApp());
}

class BlockTraceApp extends StatelessWidget {
  const BlockTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()..load()),
        ChangeNotifierProvider(create: (_) => TagProvider()..load()),
        ChangeNotifierProxyProvider<ConnectionProvider, TraceProvider>(
          create: (ctx) => TraceProvider(ctx.read<ConnectionProvider>()),
          update: (ctx, conn, prev) => prev ?? TraceProvider(conn),
        ),
      ],
      child: MaterialApp(
        title: 'Block Trace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A6CF7),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
