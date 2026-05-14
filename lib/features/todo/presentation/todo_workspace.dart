import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/todo_item.dart';

/// Oturumu ve Supabase yapılandırmasını üst bileşende doğrula; burada liste + todo işlenir.
class TodoWorkspace extends StatefulWidget {
  const TodoWorkspace({super.key});

  @override
  State<TodoWorkspace> createState() => _TodoWorkspaceState();
}

final class _TodoWorkspaceState extends State<TodoWorkspace> {
  bool _busy = false;
  String? _error;
  final TextEditingController _newTodoTitle = TextEditingController();

  List<SharedList> _lists = <SharedList>[];
  SharedList? _active;
  List<TodoItem> _items = <TodoItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshLists();
    });
  }

  @override
  void dispose() {
    _newTodoTitle.dispose();
    super.dispose();
  }

  Future<void> _refreshLists({bool reloadTodos = true}) async {
    final scope = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await scope.sharedListRepository.fetchMyLists();
      if (!mounted) {
        return;
      }

      SharedList? pick = _active;
      if (next.isEmpty) {
        pick = null;
      } else if (pick == null ||
          next.every((SharedList element) => element.id != pick?.id)) {
        pick = next.first;
      }

      setState(() {
        _lists = next;
        _active = pick;
      });

      if (reloadTodos && pick != null) {
        final SharedList reloadFor = pick;
        await _reloadTodosQuiet(reloadFor.id);
      }
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reloadTodosQuiet(String listId) async {
    final scope = AppScope.read(context);
    try {
      final rows = await scope.todoRepository.fetchTodos(listId: listId);
      if (!mounted) {
        return;
      }
      setState(() => _items = rows);
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message);
    }
  }

  Future<void> _createList() async {
    final scope = AppScope.read(context);
    final titleController = TextEditingController(text: 'Ortak liste');
    String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Yeni liste'),
            content: TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Başlık',
              ),
              onSubmitted: (String _) => Navigator.of(context).maybePop(
                titleController.text.trim(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  titleController.text.trim(),
                ),
                child: const Text('Oluştur'),
              ),
            ],
          );
        },
      );
    } finally {
      titleController.dispose();
    }
    if (name == null || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await scope.sharedListRepository.createList(
        title: name.isEmpty ? 'Ortak liste' : name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _active = created;
      });
      await _refreshLists(reloadTodos: true);
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickList(SharedList list) async {
    setState(() {
      _active = list;
    });
    await _reloadTodosQuiet(list.id);
  }

  Future<void> _toggle(TodoItem item, bool completed) async {
    final scope = AppScope.read(context);
    try {
      await scope.todoRepository.setCompleted(todoId: item.id, completed: completed);
      if (_active != null) {
        await _reloadTodosQuiet(_active!.id);
      }
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _delete(TodoItem item) async {
    final scope = AppScope.read(context);
    try {
      await scope.todoRepository.deleteTodo(todoId: item.id);
      if (_active != null) {
        await _reloadTodosQuiet(_active!.id);
      }
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _addTodo() async {
    if (_active == null) {
      return;
    }
    final scope = AppScope.read(context);
    try {
      await scope.todoRepository.addTodo(
        listId: _active!.id,
        title: _newTodoTitle.text,
      );
      _newTodoTitle.clear();
      await _reloadTodosQuiet(_active!.id);
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_busy && _lists.isEmpty && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null &&
        !_busy &&
        _lists.isEmpty &&
        _active == null &&
        _items.isEmpty) {
      body = _ErrorPanel(
        message: _error!,
        onRetry: _refreshLists,
      );
    } else if (_lists.isEmpty) {
      body = EmptyListPrompt(busy: _busy, onCreate: _createList);
    } else {
      final SharedList viewing = _active ?? _lists.first;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Yeni liste',
              onPressed: _busy ? null : _createList,
              icon: const Icon(Icons.playlist_add),
            ),
          ),
          if (_lists.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButton<String>(
                isExpanded: true,
                key: ValueKey<String>('picker_${viewing.id}'),
                value: viewing.id,
                hint: const Text('Liste seç'),
                items: _lists
                    .map(
                      (SharedList list) => DropdownMenuItem<String>(
                            value: list.id,
                            child: Text(list.title),
                          ),
                    )
                    .toList(),
                onChanged: (String? nextId) {
                  if (nextId == null) {
                    return;
                  }
                  final SharedList picked = _lists.firstWhere(
                    (SharedList element) => element.id == nextId,
                  );
                  _pickList(picked);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  viewing.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _newTodoTitle,
                  decoration: const InputDecoration(
                    hintText: 'Yeni görev',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addTodo(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _addTodo,
                child: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _refreshLists(reloadTodos: true);
              },
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        SizedBox(height: 48),
                        Center(child: Text('Bu listede henüz görev yok')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemBuilder: (BuildContext context, int index) {
                        final TodoItem item = _items[index];
                        return Dismissible(
                          key: ValueKey<String>(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) {
                            _delete(item);
                          },
                          child: CheckboxListTile(
                            value: item.completed,
                            onChanged: _busy
                                ? null
                                : (bool? checked) =>
                                    _toggle(item, checked ?? false),
                            title: Text(
                              item.title,
                              style: item.completed
                                  ? TextStyle(
                                      color:
                                          Theme.of(context).disabledColor,
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                      separatorBuilder:
                          (BuildContext context, int index) =>
                              const Divider(height: 1),
                      itemCount: _items.length,
                    ),
            ),
          ),
        ],
      );
    }

    final bool showOverlayBusy = _busy && _lists.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: body),
        if (showOverlayBusy)
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.24),
          ),
        if (showOverlayBusy)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

final class EmptyListPrompt extends StatelessWidget {
  const EmptyListPrompt({
    required this.busy,
    required this.onCreate,
    super.key,
  });

  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Henüz listen yok.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('İlk listeyi oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              unawaited(onRetry());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
