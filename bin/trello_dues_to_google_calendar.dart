import 'dart:io';
import 'package:logging/logging.dart';
import 'dart:convert' show JSON;
import 'dart:collection';
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';

class Trello2Cal {
  String cardId;
  String cardDesc;
  String cardDue;
  String cardUrl;
  String boardName;
  String eventId; // This is set *after* the insertion in Google Calendar
  Trello2Cal(Map<String, String> card, String boarName) {
    cardId = card["id"];
    cardDesc = card["desc"];
    cardDue = card["due"];
    cardUrl = card["url"];
    boardName = boardName;
  }

  bool operator ==(Trello2Cal other) {
    return this.cardId == other.cardId && this.cardDesc == other.cardDesc &&
        this.cardDue == other.cardDue && this.cardUrl == other.cardUrl;
  }

  // TODO:
  String toEventJson() {
    Map<String, dynamic> _eventMap = {};
    return JSON.encode(_eventMap);
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
  // Overriding .contains for fun and profit (and to get intersection working!)
  bool contains(E elem) {
    try {
      _set.singleWhere((E e) => e == elem);
    } catch (e) {
      return false;
    }
    return true;
  }

}

final String CONFIG_FILE = "config.json";
Calendar trelloCal;

main() {
  // TODO: add --debug flag

  // TODO: using logger only if --debug=true
  // Setting up the logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] ${rec.message}');
  });
  final Logger log = new Logger('TrelloDues2Calendar');

  log.info("Starting app");
  log.info("Reading $CONFIG_FILE");
  File configFile = new File(CONFIG_FILE);
  Map<String, String> config = JSON.decode(configFile.readAsStringSync());
  log.info("Configuration:");
  log.info(config.toString());

  log.info("Checking if Trello keys are present");
  if (config["trello_key"].isEmpty || config["trello_secret"].isEmpty) {
    log.severe("Trello Keys not found");
    error("Please check your keys");
  }

  var auth = new OAuth2Console(identifier: config["google_client_id"],
      secret: config["google_client_secret"],
      scopes: config["google_scopes"] as List,
      credentialsFilePath: config["google_credentials"]);

  cal.Calendar calendar = new cal.Calendar(auth);
  calendar.makeAuthRequests = true;

  if (config["google_client_id"].isEmpty ||
      config["google_client_secret"].isEmpty) {
    log.severe("Google API keys not found");
    error("Please check google api");
  }


  if (config["id_trello_calendar"].isEmpty) {
    log.warning("Trello calendar id not set");
    log.info("Looking for trello calendar id in Google Calendar");
    calendar.calendarList.list(
        optParams: {"approval_prompt": "auto"}).then((CalendarList list) {
      // FIXME:
      // type 'CalendarListEntry' is not a subtype of type 'Calendar' in
      // type cast.
      try {
        trelloCal = list.items.singleWhere((calEntry) {
          return calEntry.summary.toLowerCase() == "trello";
        }) as Calendar; // FIXME: failing type cast

      } catch (StateError) {
        log.severe("Trello calendar is not present");
        log.severe(StateError.toString());
        Calendar calendarRequest = new Calendar.fromJson({"summary": "Trello"});
        calendar.calendars.insert(calendarRequest).then((Calendar cal) {
          log.fine("Trello Calendar successfully created");
          trelloCal = cal;
        });
      }
    });
  }
}

void error(String msg) {
  print("Error: $msg");
  print("Exiting app.");
  exit(1);
}