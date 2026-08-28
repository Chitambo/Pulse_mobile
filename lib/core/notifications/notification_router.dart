import 'package:flutter/material.dart';

import '../../screens/approvals/approvals_screen.dart';
import '../../screens/invoices/invoices_screen.dart';
import '../../screens/support_tickets/support_tickets_screen.dart';
import '../../screens/expenses/expenses_screen.dart';

/// Shared navigator so push/socket notifications can route without a context.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

int? _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

/// Opens the screen a notification points at. Accepts either an
/// AppNotification-shaped map (`entityType`/`entityId`) or FCM `data`.
void openFromNotification(Map<String, dynamic> data) {
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;

  final entityType = (data['entityType'] ?? '').toString();
  final id = _asInt(data['entityId']);

  switch (entityType) {
    case 'ApprovalRequest':
      nav.push(MaterialPageRoute(builder: (_) => const ApprovalsScreen()));
      break;
    case 'SupportTicket':
      nav.push(MaterialPageRoute(
        builder: (_) => id != null ? TicketDetailScreen(ticketId: id) : const SupportTicketsScreen(),
      ));
      break;
    case 'Invoice':
      nav.push(MaterialPageRoute(
        builder: (_) => id != null ? InvoiceDetailScreen(invoiceId: id) : const InvoicesScreen(),
      ));
      break;
    case 'Expense':
      nav.push(MaterialPageRoute(builder: (_) => const ExpensesScreen()));
      break;
    case 'ScheduledPayment':
      // no dedicated screen yet — expenses is the closest home
      nav.push(MaterialPageRoute(builder: (_) => const ExpensesScreen()));
      break;
    default:
      break;
  }
}
