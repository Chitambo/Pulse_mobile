class ApiConstants {
  static const String baseUrl = 'http://52.42.96.17/api';
  static const String socketUrl = 'http://52.42.96.17';
  static const String socketPath = '/socket.io';
  static const String uploadsUrl = 'http://52.42.96.17/uploads';

  // Auth
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';
  static const String deviceToken = '/auth/device-token';

  // Resources
  static const String users = '/users';
  static const String roles = '/users/roles';
  static const String departments = '/departments';
  static const String employees = '/employees';
  static const String clients = '/clients';
  static const String projects = '/projects';
  static const String supportTickets = '/support-tickets';
  static const String developmentTasks = '/development-tasks';
  static const String salesLeads = '/sales-leads';
  static const String invoices = '/invoices';
  static const String kpiTemplates = '/kpi/templates';
  static const String kpiScores = '/kpi/scores';
  static const String kpiScorecard = '/kpi/scorecard';
  static const String dailyActivities = '/daily-activities';
  static const String weeklySummaries = '/weekly-summaries';
  static const String notifications = '/notifications';
  static const String documents = '/documents';

  // Dashboard
  static const String dashboardCeo = '/dashboard/ceo';
  static const String dashboardSupport = '/dashboard/support';
  static const String dashboardDeveloper = '/dashboard/developer';
  static const String dashboardMy = '/dashboard/my';

  // Chat — channels & messages
  static const String chatChannels = '/chat/channels';
  static const String chatDm = '/chat/dm';
  static const String chatUsers = '/chat/users';
  static const String chatSearch = '/chat/search';

  // Chat — tasks
  static const String chatTasks = '/chat/tasks';

  // Chat — notification preferences
  static const String chatNotificationPreferences = '/chat/notification-preferences';

  // Chat — reminders
  static const String chatReminders = '/chat/reminders';

  // Dynamic helpers
  static String channelMessages(int channelId) => '/chat/channels/$channelId/messages';
  static String channelRead(int channelId) => '/chat/channels/$channelId/read';
  static String channelUpload(int channelId) => '/chat/channels/$channelId/upload';
  static String channelNotificationLevel(int channelId) => '/chat/channels/$channelId/notification-level';
  static String messageAssign(int messageId) => '/chat/messages/$messageId/assign';
  static String messageRemind(int messageId) => '/chat/messages/$messageId/remind';
  static String taskById(int taskId) => '/chat/tasks/$taskId';

  // Settings
  static const String settings = '/settings';

  // Quotations
  static const String quotations = '/quotations';

  // Expenses
  static const String expenses = '/expenses';

  // Bookkeeping
  static const String bookkeepingSummary = '/bookkeeping/summary';
  static const String bookkeepingMonthly = '/bookkeeping/monthly';
  static const String bookkeepingExpenseBreakdown = '/bookkeeping/expense-breakdown';
  static const String bookkeepingTransactions = '/bookkeeping/transactions';
}
