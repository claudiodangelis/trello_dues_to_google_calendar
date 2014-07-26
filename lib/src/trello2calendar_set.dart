part of trello_dues_to_google_calendar;


class Trello2CalSet<E> extends SetBase<E> {
  Set<E> _set = new Set<E>();

  Set<E> toSet() => new Set()..addAll(this);
  int get length => _set.length;
  Iterator<E> get iterator => _set.iterator;
  bool add(E elem) => _set.add(elem);
  bool remove(E elem) => _set.remove(elem);
  E lookup(E elem) => _set.lookup(elem);
  // Overriding .contains() for fun and profit (and to get intersection working)
  bool contains(E elem) {
    try {
      _set.singleWhere((E e) => e == elem);
    } catch (e) {
      return false;
    }
    return true;
  }

}