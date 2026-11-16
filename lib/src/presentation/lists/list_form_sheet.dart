import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/list_repository.dart';
import '../../shared/extension/context_extension.dart';

/// Create / rename / recolour / delete a list
class ListFormSheet extends StatefulWidget {
  const ListFormSheet({super.key, this.list});

  final TaskList? list;

  /// Returns true when the list was deleted
  static Future<bool?> show(BuildContext context, {TaskList? list}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ListFormSheet(list: list),
    );
  }

  @override
  State<ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<ListFormSheet> {
  late final _name = TextEditingController(text: widget.list?.name);
  late int _color = widget.list?.colorValue ?? listColors.first;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final repo = getIt<ListRepository>();
    final list = widget.list;
    if (list == null) {
      await repo.create(name, _color);
    } else {
      await repo.update(list.id, name: name, color: _color);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _delete(TaskList list) async {
    final messenger = ScaffoldMessenger.of(context);
    final undo = await getIt<ListRepository>().delete(list.id);
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    Navigator.pop(context, true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.listDeleted(list.name)),
          action: SnackBarAction(label: l10n.undo, onPressed: undo),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = widget.list;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            list == null ? l10n.newList : l10n.editList,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: list == null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_showError) {
                setState(() => _showError = false);
              }
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.listName,
              errorText: _showError ? l10n.listNameRequired : null,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in listColors)
                Semantics(
                  selected: color == _color,
                  button: true,
                  child: InkResponse(
                    onTap: () => setState(() => _color = color),
                    radius: 24,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: color == _color
                            ? Border.all(
                                color: context.colorScheme.onSurface,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: color == _color
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(list == null ? l10n.createList : l10n.save),
          ),
          if (list != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.error,
              ),
              onPressed: () => _confirmDelete(list),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.deleteListNamed(list.name)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(TaskList list) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteListNamed(list.name)),
        content: Text(l10n.deleteListMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              foregroundColor: context.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteListNamed(list.name)),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _delete(list);
    }
  }
}
