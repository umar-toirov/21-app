import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/challenge_icons.dart';
import '../../../../core/widgets/mockup_widgets.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// Picks a challenge framework. Shown right after sign-up (with Skip, so people
/// can join a group without a personal challenge) and from Home for a new one.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _customId = '_custom';

  final _search = TextEditingController();
  String _query = '';
  String _category = 'all';
  String? _selected;
  bool _skipping = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    if (_skipping) return;
    setState(() => _skipping = true);
    try {
      await ref.read(apiRepositoryProvider).skipOnboarding();
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a group now. You can start your own challenge anytime from Home.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 92),
        ),
      );
      context.go('${AppRoutes.home}/groups');
    } catch (e) {
      if (!mounted) return;
      setState(() => _skipping = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  void _continue(ChallengeCatalog catalog) {
    final id = _selected;
    if (id == null) return;
    final template = id == _customId
        ? null
        : catalog.templates.firstWhere((t) => t.id == id);
    context.push(AppRoutes.newChallenge, extra: template);
  }

  List<ChallengeTemplate> _filtered(ChallengeCatalog catalog) {
    final q = _query.trim().toLowerCase();
    return catalog.templates.where((t) {
      if (_category != 'all' && t.category != _category) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(challengeCatalogProvider);
    final firstTime = ref.watch(profileProvider).maybeWhen(
          data: (p) => p.needsOnboarding,
          orElse: () => false,
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: catalogAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
              error: (e, _) => _LoadError(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(challengeCatalogProvider),
              ),
              data: (catalog) => _buildBody(context, catalog, firstTime),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChallengeCatalog catalog, bool firstTime) {
    final items = _filtered(catalog);
    final showCustom = _category == 'all' && _query.trim().isEmpty;

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 640 ? 3 : 2;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  if (context.canPop())
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    )
                  else
                    const SizedBox(width: 44),
                  const Spacer(),
                  if (firstTime)
                    TextButton(
                      onPressed: _skipping ? null : _skip,
                      child: _skipping
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Skip',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _header(firstTime)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterHeader(
                      minHeight: 116,
                      child: _filters(catalog),
                    ),
                  ),
                  if (items.isEmpty && !showCustom)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoResults(
                        onCreateOwn: () => setState(() {
                          _search.clear();
                          _query = '';
                          _category = 'all';
                          _selected = _customId;
                        }),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 176,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (showCustom && i == 0) {
                              return _CustomCard(
                                selected: _selected == _customId,
                                onTap: () => _select(_customId),
                              );
                            }
                            final t = items[i - (showCustom ? 1 : 0)];
                            return _TemplateCard(
                              template: t,
                              selected: _selected == t.id,
                              onTap: () => _select(t.id),
                            );
                          },
                          childCount: items.length + (showCustom ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _BottomBar(
              enabled: _selected != null,
              label: _selected == null ? 'Choose a challenge' : 'Continue',
              onPressed: () => _continue(catalog),
            ),
          ],
        );
      },
    );
  }

  void _select(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selected = id);
  }

  Widget _header(bool firstTime) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstTime ? 'One last step' : 'New challenge',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: firstTime ? 'Pick your ' : 'Pick a '),
                TextSpan(
                  text: firstTime ? 'first' : 'new',
                  style: const TextStyle(color: AppColors.orange),
                ),
                const TextSpan(text: ' challenge'),
              ],
            ),
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            firstTime
                ? 'Choose something meaningful. You can always add more later.'
                : 'Choose a framework, then make it yours.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(ChallengeCatalog catalog) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search challenges…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppColors.borderStrong),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppColors.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _category == 'all',
                  onTap: () => setState(() => _category = 'all'),
                ),
                for (final c in catalog.categories)
                  _CategoryChip(
                    label: c.label,
                    selected: _category == c.id,
                    onTap: () => setState(() => _category = c.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterHeader extends SliverPersistentHeaderDelegate {
  _FilterHeader({required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => minHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _FilterHeader oldDelegate) => true;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.orange : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.orange : AppColors.borderStrong),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final ChallengeTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = challengeCategoryColor(template.category);
    final diff = difficultyColor(template.difficulty);

    return _CardShell(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlossyIcon(icon: challengeIcon(template.icon), color: color, size: 44),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.orange, size: 22),
            ],
          ),
          const Spacer(),
          Text(
            template.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${template.durationDays} days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diff.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  template.difficultyLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: diff,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GlossyIcon(icon: Icons.add_rounded, color: AppColors.orange, size: 44),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.orange, size: 22),
            ],
          ),
          const Spacer(),
          Text(
            'Create your own',
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your goal, your tasks',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: selected ? AppColors.orangeSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.orange : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: PrimaryButton(
        label: label,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onCreateOwn});

  final VoidCallback onCreateOwn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            'No challenges found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another word, or create your own.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onCreateOwn, child: const Text('Create your own')),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: PrimaryButton(label: 'Try again', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}
