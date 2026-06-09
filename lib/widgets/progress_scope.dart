import 'package:flutter/widgets.dart';
import '../models/progress_state.dart';

/// InheritedNotifier that propagates ProgressState down the tree.
/// Widgets that call [ProgressScope.of] rebuild automatically whenever
/// ProgressState notifies listeners.
class ProgressScope extends InheritedNotifier<ProgressState> {
  const ProgressScope({
    super.key,
    required ProgressState progress,
    required super.child,
  }) : super(notifier: progress);

  static ProgressState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope found in widget tree.');
    return scope!.notifier!;
  }
}
