import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/checklist_repository.dart';
import '../data/todo_set_repository.dart';
import '../notifications/notification_service.dart';

final todoSetRepositoryProvider = Provider<TodoSetRepository>((ref) => TodoSetRepository());

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) => ChecklistRepository());

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService.instance);
