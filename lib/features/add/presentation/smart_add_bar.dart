import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/app_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../notes/domain/note_repo.dart';
import '../../todo/domain/todo_repo.dart';
import 'smart_add_controller.dart';
import 'smart_add_edit_sheet.dart';

/// The shell-level Smart Add result bar. While the background pass runs it shows
/// a progress line; once ready it offers Accept (write the items) and Edit (open
/// the page picker and re-classify). Driven by [SmartAddController]; rendered by
/// the swipe shell so it floats over whichever tab is showing.
class SmartAddBar extends StatelessWidget {
  const SmartAddBar({super.key, required this.controller});

  final SmartAddController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [kCardShadow],
      ),
      child: controller.isProcessing ? _processing() : _ready(context),
    );
  }

  Widget _processing() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark),
        ),
        const SizedBox(width: 12),
        Text('AI 分析中…',
            style: AppText.body(size: 14, color: AppColors.dark)),
      ],
    );
  }

  Widget _ready(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 15, color: AppColors.amber),
            const SizedBox(width: 7),
            Expanded(
              child: Text(controller.summary,
                  style: AppText.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.dark)),
            ),
            GestureDetector(
              onTap: controller.dismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(LucideIcons.x, size: 16, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _btn(
                label: '編輯',
                filled: false,
                onTap: () => _edit(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _btn(
                label: '接受',
                filled: true,
                onTap: () => _accept(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _btn({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: filled ? null : Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.body(
              size: 14,
              weight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final n = await controller.accept();
    if (n > 0) {
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('已新增 $n 個項目',
              style: AppText.body(size: 13, color: Colors.white)),
          backgroundColor: AppColors.dark,
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Future<void> _edit(BuildContext context) async {
    final todoRepo = context.read<TodoRepo>();
    final noteRepo = context.read<NoteRepo>();
    final todoCats = await todoRepo.watchTodoCategories().first;
    final noteCats = await noteRepo.watchNoteCategories().first;
    if (!context.mounted) return;
    final result = await showSmartAddEditSheet(
      context,
      items: controller.items,
      todoCats: todoCats,
      noteCats: noteCats,
    );
    if (result != null) {
      await controller.reclassify(
        cats: result.cats,
        todoCatId: result.todoCatId,
        noteCatId: result.noteCatId,
      );
    }
  }
}
