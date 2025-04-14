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

  // Инициализация фонового сервиса
  await initializeService();

  runApp(const MyApp());
}

// Инициализация фонового сервиса
Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: 'voice_alert_channel',
      initialNotificationTitle: 'Голосовое оповещение',
      initialNotificationContent: 'Приложение прослушивает команды помощи',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
  
  service.startService();
}

// Функция, запускаемая в фоновом режиме
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final speech = SpeechToText();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Канал уведомлений для Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alert', // id
    'Оповещения о помощи', // name
    description: 'Канал для уведомлений о призывах о помощи', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Инициализация распознавания речи
  if (await speech.initialize()) {
    speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        if (text.contains("помогите")) {
          flutterLocalNotificationsPlugin.show(
            0,
            'Тревога',
            'Обнаружено слово помощи!',
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
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

  // Поддержка периодических проверок для сервиса
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Периодическое обновление для поддержания работы сервиса
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Голосовое оповещение активно",
          content: "Приложение прослушивает команды помощи",
        );
      }
    }
  });
}

void sendEmergencySms() async {
  const String message = "Сигнал тревоги от ребенка!";
  const List<String> recipients = ["+77001234567"];
  try {
    await sendSMS(message: message, recipients: recipients, sendDirect: true);
  } catch (e) {
    debugPrint("Ошибка отправки SMS: $e");
  }
}

void triggerVibration() async {
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(pattern: [500, 1000, 500, 2000]);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Ожидание команды помощи...';
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    setState(() {
      _isServiceRunning = isRunning;
      _status = isRunning 
          ? 'Сервис активен: ожидание команды помощи...' 
          : 'Сервис остановлен. Нажмите для запуска';
    });
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    if (_isServiceRunning) {
      await service.invoke('stopService');
    } else {
      await service.startService();
    }
    await _checkServiceStatus();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Голосовое оповещение'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isServiceRunning ? Icons.mic : Icons.mic_off,
                size: 80,
                color: _isServiceRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _toggleService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServiceRunning ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30, 
                    vertical: 15,
                  ),
                ),
                child: Text(
                  _isServiceRunning ? 'Остановить сервис' : 'Запустить сервис',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}