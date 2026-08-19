import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The app's signature interaction: a full-bleed hero view up top, and
/// a sheet anchored at the bottom that starts as a slim peek showing
/// just a "View Full Details" pill. Tap the pill (or drag it up) and
/// the entire screen's data slides up to cover the hero.
class HeroRevealSheet extends StatefulWidget {
  final Widget hero;
  final List<Widget> details;
  final String peekLabel;

  const HeroRevealSheet({
    super.key,
    required this.hero,
    required this.details,
    this.peekLabel = "View Full Details",
  });

  @override
  State<HeroRevealSheet> createState() => _HeroRevealSheetState();
}

class _HeroRevealSheetState extends State<HeroRevealSheet> {
  final _sheetController = DraggableScrollableController();

  void _expand() {
    _sheetController.animateTo(
      0.92,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.hero),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.18,
          minChildSize: 0.18,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.18, 0.92],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, -10)),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  GestureDetector(
                    onTap: _expand,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.accentA),
                            const SizedBox(width: 6),
                            Text(
                              widget.peekLabel,
                              style: const TextStyle(color: AppColors.accentA, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...widget.details,
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
