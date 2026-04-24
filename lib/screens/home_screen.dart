import 'package:flutter/material.dart';
import '../utils/localization.dart';
import '../providers/locale_provider.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/environment_security.dart';
import 'qr_generator_screen.dart';
import 'barcode_generator_screen.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'batch_generator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _historyRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSecurityChecks();
    });
  }

  Future<void> _runSecurityChecks() async {
    final results = await EnvironmentSecurity.checkEnvironment();
    if (!mounted) return;

    final langCode = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    await EnvironmentSecurity.showEnvironmentWarnings(context, results, langCode: langCode);
  }

  @override
  Widget build(BuildContext context) {
    final loc = (String key) => AppLocalizations.of(context, key);

    final tabs = [
      const QrGeneratorScreen(), // QR Generator Screen
      const BarcodeGeneratorScreen(), // Barcode Generator Screen
      ScannerScreen(isActive: _currentIndex == 2), // Scanner Screen
      HistoryScreen(refreshKey: _historyRefreshKey), // History Screen
      _buildSettingsTab(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc('app_name')),
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
            if (idx == 3) _historyRefreshKey++;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_2),
            label: loc('qr_short'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.view_column),
            label: loc('barcode_short'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.document_scanner),
            label: loc('scanner'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: loc('history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: loc('settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = (String key) => AppLocalizations.of(context, key);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        SwitchListTile(
          value: themeProvider.themeMode == ThemeMode.dark,
          onChanged: (val) {
            themeProvider.toggleTheme(val);
          },
          title: Text(loc('dark_mode')),
          secondary: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(loc('language')),
          trailing: DropdownButton<String>(
            value: localeProvider.locale.languageCode,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    Image.asset('assets/flags/uk.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    const Text('English'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'ar',
                child: Row(
                  children: [
                    Image.asset('assets/flags/algeria.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    const Text('العربية'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'fr',
                child: Row(
                  children: [
                    Image.asset('assets/flags/france.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    const Text('Français'),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                localeProvider.setLocale(Locale(val));
              }
            },
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.batch_prediction),
          title: Text(loc('batch_generation')),
          subtitle: Text(loc('csv_support')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchGeneratorScreen()));
          },
        ),
      ],
    );
  }
}
