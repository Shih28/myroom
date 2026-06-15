import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/date_format.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/bottom_nav_bar.dart';
import '../core/widgets/mr_icon_button.dart';
import '../features/add/presentation/add_overlay.dart';
import '../router/routes.dart';

/// The swipeable shell rendered by the `StatefulShellRoute`'s
/// `navigatorContainerBuilder`. It lays the five branch navigators out in a
/// horizontal [PageView] strip and prepends the Add overlay as the page to the
/// left of the calendar:
///
///   page 0 = Add overlay (own header, no top bar / no nav)
///   page 1 = calendar, 2 = todo, 3 = idea, 4 = note, 5 = recap
///   (branch index = page - 1)
///
/// Centre swipes are handled by the [PageView] itself, so the in-page
/// horizontal gestures that sit deeper in the tree (the calendar month pager,
/// the todo row-`Dismissible`/chip strip) win the gesture arena where they are,
/// while empty areas fall through to a page change. The two thin edge strips on
/// top force a page change from the left/right 10% — the only way to leave the
/// calendar (whose centre is reserved for the month pager) and what reveals the
/// Add overlay IG-style.
class SwipeShell extends StatefulWidget {
  const SwipeShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<SwipeShell> createState() => _SwipeShellState();
}

class _SwipeShellState extends State<SwipeShell> {
  static const _pageTitles = ['行事曆', '待辦', '靈感', '札記', '成就'];
  static const _edgeFraction = 0.1;
  static const _swipeDuration = Duration(milliseconds: 260);
  static const _flingVelocity = 320.0;

  late final PageController _pageCtrl;
  bool _navBarVisible = true;

  int get _branchIndex => widget.navigationShell.currentIndex;
  int get _currentPage => _branchIndex + 1;
  int get _lastPage => widget.children.length; // overlay + N branches → N

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(SwipeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate to the new tab only when the branch changed externally (a
    // bottom-nav tap or deep link) — never on an unrelated rebuild, which would
    // otherwise yank the user off the overlay (page 0, where currentIndex still
    // points at the calendar). The second guard skips the no-op animate when a
    // swipe we just settled is what changed the branch.
    if (oldWidget.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex &&
        _pageCtrl.hasClients &&
        (_pageCtrl.page?.round() ?? _currentPage) != _currentPage) {
      _pageCtrl.animateToPage(_currentPage,
          duration: _swipeDuration, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Keep go_router's branch (and the bottom-nav highlight) in sync once a swipe
  // settles. Page 0 is the overlay — it has no branch, so leave currentIndex on
  // the calendar.
  void _onPageSettled(int page) {
    if (page >= 1 && page - 1 != _branchIndex) {
      widget.navigationShell.goBranch(page - 1);
    }
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // The active page's vertical scroll flies the bottom nav out (scroll down) /
  // back in (scroll up); horizontal scrollers are ignored.
  bool _handleNavBarScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse && _navBarVisible) {
      setState(() => _navBarVisible = false);
    } else if (n.direction == ScrollDirection.forward && !_navBarVisible) {
      setState(() => _navBarVisible = true);
    }
    return false;
  }

  // ── Edge override: drive the PageController straight from the finger ─────────

  void _onEdgeDragUpdate(DragUpdateDetails d) {
    if (!_pageCtrl.hasClients) return;
    final pos = _pageCtrl.position;
    _pageCtrl.jumpTo((pos.pixels - d.delta.dx)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent));
  }

  void _onEdgeDragEnd(DragEndDetails d) {
    if (!_pageCtrl.hasClients) return;
    final current = _pageCtrl.page ?? _currentPage.toDouble();
    final v = d.primaryVelocity ?? 0;
    final int target;
    if (v < -_flingVelocity) {
      target = current.floor() + 1; // fling left → next page
    } else if (v > _flingVelocity) {
      target = current.ceil() - 1; // fling right → previous page
    } else {
      target = current.round();
    }
    _pageCtrl.animateToPage(target.clamp(0, _lastPage),
        duration: _swipeDuration, curve: Curves.easeOut);
  }

  // Current fractional strip position (overlay = 0 … last tab = N); falls back
  // to the settled page until the controller attaches.
  double get _stripPage => _pageCtrl.hasClients
      ? (_pageCtrl.page ?? _currentPage.toDouble())
      : _currentPage.toDouble();

  // Wraps a fixed chrome widget (top bar / bottom nav) so it fades out and stops
  // taking pointers as the strip slides onto the overlay (page 0), which brings
  // its own header.
  Widget _fadingChrome(Widget child) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, c) {
        // 0 over the overlay, 1 once on the calendar or beyond.
        final reveal = _stripPage.clamp(0.0, 1.0);
        if (reveal == 0) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: reveal < 1,
          child: Opacity(opacity: reveal, child: c),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final edgeW = constraints.maxWidth * _edgeFraction;
        return Stack(
          children: [
            NotificationListener<UserScrollNotification>(
              onNotification: _handleNavBarScroll,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: widget.children.length + 1,
                onPageChanged: _onPageSettled,
                itemBuilder: (context, page) {
                  if (page == 0) {
                    // The overlay is left lazy (no keep-alive) so its recorder
                    // is released whenever it scrolls out of the cache.
                    return AddOverlay(
                      onClose: () => _pageCtrl.animateToPage(1,
                          duration: _swipeDuration, curve: Curves.easeOut),
                    );
                  }
                  final branch = page - 1;
                  // go_router's branch proxies already keep their state alive in
                  // a PageView/TabBarView (AutomaticKeepAliveClientMixin), so the
                  // tab content survives being scrolled off-screen.
                  return _TabPage(
                    title: _pageTitles[branch],
                    child: widget.children[branch],
                  );
                },
              ),
            ),

            // Fixed top bar — stays put while the pages (and their titles) slide
            // beneath it; fades away as the strip nears the overlay (page 0),
            // which carries its own header. Sits below the edge strips so an
            // edge swipe started up here still changes page.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _fadingChrome(const _TopBar()),
            ),

            // Edge-override strips (above the pages, translucent so taps and
            // vertical scrolls still reach the content underneath).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: edgeW,
              child: _EdgeSwipeArea(
                onUpdate: _onEdgeDragUpdate,
                onEnd: _onEdgeDragEnd,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: edgeW,
              child: _EdgeSwipeArea(
                onUpdate: _onEdgeDragUpdate,
                onEnd: _onEdgeDragEnd,
              ),
            ),

            // Fixed bottom nav — fades + lifts away as the strip nears the
            // overlay (page 0), and still flies out on vertical scroll.
            Positioned(
              bottom: 22,
              left: 20,
              right: 20,
              child: _fadingChrome(
                AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  offset: _navBarVisible ? Offset.zero : const Offset(0, 2.5),
                  child: BottomNavBar(
                    activeIndex: _branchIndex,
                    onTap: _goBranch,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Height reserved at the top of every tab page for the fixed [_TopBar], which
/// the shell paints over this gap. Matches `_TopBar`'s 8 + 36 (button) + 12.
const _kTopBarHeight = 56.0;

/// A single tab page. Only the page title + content live here, so they slide
/// during a swipe while the shell's [_TopBar] stays pinned above the reserved
/// [_kTopBarHeight] gap.
class _TabPage extends StatelessWidget {
  const _TabPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _kTopBarHeight),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.display()),
              const SizedBox(height: 3),
              Text(
                '${now.year}年${now.month}月${now.day}日，星期${kDow[now.weekday % 7]}',
                style: AppText.caption(),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// The fixed top bar (myroom logo + add / search / settings). A single instance
/// pinned by the shell above every tab page, so it stays put while pages slide.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      child: Row(
        children: [
          MrIconButton(
            icon: LucideIcons.plus,
            bg: AppColors.dark,
            iconColor: Colors.white,
            showBorder: false,
            borderRadius: 13,
            onTap: () => context.push(Routes.add),
          ),
          const Spacer(),
          Text('myroom',
              style:
                  AppText.display(size: 23, weight: FontWeight.w400, italic: true)),
          const Spacer(),
          Row(
            children: [
              MrIconButton(
                icon: LucideIcons.search,
                iconSize: 17,
                onTap: () => context.push(Routes.chat),
              ),
              const SizedBox(width: 7),
              MrIconButton(
                icon: LucideIcons.settings,
                iconSize: 16,
                onTap: () => context.push(Routes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A thin transparent strip that captures only horizontal drags and drives the
/// [PageController] directly, winning over any in-page horizontal gesture in the
/// edge zone (it is the topmost hit-test target there).
class _EdgeSwipeArea extends StatelessWidget {
  const _EdgeSwipeArea({required this.onUpdate, required this.onEnd});

  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: onUpdate,
      onHorizontalDragEnd: onEnd,
    );
  }
}
