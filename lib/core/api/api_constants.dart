class ApiConstants {
  static const String baseUrl = 'https://stage1.tklapp.com/api';
  static const String socketUrl = 'https://stage1.tklapp.com';
  static const String socketPath = '/socket.io';
  static const String uploadsUrl = 'https://stage1.tklapp.com/uploads';

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

  // Chat
  static const String chatChannels = '/chat/channels';
  static const String chatDm = '/chat/dm';
  static const String chatUsers = '/chat/users';
  static const String chatSearch = '/chat/search';

  // Settings
  static const String settings = '/settings';

  // Quotations
  static const String quotations = '/quotations';

  // Expenses
  static const String expenses = '/expenses';

  // Bookkeeping (CEO/admin/accounts only)
  static const String bookkeepingSummary = '/bookkeeping/summary';
  static const String bookkeepingMonthly = '/bookkeeping/monthly';
  static const String bookkeepingExpenseBreakdown = '/bookkeeping/expense-breakdown';
  static const String bookkeepingTransactions = '/bookkeeping/transactions';
}
