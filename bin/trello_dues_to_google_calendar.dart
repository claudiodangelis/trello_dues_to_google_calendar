import 'dart:io';
import 'dart:async';
import 'dart:convert' show JSON;

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:trello_dues_to_google_calendar/lib.dart';
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;


final Logger log = new Logger('TrelloDues2Calendar');
Map<String, dynamic> config;
final bool noPastDues = true; // TODO: Move this in config.json
List<Map<String, dynamic>> _boards;
List<Map<String, dynamic>> _cards;
cal.Calendar calendar;


main(List<String> args) {
  // Logger configuration
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] ${rec.message}');
  });

  // Parser configuration
  ArgParser parser = new ArgParser();
  bool configure;
  bool runAfterWizard = false;
  parser.addFlag('configure', negatable: false, defaultsTo: false, callback:
      (_configure) {

    configure = _configure;
    if (configure) {
      // Start configuration process
      wizard();
      print("Finished configuration.\n"
          "Press <Enter> to run the app (recommended) or CTRL+C to exit.");
      // TODO:
      String _ = stdin.readLineSync();
      runAfterWizard = true;
    }
  });

  parser.parse(args);
  print("Starting the app...");
  if (!configure || runAfterWizard) {
    log.info("Checking configuration integrity");
    if (!checkConfiguration()) {
      error("Invalid configuration. Run this app with the --configure flag");
    }
    log.info("Configuration is valid, reading it.");
    config = readConfiguration();

    log.info("Setting up Calendar client");
    var auth = new OAuth2Console(identifier: config["google_client_id"], secret:
        config["google_client_secret"], scopes: config["google_scopes"] as List,
        credentialsFilePath: config["google_credentials"]);

    calendar = new cal.Calendar(auth);
    // TODO: check if authorized
    calendar.makeAuthRequests = true;

    log.info("Checking Trello configuration");

    // Checking if Trello token is present
    // FIXME/TODO: what happens if token is invalid / expired?
    if ((config["trello_token"] as String).isEmpty) {
      log.warning("trello_token is empty");
      print("You'll now need to authorize to Trello");
      print("Please visit this URL get a token:");
      String requestTrelloAuthUrl = "https://trello.com/1/authorize?" + "key=" +
          config["trello_key"] + "&" + "name=" + "TrelloDues2Calendar" + "&" +
          "expiration=" + "never" + "&" + "response_type=" + "token";
      print(requestTrelloAuthUrl);
      print("\nPaste your token here:");
      // TODO: set a timeout for this operation
      String _trelloToken = stdin.readLineSync();

      // Updating configuration and reading it
      config = updateConfiguration("trello_token", _trelloToken);
    }

    if ((config["id_trello_calendar"] as String).isEmpty) {
      // Retrieving id trello calendar
      // TODO: add more comments
      calendar.calendarList.list(optParams: {
        "approval_prompt": "auto"
      }).then((CalendarList list) {
        try {
          String _idTrelloCalendar = list.items.singleWhere((calEntry) {
            return calEntry.summary.toLowerCase() == "trello";
          }).id;
          config = updateConfiguration("id_trello_calendar", _idTrelloCalendar);

        } catch (StateError) {
          log.severe("Trello calendar is not present");
          log.severe(StateError.toString());
          Calendar calendarRequest = new Calendar.fromJson({
            "summary": "Trello"
          });

          calendar.calendars.insert(calendarRequest).then((Calendar cal) {
            log.fine("Trello Calendar successfully created");
            config = updateConfiguration("id_trello_calendar", cal.id);
          });
        }
      });

    }
    // Preparing sets
    // `next`: all t2c items got from Trello
    // `current`: t2c items currently in Calendar
    // `skipping`: t2c items existing both in `next` and `current`
    // `adding`: t2c items exisiting in `next` and not in `current`
    // `deleting`: t2c items existing in `current` and not in `next`

    Trello2CalSet<Trello2Cal> next = new Trello2CalSet<Trello2Cal>();
    Trello2CalSet<Trello2Cal> current = getCurrent();
    Set<Trello2Cal> skipping = new Trello2CalSet<Trello2Cal>();
    ;
    Set<Trello2Cal> adding = new Trello2CalSet<Trello2Cal>();
    Set<Trello2Cal> deleting = new Trello2CalSet<Trello2Cal>();

    // Ok, ready to go
    log.info("Getting Trello cards");

    List trelloCardsFutures = [];
    getBoards().then((List<Map<String, dynamic>> boards) {
      boards.forEach((board) {
        trelloCardsFutures.add(getCards(board));
      });
      Future.wait(trelloCardsFutures).then((List<Trello2CalSet> cardResponses) {
        cardResponses.forEach((Trello2CalSet resp) {
          if (resp.isNotEmpty) {
            resp.forEach((Trello2Cal t2c) {
              next.add(t2c);
            });
          }
        });
      }).whenComplete(() {
        log.fine("Done populating `next` set");
        log.info("Checkingi f current set is empty");
        if (current.isEmpty) {
          log.info("CurrentSet empty, any next item will be added to `adding`");
          adding.addAll(next);
        } else {
          log.info("CurrentSet not empty, performing sorting");

          log.info("Populating skipping set");
          skipping = current.intersection(next);

          log.info("Populating adding set");
          adding = next.difference(next.intersection(current));

          log.info("Populating deleting set");
          deleting = current.difference(current.intersection(next));

          log.info("Dumping sets:");
          log.info("- skipping:");
          log.info(skipping.toString());
          log.info("- adding:");
          log.info(adding.toString());
          log.info("- deleting:");
          log.info(deleting.toString());

        }

        log.info("Ready to push elements to Google Calendar");
        log.info("Preparing what is going to be the next current set");
        Set<Trello2Cal> nextCurrent = new Set<Trello2Cal>();

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
              nextCurrent.add(t2c);
            });
          });
        }).whenComplete(() {
          log.info("Preparing next current to be written to file");
          List<String> nextCurrentAsList = [];

          nextCurrent.forEach((Trello2Cal t2c) {
            nextCurrentAsList.add(t2c.toString());
          });

          skipping.forEach((Trello2Cal t2c) {
            nextCurrentAsList.add(t2c.toString());
          });

          log.info("Removing old items from Calendar");

          if (deleting.isNotEmpty || deleting == null) {
            deleting.forEach((Trello2Cal t2c) {
              log.info("Deleting: ${t2c.cardDesc}");
              calendar.events.delete(config["id_trello_calendar"], t2c.eventId);
            });
          }
          config = updateConfiguration("current", nextCurrentAsList);
        });

      });
    });
  }
}

Future<Map<Trello2Cal, Event>> addTrello2Cals(Trello2Cal t2c) {
  Completer completer = new Completer();
  print(config["id_trello_calendar"]);
  log.info("Adding ${t2c.cardName} to Google Calendar");
  calendar.events.insert(new Event.fromJson(t2c.toEventJson()),
      config["id_trello_calendar"], optParams: {
    "approval_prompt": "auto"
  }).then((Event event) {

    completer.complete({
      t2c: event
    });
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
  print("Quitting.");
  exit(1);
}
