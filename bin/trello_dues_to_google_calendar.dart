import 'dart:io';

import 'package:trello_dues_to_google_calendar/lib.dart';
import 'package:logging/logging.dart';
import 'package:args/args.dart';
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';


final Logger log = new Logger('TrelloDues2Calendar');

main(List<String> args) {
  // Logger configuration
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] ${rec.message}');
  });

  // Parser configuration
  ArgParser parser = new ArgParser();
  bool configure;
  parser.addFlag('configure', negatable: false, defaultsTo: false,
      callback: (_configure) {

    configure = _configure;
    if (configure) {
      // Start configuration process
      wizard();
      print("Finished configuration.\n"
          "Press <Enter> to run the app (recommended) or CTRL+C to exit.");
      String _ = stdin.readLineSync();

    }
  });

  parser.parse(args);
  print("Starting the app...");
  if (!configure) {
    log.info("Checking configuration integrity");
    if (!checkConfiguration()) {
      error("Invalid configuration. Run this app with the --configure flag");
    }
    log.info("Configuration is valid, reading it.");
    Map<String, dynamic> config = readConfiguration();

    log.info("Setting up Calendar client");
    var auth = new OAuth2Console(identifier: config["google_client_id"], secret:
        config["google_client_secret"], scopes: config["google_scopes"] as List,
        credentialsFilePath: config["google_credentials"]);

    cal.Calendar calendar = new cal.Calendar(auth);
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
    // Ok, ready to go
    log.info("Getting Trello cards");

  }
}

void error(String msg) {
  print("Error: $msg");
  print("Quitting.");
  exit(1);
}
