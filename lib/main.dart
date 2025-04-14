import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:vibration/vibration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(),
  );

  FlutterBackgroundService().start();

  runApp(const MyApp());
}

void onStart(ServiceInstance service) async {
  final speech = SpeechToText();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await speech.initialize();
  await speech.listen(
    onResult: (result) {
      final text = result.recognizedWords.toLowerCase();
      if (text.contains("помогите")) {
        flutterLocalNotificationsPlugin.show(
          0,
          'Тревога',
          'Обнаружено слово помощи!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'alert',
              'Alert',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'alarm',
            ),
          ),
        );
        sendEmergencySms();
        triggerVibration();
      }
    },
    listenMode: ListenMode.dictation,
    cancelOnError: false,
    partialResults: true,
  );
}

void sendEmergencySms() async {
  const String message = "Сигнал тревоги от ребенка!";
  const List<String> recipients = ["+77001234567"];
  try {
    await sendSMS(message: message, recipients: recipients, sendDirect: true);
  } catch (e) {
    debugPrint("Ошибка отправки SMS: \$e");
  }
}

void triggerVibration() async {
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(pattern: [500, 1000, 500, 2000]);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Ожидание команды помощи...')),
      ),
    );
  }
}
