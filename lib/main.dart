import 'package:dynamic_color/dynamic_color.dart';
import 'package:email/services/email_service.dart';
import 'package:email/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'mail.dart';
import 'services/haptic_service.dart';
import 'setting.dart';
import 'services/storage_service.dart';

void main() async {
  // Ensure that widget binding is initialized for async main.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize services before running the app.
  await StorageService.instance.init();
  await HapticService.instance.init();
  await ThemeService.instance.init();
  EmailService.instance; // Initialize the email service to start listeners.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to listen to ThemeService for theme changes.
    // This is more efficient than rebuilding the entire app.
    return AnimatedBuilder(
        animation: ThemeService.instance,
        builder: (context, child) {
          final themeService = ThemeService.instance;
          // 默认的紫色主题
          const defaultSeedColor = Colors.deepPurple;

          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightColorScheme;
              ColorScheme darkColorScheme;

              if (themeService.useDynamicColor &&
                  lightDynamic != null &&
                  darkDynamic != null) {
                // 使用系统动态颜色
                lightColorScheme = lightDynamic;
                darkColorScheme = darkDynamic;
              } else {
                // 使用预设的紫色
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: defaultSeedColor,
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: defaultSeedColor,
                  brightness: Brightness.dark,
                );
              }

              return MaterialApp(
                title: '临时邮箱',
                theme: ThemeData(
                  // 启用Material Design 3
                  useMaterial3: true,
                  // 使用Material 3的颜色方案
                  colorScheme: lightColorScheme,
                  // 设置卡片样式
                  cardTheme: const CardThemeData(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  // 设置按钮主题
                  elevatedButtonTheme: const ElevatedButtonThemeData(
                    style: ButtonStyle(
                      elevation: WidgetStatePropertyAll(0),
                      shape: WidgetStatePropertyAll(StadiumBorder()),
                    ),
                  ),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  colorScheme: darkColorScheme,
                  cardTheme: const CardThemeData(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  elevatedButtonTheme: const ElevatedButtonThemeData(
                    style: ButtonStyle(
                      elevation: WidgetStatePropertyAll(0),
                      shape: WidgetStatePropertyAll(StadiumBorder()),
                    ),
                  ),
                ),
                themeMode: themeService.themeMode,
                home: const MyHomePage(),
              );
            },
          );
        });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final _hapticService = HapticService.instance;
  final _emailService = EmailService.instance;

  static const List<String> _widgetTitles = <String>[
    '主页',
    '临时邮箱',
    '设置',
  ];

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      const HomeScreen(),
      const MailPage(),
      const SettingPage(),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      _hapticService.mediumImpact();
      // When user switches to the Mail page, trigger an auto-refresh if needed.
      if (index == 1) {
        // Instead of calling the child's method directly, we notify the service.
        _emailService.triggerMailListRefresh();
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pages are now simpler and state is managed by services.

    return Scaffold(
      appBar: AppBar(
        title: Text(_widgetTitles[_selectedIndex]),
        centerTitle: true,
        actions: [
          // The refresh button's visibility is now controlled by EmailService's state.
          ValueListenableBuilder<String?>(
            valueListenable: _emailService.emailId,
            builder: (context, emailId, child) {
              if (_selectedIndex == 1 && emailId != null) {
                return TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                  onPressed: _emailService.triggerMailListRefresh,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              }
              return const SizedBox.shrink(); // Return an empty widget if not visible.
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: NavigationBar(
          onDestinationSelected: _onItemTapped,
          selectedIndex: _selectedIndex,
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.home_outlined),
              label: '主页',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.mail),
              icon: Icon(Icons.mail_outlined),
              label: '邮箱',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.settings),
              icon: Icon(Icons.settings_outlined),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
