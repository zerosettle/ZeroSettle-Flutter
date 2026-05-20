import 'package:go_router/go_router.dart';

import '../screens/auth/create_user_screen.dart';
import '../screens/habit/add_habit_screen.dart';
import '../screens/habit/habit_detail_screen.dart';
import '../screens/home/home_screen.dart';

/// Top-level route names. Used as both `path` and `name` for `go_router`.
class Routes {
  Routes._();
  static const createUser = '/create-user';
  static const home = '/';
  static const addHabit = '/add-habit';
  // Habit detail uses a path parameter: /habit/123
  static String habitDetail(int id) => '/habit/$id';
  static const habitDetailTemplate = '/habit/:id';
}

/// Builds the [GoRouter]. Pass [startAtHome] = true after onboarding has
/// completed so the app skips `/create-user`.
GoRouter buildRouter({required bool startAtHome}) {
  return GoRouter(
    initialLocation: startAtHome ? Routes.home : Routes.createUser,
    routes: [
      GoRoute(
        path: Routes.createUser,
        name: 'create-user',
        builder: (_, __) => const CreateUserScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.addHabit,
        name: 'add-habit',
        builder: (_, __) => const AddHabitScreen(),
      ),
      GoRoute(
        path: Routes.habitDetailTemplate,
        name: 'habit-detail',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return HabitDetailScreen(habitId: id);
        },
      ),
    ],
  );
}
