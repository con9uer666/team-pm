import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/fade_in.dart';

/// Aggregate landing page mirroring `frontend/src/views/Collaborate.vue`.
/// Today only the "会议" entry is live; the other three are placeholders to
/// keep parity with the web roadmap. Tapping a placeholder surfaces a toast
/// so users get explicit feedback instead of silent no-op.
class CollaborateScreen extends StatelessWidget {
  const CollaborateScreen({super.key});

  void _comingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 功能开发中，敬请期待')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_Entry>[
      _Entry(
        icon: Icons.event_outlined,
        title: '会议',
        subtitle: '会议安排、签到、纪要',
        color: const Color(0xFF8B5CF6),
        onTap: () => context.push('/meetings'),
      ),
      _Entry(
        icon: Icons.chat_outlined,
        title: '讨论',
        subtitle: '组内讨论（开发中）',
        color: const Color(0xFF94A3B8),
        disabled: true,
        onTap: () => _comingSoon(context, '讨论'),
      ),
      _Entry(
        icon: Icons.menu_book_outlined,
        title: '知识库',
        subtitle: '文档与资料（开发中）',
        color: const Color(0xFF94A3B8),
        disabled: true,
        onTap: () => _comingSoon(context, '知识库'),
      ),
      _Entry(
        icon: Icons.calendar_month_outlined,
        title: '赛程日历',
        subtitle: '比赛与训练安排（开发中）',
        color: const Color(0xFF94A3B8),
        disabled: true,
        onTap: () => _comingSoon(context, '赛程日历'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('协作')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (var i = 0; i < entries.length; i++)
            FadeInUp(
              delay: Duration(milliseconds: 40 * i),
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: entries[i].disabled ? 0.6 : 1.0,
                  child: ListTile(
                    leading: Icon(entries[i].icon, color: entries[i].color),
                    title: Text(entries[i].title),
                    subtitle: Text(entries[i].subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: entries[i].onTap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;
}
