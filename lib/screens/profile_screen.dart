import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
// Note: AuthProvider is assumed to be implemented elsewhere as per instructions

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Profile', style: AppTypography.heading2.copyWith(color: AppColors.onSurface)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.outlineVariant.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
                                child: const Icon(Icons.verified, color: AppColors.secondary, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Alex Morgan', style: AppTypography.heading3.copyWith(color: AppColors.onSurface)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.tertiaryFixed,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: AppColors.tertiary, size: 12),
                                        const SizedBox(width: 4),
                                        Text('Pro Plan', style: AppTypography.bodySmall.copyWith(color: AppColors.tertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('alex.morgan@example.com', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text('Design Team Workspace', style: AppTypography.bodySmall.copyWith(color: AppColors.outline)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.onSurface),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weekly Flow', style: AppTypography.heading3.copyWith(color: AppColors.onSurface)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Top 5% Momentum',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Done', '28', '+14%', AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('On-Time', '94%', null, AppColors.secondary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Streak', '6d', 'Personal best', AppColors.tertiary)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Breakdown', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar('M', 40),
                        _buildBar('T', 60),
                        _buildBar('W', 80, isToday: true),
                        _buildBar('T', 30),
                        _buildBar('F', 50),
                        _buildBar('S', 20),
                        _buildBar('S', 10),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Preferences', style: AppTypography.heading3.copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow('Push Notifications', trailing: Switch(value: true, onChanged: (v) {}, activeColor: AppColors.primary)),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      'Daily Morning Digest',
                      trailing: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(16)),
                            child: Text('08:00 AM', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface)),
                          ),
                          const SizedBox(width: 8),
                          Switch(value: true, onChanged: (v) {}, activeColor: AppColors.primary),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      'Theme Mode',
                      trailing: Container(
                        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(8)),
                              child: Text('Light', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Text('Dark', style: AppTypography.bodySmall.copyWith(color: AppColors.outline)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      'Default Priority',
                      trailing: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.tertiaryFixed, borderRadius: BorderRadius.circular(12)),
                            child: Text('Medium', style: AppTypography.bodySmall.copyWith(color: AppColors.tertiary)),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.outline),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Account & Data', style: AppTypography.heading3.copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Backup & Cloud Sync', style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface)),
                              Text('Last synced 5m ago', style: AppTypography.bodySmall.copyWith(color: AppColors.outline)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Sync Now', style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      'Export Tasks',
                      trailing: const Icon(Icons.open_in_new, color: AppColors.outline, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Session', style: AppTypography.heading3.copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.errorContainer),
                    ),
                    backgroundColor: AppColors.surfaceContainerLowest,
                  ),
                  child: Text(
                    'Log Out',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Text('TaskFlow v2.4.0 • Made with serenity', style: AppTypography.bodySmall.copyWith(color: AppColors.outline)),
                    const SizedBox(height: 4),
                    Text('Build 4829 • All systems operational', style: AppTypography.bodySmall.copyWith(color: AppColors.outline)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String? subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.heading2.copyWith(color: AppColors.onSurface, fontSize: 24)),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                if (subtitle.contains('%'))
                  Text(subtitle, style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
              ]
            ],
          ),
          if (subtitle != null && !subtitle.contains('%')) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.outline, fontSize: 10)),
          ]
        ],
      ),
    );
  }

  Widget _buildBar(String label, double height, {bool isToday = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isToday ? AppColors.primary : AppColors.outline,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(String title, {required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface)),
          trailing,
        ],
      ),
    );
  }
}
