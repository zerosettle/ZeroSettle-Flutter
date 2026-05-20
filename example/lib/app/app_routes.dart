import 'package:go_router/go_router.dart';

import '../screens/auth/create_user_screen.dart';
import '../screens/habit/add_habit_screen.dart';
import '../screens/habit/habit_detail_screen.dart';
import '../screens/home/home_screen.dart';
import 'routes.dart';

export 'routes.dart';

/// Builds the [GoRouter]. Pass [startAtHome] = true after onboarding has
/// completed so the app skips `/create-user`.
GoRouter buildRouter({required bool startAtHome}) {
  return GoRouter(
    initialLocation: startAtHome ? Routes.home : Routes.createUser,
    routes: [
      GoRoute(
        path: Routes.createUser,
        name: 'create-user',
        builder: (_, _) => const CreateUserScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.addHabit,
        name: 'add-habit',
        builder: (_, _) => const AddHabitScreen(),
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
