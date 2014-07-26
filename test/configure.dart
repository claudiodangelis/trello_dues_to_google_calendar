import 'dart:io';
import 'package:args/args.dart';
import 'package:trello_dues_to_google_calendar/lib.dart';

main(List<String> args) {
  ArgParser parser = new ArgParser();
  parser.addFlag('configure', negatable: false, callback: startConfigure);
  parser.parse(args);
  startApplication();
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

void startApplication() {
  print("Starting the app");
}