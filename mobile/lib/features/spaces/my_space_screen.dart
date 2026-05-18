import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/dio_client.dart';
import '../../core/org/users_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/fade_in.dart';
import '../../shared/widgets/press_scale.dart';
import 'data/spaces_api.dart';

enum _SpaceTab { mine, all }

class MySpaceScreen extends ConsumerStatefulWidget {
  const MySpaceScreen({super.key});

  @override
  ConsumerState<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends ConsumerState<MySpaceScreen> {
  _SpaceTab _tab = _SpaceTab.mine;

  bool _canSeeAll() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;
    return user.isSuperAdmin || user.roleLevel >= 5;
  }

  @override
  Widget build(BuildContext context) {
    final canSeeAll = _canSeeAll();
    final mineAsync = ref.watch(mySpacesProvider);
    final orgAsync = ref.watch(orgStructureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的空间')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySpacesProvider);
          ref.invalidate(orgStructureProvider);
          await ref.read(mySpacesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (canSeeAll) ...[
              FadeInUp(
                child: Center(
                  child: SegmentedButton<_SpaceTab>(
                    segments: const [
                      ButtonSegment(value: _SpaceTab.mine, label: Text('我的')),
                      ButtonSegment(value: _SpaceTab.all, label: Text('全部')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) =>
                        setState(() => _tab = s.first),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_tab == _SpaceTab.mine)
              _MineSection(async: mineAsync)
            else
              _AllSection(async: orgAsync),
          ],
        ),
      ),
    );
  }
}

class _MineSection extends StatelessWidget {
  const _MineSection({required this.async});
  final AsyncValue<MySpaces> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(dioErrorMessage(e, '加载失败'),
            style: TextStyle(color: AppTheme.dangerFg)),
      ),
      data: (my) {
        if (my.groups.isEmpty && my.divisions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 120),
            child: Center(
              child: Text('暂未加入任何兵种 / 技术组',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (my.divisions.isNotEmpty)
              _Section(
                title: '兵种组',
                cards: my.divisions,
                scope: 'division',
              ),
            if (my.divisions.isNotEmpty && my.groups.isNotEmpty)
              const SizedBox(height: 16),
            if (my.groups.isNotEmpty)
              _Section(
                title: '技术组',
                cards: my.groups,
                scope: 'group',
              ),
          ],
        );
      },
    );
  }
}

class _AllSection extends StatelessWidget {
  const _AllSection({required this.async});
  final AsyncValue<OrgStructure> async;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(dioErrorMessage(e, '加载失败'),
            style: TextStyle(color: AppTheme.dangerFg)),
      ),
      data: (org) {
        final divCards = [
          for (final d in org.divisions)
            SpaceCard(
              id: d.id,
              name: d.name,
              leaderIds: d.leaderIds,
              memberCount: org.usersInDivision(d.id).length,
            ),
        ];
        final groupCards = [
          for (final g in org.groups)
            SpaceCard(
              id: g.id,
              name: g.name,
              leaderIds: g.leaderIds,
              memberCount: org.usersInGroup(g.id).length,
            ),
        ];
        if (divCards.isEmpty && groupCards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 120),
            child: Center(
              child: Text('暂无任何兵种 / 技术组',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (divCards.isNotEmpty)
              _Section(
                title: '兵种组',
                cards: divCards,
                scope: 'division',
              ),
            if (divCards.isNotEmpty && groupCards.isNotEmpty)
              const SizedBox(height: 16),
            if (groupCards.isNotEmpty)
              _Section(
                title: '技术组',
                cards: groupCards,
                scope: 'group',
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.cards,
    required this.scope,
  });
  final String title;
  final List<SpaceCard> cards;
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInUp(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            for (var i = 0; i < cards.length; i++)
              if (i < 4)
                FadeInUp(
                  delay: Duration(milliseconds: 40 * (i + 1)),
                  child: _SpaceCardTile(card: cards[i], scope: scope),
                )
              else
                _SpaceCardTile(card: cards[i], scope: scope),
          ],
        ),
      ],
    );
  }
}

class _SpaceCardTile extends StatelessWidget {
  const _SpaceCardTile({required this.card, required this.scope});
  final SpaceCard card;
  final String scope;

  @override
  Widget build(BuildContext context) {
    final accent =
        scope == 'group' ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    return PressScale(
      child: InkWell(
        onTap: () => context.push('/spaces/$scope/${card.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                scope == 'group' ? Icons.engineering : Icons.shield_outlined,
                size: 18,
                color: accent,
              ),
            ),
            const Spacer(),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${card.memberCount} 人',
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
