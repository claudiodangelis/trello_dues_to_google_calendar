library trello_dues_to_google_calendar;

import 'dart:collection';
import 'dart:convert' show JSON;
import 'dart:io';

final String CONFIG_FILE = 'config.json';

Trello2CalSet<Trello2Cal> getCurrent() {
  // TODO: write this function
  File configFile = new File(CONFIG_FILE);
  Map<String, dynamic> config = JSON.decode(configFile.readAsStringSync());
  Trello2CalSet<Trello2Cal> _set = new Trello2CalSet<Trello2Cal>();
  if (config["current"] != null) {
    List<String> currentAsList = config["current"];
    currentAsList.forEach((String json) {
      _set.add(new Trello2Cal.fromJson(json));
    });
    return _set;
  }
  updateConfiguration(CONFIG_FILE, "current", []);
  return _set;
}

// TODO:
// TODO: if possible, pretty-print json
bool updateConfiguration(String configFilePath, String key, dynamic value) {
  print("Updating config, key: $key");
  print("Updating config, value: $value");
  // TODO: write this function
  File configFile = new File(configFilePath);
  // Read the conf
  // FIXME: what if the contents are not valid json?
  Map<String, dynamic> config = JSON.decode(configFile.readAsStringSync());
  // Add/replace the key
  config[key] = value;
  // Write down the conf again
  try {
    configFile.writeAsStringSync(JSON.encode(config), mode: WRITE);
    return true;
  } catch (FileSystemException) {
    print(FileSystemException);
  }
  return false;
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

  String toString() {
    Map<String, String> _map = {};
    _map["cardId"] = this.cardId;
    _map["cardDesc"] = this.cardDesc;
    _map["cardDue"] = this.cardDue;
    _map["cardUrl"] = this.cardUrl;
    _map["cardName"] = this.cardName;
    _map["boardName"] = this.boardName;
    _map["eventId"] = this.eventId;

    return JSON.encode(_map);
  }

  Trello2Cal.fromJson(String json) {
    Map<String, String> _map = JSON.decode(json);
    this.boardName = _map["boardName"];
    this.cardDesc = _map["cardDesc"];
    this.cardDue = _map["cardDue"];
    this.cardId = _map["cardId"];
    this.cardName = _map["cardName"];
    this.cardUrl = _map["cardUrl"];
    this.eventId = _map["eventId"];
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