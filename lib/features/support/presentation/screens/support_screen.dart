import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_card.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick actions
            Row(
              children: [
                _buildAction(context, Icons.bug_report, 'Report\nIssue', () {
                  context.push('/support/report');
                }),
                SizedBox(width: 12.w),
                _buildAction(context, Icons.chat, 'Live\nChat', () {
                  context.push('/support/chat');
                }),
                SizedBox(width: 12.w),
                _buildAction(context, Icons.email, 'Email\nUs', () {
                  context.push('/support/email');
                }),
              ],
            ),
            SizedBox(height: 24.h),

            Text('FAQ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 12.h),

            _buildFaqSection(context, 'Getting Started', [
              _FaqItem('How do I rent a bike?', 'Scan the QR code on any available bike at a station to unlock it. The ride will start automatically.'),
              _FaqItem('What types of vehicles are available?', 'We offer regular bikes, e-bikes, and buggies depending on the station location.'),
              _FaqItem('How do I end a ride?', 'Park the vehicle at any station and tap "End Ride" in the app.'),
            ]),
            SizedBox(height: 12.h),

            _buildFaqSection(context, 'Payments & Subscriptions', [
              _FaqItem('What payment methods are supported?', 'We accept credit/debit cards, UPI, and wallet balance.'),
              _FaqItem('How do subscriptions work?', 'Subscribe to a plan for discounted ride rates. Cancel anytime from your profile.'),
            ]),
            SizedBox(height: 12.h),

            _buildFaqSection(context, 'Troubleshooting', [
              _FaqItem('QR code not scanning?', 'Ensure your camera is clean and steady. Try manual entry of the bike code if scanning fails.'),
              _FaqItem('Bike won\'t unlock?', 'Check your internet connection. If the issue persists, report it to support.'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: MjCard(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 24.w),
              ),
              SizedBox(height: 8.h),
              Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context, String title, List<_FaqItem> items) {
    return MjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
          SizedBox(height: 8.h),
          ...items.map((item) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: 8.h),
                title: Text(item.question, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                children: [Text(item.answer, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))],
              )),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}
