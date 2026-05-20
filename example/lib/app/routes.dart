/// Top-level route names. Used as both `path` and `name` for `go_router`.
///
/// Lives in its own file (separate from `app_routes.dart`, which holds
/// `buildRouter` and imports every screen) so screens can reference route
/// names WITHOUT pulling the screen-import graph into their compile unit.
class Routes {
  Routes._();
  static const createUser = '/create-user';
  static const home = '/';
  static const addHabit = '/add-habit';

  /// Habit detail uses a path parameter: `/habit/123`.
  static String habitDetail(int id) => '/habit/$id';
  static const habitDetailTemplate = '/habit/:id';
}
