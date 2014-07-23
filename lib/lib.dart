library trello_dues_to_google_calendar;

import 'dart:collection';
import 'dart:convert' show JSON;

Trello2CalSet<Trello2Cal> getCurrent() {
  // TODO: write this function
  return new Trello2CalSet<Trello2Cal>();
}

bool updateConfiguration(String configFile, String key, String value) {
  print("Updating config, key: $key");
  print("Updating config, value: $value");
  // TODO: write this function
  return true;
}

class Trello2Cal {
  String cardId;
  String cardDesc;
  String cardDue;
  String cardUrl;
  String cardName;
  String boardName;
  String eventId; // This is set *after* the insertion in Google Calendar
  Trello2Cal(Map<String, String> card, String _boardName) {
    cardId = card["id"];
    cardDesc = card["desc"];
    cardDue = card["due"];
    cardUrl = card["url"];
    cardName = card["name"];
    boardName = _boardName;
  }

  bool operator ==(Trello2Cal other) {
    return this.cardId == other.cardId && this.cardDesc == other.cardDesc &&
        this.cardDue == other.cardDue && this.cardUrl == other.cardUrl &&
        this.boardName == other.boardName && this.cardName == other.cardName;
  }

  // TODO:
  Map<String, dynamic> toEventJson() {

    String description = this.cardDesc != null
      ? this.cardDesc + "\n\n---\n"
      : "";

    description += "View in Trello:\n" + this.cardUrl;

    Map<String, dynamic> _eventMap = {};
    _eventMap["start"] = {"dateTime" : this.cardDue};
    _eventMap["end"] = {"dateTime" : this.cardDue};
    _eventMap["summary"] = this.boardName + ": " + this.cardName;
    _eventMap["description"] = description;
    return _eventMap;
  }
}

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