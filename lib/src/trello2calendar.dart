part of trello_dues_to_google_calendar;

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