import 'dart:io';
import 'package:logging/logging.dart';
import 'dart:convert' show JSON;
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';

final String CONFIG_FILE = "config.json";


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

  Calendar trelloCal;

  if (config["id_trello_calendar"].isEmpty) {
    log.warning("Trello calendar id not set");
    log.info("Looking for trello calendar id in Google Calendar");
    calendar.calendarList.list(
        optParams: {"approval_prompt": "auto"}).then((CalendarList list) {

      try {
        trelloCal = list.items.singleWhere((calEntry) {
          return calEntry.summary.toLowerCase() == "trello";
        }) as Calendar;


      } catch (StateError) {
        log.severe("Trello calendar is not present");
        Calendar calendarRequest = new Calendar.fromJson({"summary": "Trello"});
        calendar.calendars.insert(calendarRequest).then((Calendar cal) {
          log.fine("Calendario creato con successo");
          trelloCal = cal;
        });
      }
    });
  }
}

void error(String msg) {
  print(msg);
  print("Exiting app.");
  exit(1);
}