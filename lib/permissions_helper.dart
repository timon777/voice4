import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  /// Запрашивает все необходимые разрешения для правильной работы приложения
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // Список разрешений, которые нужны приложению
    final permissions = [
      Permission.microphone,
      Permission.sms,
      Permission.notification,
    ];

    // Проверяем текущий статус разрешений
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Проверяем, все ли разрешения получены
    bool allGranted = true;
    List<Permission> denied = [];
    
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        denied.add(permission);
      }
    });

    // Если не все разрешения получены, показываем диалог
    if (!allGranted && context.mounted) {
      _showPermissionDialog(context, denied);
      return false;
    }
    
    return true;
  }

  /// Показывает диалог с информацией о недостающих разрешениях
  static void _showPermissionDialog(BuildContext context, List<Permission> denied) {
    // Текст разрешений для отображения пользователю
    final Map<Permission, String> permissionNames = {
      Permission.microphone: 'Микрофон',
      Permission.sms: 'Отправка SMS',
      Permission.notification: 'Уведомления',
    };

    // Формируем список недостающих разрешений
    String missingPermissions = denied
        .map((permission) => permissionNames[permission] ?? permission.toString())
        .join(', ');

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Необходимы разрешения'),
        content: Text(
          'Для работы приложения требуются следующие разрешения: $missingPermissions. '
          'Пожалуйста, предоставьте их в настройках приложения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }
}