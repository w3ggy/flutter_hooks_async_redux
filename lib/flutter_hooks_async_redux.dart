library;

import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;

/// [useSelector] lets you select a part of the state and subscribe to updates.
///
/// The `converter` function should return the part of the state that
/// the widget needs. Example:
///
/// ```dart
/// String username = useSelector<AppState, String>((state) => state.username);
/// ```
///
/// Note: If your state is called `AppState`, you can define your
/// own `useAppState` hook, like this:
///
/// ```dart
/// T useAppState<T>(T Function(AppState state) converter, {bool distinct = true})
///    => useSelector<AppState, T>(converter, distinct: distinct);
/// ```
///
/// This will simplify the use of the hook, like this:
///
/// ```dart
/// String username = useAppState((state) => state.username);
/// ```
///
T useSelector<St, T>(
  T Function(St state) converter, {
  bool distinct = true,
}) {
  final store = StoreProvider.backdoorStaticGlobal<St>();
  return use(
    _AppStateHook(
      store: store,
      converter: converter,
      distinct: distinct,
    ),
  );
}

T _useStore<T>(
  T Function(Store store) converter,
) {
  final store = StoreProvider.backdoorStaticGlobal();
  return use(
    _AppStoreHook(
      store: store,
      storeConverter: converter,
    ),
  );
}

/// Dispatches the action, applying its reducer, and possibly changing the store state.
/// The action may be sync or async.
///
/// ```dart
/// var dispatch = useDispatch()
/// dispatch(MyAction());
/// ```
///
/// See also:
/// - [useDispatchSync] which dispatches sync actions, and throws if the action is async.
/// - [useDispatchAndWait] which dispatches both sync and async actions, and returns a Future.
Dispatch useDispatch() => StoreProvider.backdoorStaticGlobal().dispatch;

/// Dispatches the action, applying its reducer, and possibly changing the store state.
/// However, if the action is ASYNC, it will throw a [StoreException].
///
/// See also:
/// - [useDispatch] which dispatches both sync and async actions.
/// - [useDispatchAndWait] which dispatches both sync and async actions, and returns a Future.
DispatchSync useDispatchSync() => StoreProvider.backdoorStaticGlobal().dispatchSync;

/// Dispatches the action, applying its reducer, and possibly changing the store state.
/// The action may be sync or async. In both cases, it returns a [Future] that resolves when
/// the action finishes.
///
/// ```dart
/// var dispatchAndWait = useDispatchAndWait();
/// var dispatch = useDispatch();
/// await dispatchAndWait(DoThisFirstAction());
/// store.dispatch(DoThisSecondAction());
/// ```
///
/// Note: While the state change from the action's reducer will have been applied when the
/// Future resolves, other independent processes that the action may have started may still
/// be in progress.
///
/// Method [useDispatchAndWait] returns `Future<ActionStatus>`,
/// which means you can also get the final status of the action after you `await` it:
///
/// ```dart
/// var status = await dispatchAndWait(MyAction());
/// ```
///
/// See also:
/// - [useDispatch] which dispatches both sync and async actions.
/// - [useDispatchSync] which dispatches sync actions, and throws if the action is async.
DispatchAndWait useDispatchAndWait() => StoreProvider.backdoorStaticGlobal().dispatchAndWait;

/// You can use [isWaiting] and pass it [actionOrActionTypeOrList] to check if:
/// * A specific async ACTION is currently being processed.
/// * An async action of a specific TYPE is currently being processed.
/// * If any of a few given async actions or action types is currently being processed.
///
/// If you wait for an action TYPE, then it returns false when:
/// - The ASYNC action of the type is NOT currently being processed.
/// - If the type is not really a type that extends [ReduxAction].
/// - The action of the type is a SYNC action (since those finish immediately).
///
/// If you wait for an ACTION, then it returns false when:
/// - The ASYNC action is NOT currently being processed.
/// - If the action is a SYNC action (since those finish immediately).
///
/// Trying to wait for any other type of object will return null and throw
/// a [StoreException] after the async gap.
///
/// Examples:
///
/// ```dart
/// var dispatch = useDispatch();
///
/// // Waiting for an action TYPE:
/// dispatch(MyAction());
/// var isWaiting = useIsWaiting(MyAction);
/// if (isWaiting) { // Show a spinner }
///
/// // Waiting for an ACTION:
/// var action = MyAction();
/// dispatch(action);
/// var isWaiting = useIsWaiting(action);
/// if (isWaiting) { // Show a spinner }
///
/// // Waiting for any of the given action TYPES:
/// dispatch(BuyAction());
/// var isWaiting = useIsWaiting([BuyAction, SellAction]);
/// if (isWaiting) { // Show a spinner }
/// ```
bool useIsWaiting(Object actionOrTypeOrList) =>
    _useStore<bool>((store) => store.isWaiting(actionOrTypeOrList));

/// Returns true if an [actionOrTypeOrList] failed with an [UserException].
///
/// Example:
///
/// ```dart
/// var isFailed = useIsFailed(MyAction);
/// if (isFailed) { // Show an error message. }
/// ```
bool useIsFailed(Object actionOrTypeOrList) =>
    _useStore<bool>((store) => store.isFailed(actionOrTypeOrList));

/// Returns the [UserException] of the [actionTypeOrList] that failed.
///
/// The [actionTypeOrList] can be a [Type], or an Iterable of types.
/// Any other type of object will return null and throw a [StoreException]
/// after the async gap.
///
/// Example:
///
/// ```dart
/// var isFailed = useIsFailed(SaveUserAction);
/// var exception = useExceptionFor(SaveUserAction);
/// if (isFailed) Text(exception)!.reason ?? '');
/// ```
UserException? useExceptionFor(Object actionOrTypeOrList) =>
    _useStore<UserException?>((store) => store.exceptionFor(actionOrTypeOrList));

/// Removes the given [actionTypeOrList] from the list of action types that
/// failed.
///
/// Note that dispatching an action already removes that action type from
/// the exceptions list. This removal happens as soon as the action is
/// dispatched, not when it finishes.
///
/// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other
/// type of object will return null and throw a [StoreException] after the
/// async gap.
///
/// Example:
///
/// ```dart
/// var isFailed = useIsFailed(SaveUserAction);
/// var clearExceptionFor = useClearExceptionFor();
/// if (isFailed) clearExceptionFor(SaveUserAction);
void Function(Object actionOrTypeOrList) useClearExceptionFor() =>
    StoreProvider.backdoorStaticGlobal().clearExceptionFor;

/// `St` is the type of the state of the store.
/// `T` is the type of the state the widget needs (the part of the state that is "selected").
class _AppStateHook<T, St> extends Hook<T> {
  const _AppStateHook({
    required this.store,
    required this.converter,
    this.distinct = true,
  });

  final T Function(St) converter;
  final bool distinct;
  final Store<St> store;

  @override
  HookState<T, Hook<T>> createState() => _AppStateStateHook<T, St>();
}

/// `St` is the type of the state of the store.
/// `T` is the type of the state the widget needs (the part of the state that is "selected").
class _AppStateStateHook<T, St> extends HookState<T, _AppStateHook<T, St>> {
  StreamSubscription? _storeSubscription;
  late T _state;

  bool get isInitialised => _storeSubscription != null;

  @override
  void initHook() {
    super.initHook();
    _updateState(hook.store.state);
    final onStoreChanged = hook.store.onChange;
    _storeSubscription = onStoreChanged.listen(_updateState);
  }

  @override
  T build(BuildContext context) => _state;

  @override
  void dispose() {
    _storeSubscription?.cancel();
    super.dispose();
  }

  void _updateState(St appState) {
    final state = hook.converter(appState);
    if (isInitialised && hook.distinct && state == _state) return;
    setState(() => _state = state);
  }
}

/// `T` is the type of the value from the store the widget needs.
class _AppStoreHook<T> extends Hook<T> {
  const _AppStoreHook({
    required this.store,
    required this.storeConverter,
  });

  final T Function(Store) storeConverter;
  final Store store;

  @override
  HookState<T, Hook<T>> createState() => _AppStoreStateHook<T>();
}

/// `T` is the type of the state the widget needs (the part of the state that is "selected").
class _AppStoreStateHook<T> extends HookState<T, _AppStoreHook<T>> {
  StreamSubscription? _storeSubscription;
  late T _value;

  bool get isInitialised => _storeSubscription != null;

  @override
  void initHook() {
    super.initHook();
    _updateValue(hook.store.state);
    final onStoreChanged = hook.store.onChange;
    _storeSubscription = onStoreChanged.listen(_updateValue);
  }

  @override
  T build(BuildContext context) => _value;

  @override
  void dispose() {
    _storeSubscription?.cancel();
    super.dispose();
  }

  void _updateValue(dynamic _) {
    final value = hook.storeConverter(hook.store);
    if (isInitialised && value == _value) return;
    setState(() => _value = value);
  }
}
