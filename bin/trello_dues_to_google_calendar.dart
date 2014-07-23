import 'dart:io';
import 'package:logging/logging.dart';
import 'package:trello_dues_to_google_calendar/lib.dart';
import 'dart:convert' show JSON;
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as cal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';


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
  log.fine("OK");

  log.info("Checking if trello token is present and valid");
  if (config["trello_token"].isEmpty) {
    log.warning("Trello token is not present. Please visit this URL get a token:");
    String requestTrelloAuthUrl = "https://trello.com/1/authorize?" +
        "key=" + config["trello_key"] + "&" +
        "name=" + "TrelloDues2Calendar" + "&" +
        "expiration=" + "never" + "&" +
        "response_type=" + "token";
    log.warning(requestTrelloAuthUrl);
    print("Paste your token here:");
    // TODO: set a timeout for this operation
    String _trelloToken = stdin.readLineSync();
    updateConfiguration(CONFIG_FILE, "trello_token", _trelloToken);
  } else {
    // TODO: check is trello token is valid
  }

  var auth = new OAuth2Console(identifier: config["google_client_id"],
      secret: config["google_client_secret"],
      scopes: config["google_scopes"] as List,
      credentialsFilePath: config["google_credentials"]);

  cal.Calendar calendar = new cal.Calendar(auth);
  calendar.makeAuthRequests = true;

  log.info("Checking if Google keys are present");
  if (config["google_client_id"].isEmpty ||
      config["google_client_secret"].isEmpty) {
    log.severe("Google API keys not found");
    error("Please check google api");
  }
  log.fine("OK");


  log.info("Checking if id_trello_calendar is set");
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
  log.fine("OK");
  log.info("Creating empty 'next' set");
  Trello2CalSet<Trello2Cal> next = new Trello2CalSet<Trello2Cal>();
  log.info("Retrieving 'current' set");
  Trello2CalSet<Trello2Cal> current = getCurrent();
  log.info("Ready to get started retrieving cards");


}

void error(String msg) {
  print("Error: $msg");
  print("Exiting app.");
  exit(1);
}