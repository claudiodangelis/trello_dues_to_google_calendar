import 'dart:io';
import 'dart:convert' show JSON;
import 'package:http/http.dart' as http;
import 'package:google_oauth2_client/google_oauth2_console.dart';
import 'package:google_calendar_v3_api/calendar_v3_api_console.dart' as gcal;
import 'package:google_calendar_v3_api/calendar_v3_api_client.dart';
import 'package:logging/logging.dart';

// Trello configuration
final String TRELLO_CONFIG_FILE = "trello.config.json";
String trelloKey;
String trelloSecret;

// Google calendar configuration
final String GCALENDAR_CONFIG_FILE = "gcalendar.config.json";
final List<String> SCOPES = ["https://www.googleapis.com/auth/calendar"];
String gcalendarClientId;
String gcalendarClientSecret;
String gcalendarAccessToken;
String gcalendarTokenType;
String gcalendarExpiresIn;
String gcalendarRefreshToken;

// Application configuration
final bool noPastDues = true;
List<Map<String, dynamic>> boards;
List<Map<String, dynamic>> cards;
String TRELLO_CALENDAR_ID = "dn7epujj78eecavdpdfsroq3dc@group.calendar.google.com";

main() {
  // TODO: add --debug flag

  // TODO: using logger only if --debug=true
  // Setting up the logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] ${rec.message}');
  });
  final Logger log = new Logger('TrelloDues2Calendar');

  // Start
  log.info("Starting");
  // Reading Trello configuration file
  log.info("Retrieving Trello API data...");
  // TODO: rename
  File trelloFile = new File(TRELLO_CONFIG_FILE);
  if (trelloFile.existsSync()) {
    // Looking for "trello_key" and "trello_secret"
    // TODO: get this to work async
    Map<String, String> trello = JSON.decode(trelloFile.readAsStringSync());
    if (trello["key"] != null && trello["secret"] != null) {
      log.fine("Trello configuration file is present");
      // Ok, there's everything
      trelloKey  = trello["key"];
      trelloSecret = trello["secret"];
      // There's the token?
      // TODO: find an elegant solution for this
      bool tokenWasEmpty = false;
      if (trello["token"] == null) {
        tokenWasEmpty = true;
        log.info("There is no token, prompting the user...");
        // Nope, prompting user, asking it to open the URL then paste the token
        print("Trello token not present."
            "Please visit this URL then paste token:");
        String requestTrelloAuthUrl = "https://trello.com/1/authorize?" +
            "key=" + trelloKey + "&" +
            "name=" + "TrelloDues2Calendar" + "&" +
            "expiration=" + "never" + "&" +
            "response_type=" + "token";

        print(requestTrelloAuthUrl);
        String trelloToken = stdin.readLineSync();
        if (trelloToken.trim().isEmpty) {
          log.severe("User entered blank input");
          // User entered no input
          // TODO: handle this
          exit(1);
        }
        log.info("Setting token");
        trello["token"] = trelloToken.trim();

      }
      // TODO: refactor this
      if (tokenWasEmpty) {
        log.info("Update configuration");
        // Update configuration
        // TODO: get this to work async
        // TODO: write pretty printed JSO
        trelloFile.writeAsStringSync(JSON.encode(trello));
      }

      log.info("Retrieving Google Calendar Data...");
      // Looking for config file
      File gcalendarFile = new File(GCALENDAR_CONFIG_FILE);
      if (gcalendarFile.existsSync()) {
        // Looking for data
        Map<String, String> gcalendar =
            JSON.decode(gcalendarFile.readAsStringSync());

        if (gcalendar["client_id"] != null &&
            gcalendar["client_secret"] != null) {

          gcalendarClientId = gcalendar["client_id"];
          gcalendarClientSecret = gcalendar["client_secret"];
          // Preparing for creating a client
          var calendar;
          // There's the token?
          if (gcalendar["token"] == null) {
            // Token not present
            // Begin the process to get the token
            var auth = new OAuth2Console(identifier: gcalendarClientId,
                secret: gcalendarClientSecret, scopes: SCOPES,
                credentialsFilePath: "calendar.credentials.json");

            gcal.Calendar calendar = new gcal.Calendar(auth);

            calendar.makeAuthRequests = true;

            // FIXME: this is not the most elegant way to authenticate for the
            // first time
            calendar.calendarList.list().whenComplete(() {
              // TODO: controlla se calendario trello esiste

              // Beginning retrieving Trello cards with due dates
              // TODO: too many string literals here
              String boardsUrl = "https://api.trello.com/1/members/me/boards?" +
                                 "filter=open" + "&" +
                                 "key=" + trello["key"] + "&" +
                                 "token=" + trello["token"];
              http.get(boardsUrl).then((resp) {
                // All the boards
                boards = JSON.decode(resp.body);
                // Getting now all the cards
                boards.forEach((Map<String, dynamic> board) {
                  // Board id
                  String boardId = board["id"];
                  String cardsUrl = "https://api.trello.com/1/boards/$boardId/cards?" +
                      "card_fields=due" + "&" +
                      "key=" + trello["key"] + "&" +
                      "token=" + trello["token"];

                  // Requesting all cards
                  http.get(cardsUrl).then((resp) {
                    cards = JSON.decode(resp.body);
                    cards.forEach((Map<String, dynamic> card) {
                      if (card["due"] != null) {
                        DateTime now = new DateTime.now();
                        int compare = now.compareTo(DateTime.parse(card["due"]));
                        if (!noPastDues || (noPastDues && compare.isNegative)) {
                          // This is the card we're looking for
                          // TODO-FIXME: keep a local map of
                          // card_id : calendar_event_id
                          // to check if event has already been added or edited

                          // Create calendar event
                          // Get Trello calendar ID (TODO, harcoded right now)

                          String description = card["desc"] != null
                            ? card["desc"] + "\n\n---\n"
                            : "";

                          description += "View in Trello:\n" + card["url"];

                          var eventMap = {
                            "start": {
                              "dateTime": card["due"]
                            },
                            "end": {
                              "dateTime": card["due"]
                            },
                            "summary": board["name"] + ": " + card["name"],
                            "description": description
                          };

                          calendar.events.insert(new Event.fromJson(eventMap),
                              TRELLO_CALENDAR_ID, optParams: {"approval_prompt": "auto"}).whenComplete(() {
                            log.fine("Insertion complete");
                            log.fine(eventMap["summary"]);
                          });

                        }
                      }
                    });
                  });
                });
              });
            });

          } else {
            // Yes, the token is present
            log.fine("Trello token is present");
          }

        } else {
          // GCalendar config data not valid
          // TODO: handle this
          log.severe("Google Calendar configuration file is not valid");
          exit(1);
        }

      } else {
        // Gcalendar config file does not exist
        // TODO handle this
        exit(1);
      }

    } else {
      // Invalid config file
      // TODO: handle this
      exit(1);
    }
  } else {
    // File does not exist
    // TODO: handle this
    exit(1);
  }
}
