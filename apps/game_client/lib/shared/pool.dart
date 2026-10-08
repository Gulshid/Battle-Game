class Pool<T> {
  Pool(this._create, this._reset, {int prewarm = 0}) {
    for (var i = 0; i < prewarm; i++) {
      _free.add(_create());
    }
  }

  final T Function() _create;
  final void Function(T) _reset;
  final List<T> _free = [];

  int get available => _free.length;

  T acquire() => _free.isEmpty ? _create() : _free.removeLast();

  void release(T o) {
    _reset(o);
    _free.add(o);
  }
}
