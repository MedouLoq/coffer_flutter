import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Controllers
import 'controllers/vault_controller.dart';
import 'controllers/main_controller.dart';

// Views
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/setup_password_view.dart';
import 'views/unlock_vault_view.dart';
import 'views/main_app_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 ACTION 1: Put it HERE. This runs before the app starts.
  // This ensures it is ALWAYS alive and NEVER killed.
  Get.put(VaultController(), permanent: true);

  runApp(const VaultApp());
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vault Secure',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      initialRoute: '/splash',
      getPages: [
        GetPage(
          name: '/splash',
          page: () => const SplashView(),
        ),
        GetPage(
          name: '/login',
          page: () => const LoginView(),
        ),
        GetPage(
          name: '/register',
          page: () => const RegisterView(),
        ),
        GetPage(
          name: '/setup_password',
          page: () => const SetupPasswordView(),
          // 👇 ACTION 2: REMOVE VaultController binding here
        ),
        GetPage(
          name: '/unlock_vault',
          page: () => UnlockVaultView(),
          // 👇 ACTION 3: REMOVE VaultController binding here too!
          // We don't need it because we already created it in main()
        ),
        GetPage(
          name: '/main',
          page: () => MainAppView(),
          binding: BindingsBuilder(() {
            // 👇 ACTION 4: REMOVE VaultController here too.
            // ONLY keep MainController
            Get.lazyPut(() => MainController());
          }),
        ),
      ],
    );
  }
}
