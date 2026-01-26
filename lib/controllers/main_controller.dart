import 'package:get/get.dart';

class MainController extends GetxController {
  var currentIndex = 0.obs;

  final List<String> tabTitles = [
    '📄 Documents',
    '📅 Événements',
    '👥 Contacts',
    '📝 Notes',
    '👤 Profil',
  ];

  void changeTab(int index) {
    currentIndex.value = index;
  }

  String get currentTitle => tabTitles[currentIndex.value];
}