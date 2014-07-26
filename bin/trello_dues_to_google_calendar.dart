import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:trello_dues_to_google_calendar/lib.dart';
import 'dart:convert' show JSON;
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:args/args.dart';

final String CONFIG_FILE = "config.json";
final bool noPastDues = true; // TODO: Move this in config.json
List<Map<String, dynamic>> _boards;
List<Map<String, dynamic>> _cards;

String trelloCalId;

final Logger log = new Logger('TrelloDues2Calendar');
File configFile;
Map<String, String> config;
cal.Calendar calendar;
main(List<String> args) {
  ArgParser parser = new ArgParser();
  parser.addFlag('configure', negatable: false, callback: startConfigure);
  parser.parse(args);

  // TODO: add --debug flag

  // TODO: using logger only if --debug=true
  // Setting up the logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] ${rec.message}');
  });



  log.info("Starting app");
  log.info("Reading config file");
  config = getConfiguration();
  log.info("Configuration:");
  log.info(config.toString());



  // FIXME:
  if (config["trello_key"].isEmpty || config["trello_secret"].isEmpty) {
    log.severe("Trello Keys not found");
    error("Please check your keys");
  }
  log.fine("OK");

  log.info("Checking if trello token is present and valid");
  if (config["trello_token"].isEmpty) {
    log.warning("Trello token not present. Please visit this URL get a token:");
    String requestTrelloAuthUrl = "https://trello.com/1/authorize?" + "key=" +
        config["trello_key"] + "&" + "name=" + "TrelloDues2Calendar" + "&" +
        "expiration=" + "never" + "&" + "response_type=" + "token";
    log.warning(requestTrelloAuthUrl);
    print("Paste your token here:");
    // TODO: set a timeout for this operation
    String _trelloToken = stdin.readLineSync();
    updateConfiguration("trello_token", _trelloToken);
  } else {
    // TODO: check is trello token is valid
  }

  var auth = new OAuth2Console(identifier: config["google_client_id"], secret:
      config["google_client_secret"], scopes: config["google_scopes"] as List,
      credentialsFilePath: config["google_credentials"]);

  calendar = new cal.Calendar(auth);
  calendar.makeAuthRequests = true;

  log.info("Checking if Google keys are present");
  if (config["google_client_id"].isEmpty ||
      config["google_client_secret"].isEmpty) {
    log.severe("Google API keys not found");
    error("Please check google api");
  }
  log.fine("OK");

  log.info("Checking if id_trello_calendar is set");
  // FIXME, nasty workaround
  if (config["id_trello_calendar"] == null) {
    updateConfiguration("id_trello_calendar", "");
  }
  config = getConfiguration();
  if (config["id_trello_calendar"].isEmpty) {
    log.warning("Trello calendar id not set");
    log.info("Looking for trello calendar id in Google Calendar");
    calendar.calendarList.list(optParams: {
      "approval_prompt": "auto"
    }).then((CalendarList list) {
      try {
        trelloCalId = list.items.singleWhere((calEntry) {
          return calEntry.summary.toLowerCase() == "trello";
        }).id;

      } catch (StateError) {
        log.severe("Trello calendar is not present");
        log.severe(StateError.toString());
        Calendar calendarRequest = new Calendar.fromJson({
          "summary": "Trello"
        });
        calendar.calendars.insert(calendarRequest).then((Calendar cal) {
          log.fine("Trello Calendar successfully created");
          trelloCalId = cal.id;
          updateConfiguration("id_trello_calendar", cal.id);
          print(trelloCalId);
        });
      }
    });
  } else {
    trelloCalId = config["id_trello_calendar"];
  }
  log.fine("OK");
  log.info("Creating empty 'next' set");
  Trello2CalSet<Trello2Cal> next = new Trello2CalSet<Trello2Cal>();
  log.info("Retrieving 'current' set");
  Trello2CalSet<Trello2Cal> current = getCurrent();
  log.info("Dump current set:");
  log.info(current.toString());

  Set<Trello2Cal> intersection;
  // If two `Trello2Cal`'s are equal, then do nothing with them
  Set<Trello2Cal> skipping = new Trello2CalSet<Trello2Cal>();;
  // If a T2C is in next, but not in next<>current intersection, then add to cal
  Set<Trello2Cal> adding = new Trello2CalSet<Trello2Cal>();
  // If a T2C is in current, but not in n<>c intersection, then delete from cal
  Set<Trello2Cal> deleting = new Trello2CalSet<Trello2Cal>();



  // TODO: please find a better name for this identifier
  List futuresQueue = [];

  log.info("Ready to get started retrieving boards and cards");
  getBoards().then((List<Map<String, dynamic>> boards) {
    boards.forEach((board) {
      futuresQueue.add(getCards(board));
    });
    Future.wait(futuresQueue).then((List<Trello2CalSet> responses) {
      responses.forEach((Trello2CalSet resp) {
        if (resp.isNotEmpty) {
          resp.forEach((Trello2Cal t2c) {
            next.add(t2c);
          });
        }
      });
    }).whenComplete(() {
      log.fine("Done populating next set");
      log.info("Checking if current set is empty");
      if (current.isEmpty) {
        log.info("current set is empty");
        log.info("Adding next set to adding set");
        adding.addAll(next);
      } else {
        log.info("Current set not empty");
        // TODO: more consistent identifiers names
        log.info("INTERSECTION");
        intersection = current.intersection(next);
        log.info(intersection.toString());
        // If two `Trello2Cal`'s are equal, then do nothing with them
        skipping = intersection;
        print("SKIPPING");
        print(skipping.toString());
        // If a T2C is in next, but not in next<>current intersection, then add to cal
        log.info("ADDING:");
        // TODO: current.intersection(next) doesn't work
        adding = next.difference(next.intersection(current));
        log.info(adding.toString());
        // If a T2C is in current, but not in n<>c intersection, then delete from cal
        log.info("DELETING:");
        deleting = current.difference(intersection);
        log.info(deleting.toString());
      }

      log.info("Pushing data to google calendar");

      Set<Trello2Cal> newCurrent = new Set<Trello2Cal>();

      List addingQueue = [];

      if (adding.isNotEmpty) {
        adding.forEach((Trello2Cal t2c) {
          addingQueue.add(addTrello2Cals(t2c));
        });
      }

      Future.wait(addingQueue).then((List<Map<Trello2Cal, Event>> responses) {
        responses.forEach((Map<Trello2Cal, Event> resp) {
          resp.forEach((t2c, event) {
            t2c.eventId = event.id;
            newCurrent.add(t2c);
          });
        });
      }).whenComplete(() {
        log.info("Preparing new current to be written to file"); // grammar ok?
        List<String> currentAsList = [];
        newCurrent.forEach((Trello2Cal t2c) {
          currentAsList.add(t2c.toString());
        });

        skipping.forEach((Trello2Cal t2c) {
          currentAsList.add(t2c.toString());
        });

        log.info("Removing events");
        if (deleting.isNotEmpty || deleting == null) {
          deleting.forEach((Trello2Cal t2c) {
            log.info("Deleting: ${t2c.cardDesc}");

            calendar.events.delete(trelloCalId, t2c.eventId);
          });
        }
        updateConfiguration("current", currentAsList);
      });
    });

  });
}

Future<Map<Trello2Cal, Event>> addTrello2Cals(Trello2Cal t2c) {
  Completer completer = new Completer();
  print(trelloCalId);
  log.info("Adding ${t2c.cardName} to Google Calendar");
  calendar.events.insert(new Event.fromJson(t2c.toEventJson()),
      trelloCalId, optParams:
      {"approval_prompt": "auto"}).then((Event event) {

    completer.complete({t2c:event});
  });
  return completer.future;

}

Future<List<Map<String, dynamic>>> getBoards() {
  Completer completer = new Completer();
  // Boards URL
  String boardsUrl = "https://api.trello.com/1/members/me/boards?" +
      "filter=open" + "&" + "key=" + config["trello_key"] + "&" + "token=" +
      config["trello_token"];
  // TODO:
  // Gets all the baords
  http.get(boardsUrl).then((http.Response boardsResp) {
    completer.complete(JSON.decode(boardsResp.body));
  });
  return completer.future;
}

Future<Trello2CalSet<Trello2Cal>> getCards(Map<String, dynamic> _board) {
  Completer completer = new Completer();
  Trello2CalSet<Trello2Cal> set = new Trello2CalSet<Trello2Cal>();
  // Board id (to use to retrieve cards)
  String _boardId = _board["id"];
  // Board name (to use to build the Trello2Cal element)
  String _boardName = _board["name"];
  // Build the retrive-card string
  String cardsUrl = "https://api.trello.com/1/boards/$_boardId/cards?" +
      "card_fields=due" + "&" + "key=" + config["trello_key"] + "&" + "token=" +
      config["trello_token"];

  // Retrieving all the cards
  http.get(cardsUrl).then((http.Response cardsResp) {
    _cards = JSON.decode(cardsResp.body);
    // Selecting only cards with due date
    _cards.forEach((Map<String, dynamic> _card) {
      if (_card["due"] != null) {
        // Performing check wether it wants or not past dues
        DateTime now = new DateTime.now();
        int compare = now.compareTo(DateTime.parse(_card["due"]));
        if (!noPastDues || (noPastDues && compare.isNegative)) {
          // This is the card we're looking for
          log.fine("Found a card with due:");
          log.info("Board name ${_board["name"]}");
          log.info("Card name: ${_card["name"]}");
          log.info("Due date: ${_card["due"]}");
          set.add(new Trello2Cal(_card, _board["name"]));
        }
      }
    });
    completer.complete(set);
  });
  return completer.future;
}

void error(String msg) {
  print("Error: $msg");
  print("Exiting app.");
  exit(1);
}

void startConfigure(bool configure) {
  if (configure) {
    // TODO: this will destroy current configureation, user(s?) should be aware
    // of this probably
    print("Starting configuration wizard...");
    // Trello keys
    // TODO: check grammar
    print(
"""
Please visit https://trello.com/1/appKey/generate in order to generate:
1) Trello Key
2) Trello Secret
required for authentication.
""");

    print("Insert 'Trello Key':");
    // TODO: check
    String _trelloKey = stdin.readLineSync();
    updateConfiguration("trello_key", _trelloKey.trim());
    print("Insert 'Trello Secret':");
    // TODO: check
    String _trelloSecret = stdin.readLineSync();
    updateConfiguration("trello_secret", _trelloSecret.trim());

    print(
"""
Good, now you need to generate Google Cloud keys. Please visit
https://cloud.google.com, create a new app, make sure to enable Google Calendar
APIs. When you're ready paste here the following keys:
1) Google Client Id
2) Google Client Secret.
""");

    print("Insert 'Google Client Id':");
    String _googleClientId = stdin.readLineSync();
    // TODO: check
    updateConfiguration("google_client_id", _googleClientId.trim());
    print("Insert 'Google Client Secret':");
    String _googleClientSecret = stdin.readLineSync();
    updateConfiguration("google_client_secret", _googleClientSecret.trim());

    updateConfiguration("google_credentials","calendar.credentials.json");
    updateConfiguration("trello_token", "");
    updateConfiguration("google_scopes", ["https://www.googleapis.com/auth/calendar"]);
    print("Press <Enter> to run the app (recommended) or CTRL+C to quit");
    stdin.readLineSync();
  }
}
