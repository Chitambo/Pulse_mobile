import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_constants.dart';
import '../../widgets/common_widgets.dart';
import '../auth/change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final emp = user.employee;
    final photoUrl = emp?.photo != null
        ? '${ApiConstants.uploadsUrl}/employees/${emp!.photo}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, auth),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 32))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  emp?.fullName ?? user.username,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text('@${user.username}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                StatusChip(label: user.role.name),
              ],
            ),
          ),
          const Divider(height: 32),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  InfoRow(icon: Icons.email, label: 'Email', value: user.email),
                  InfoRow(icon: Icons.shield, label: 'Role', value: user.role.name),
                  if (emp != null) ...[
                    InfoRow(icon: Icons.badge, label: 'Employee #', value: emp.id.toString()),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            onPressed: () => _confirmLogout(context, auth),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
