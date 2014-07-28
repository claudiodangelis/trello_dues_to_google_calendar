import 'dart:io';

import 'package:trello_dues_to_google_calendar/lib.dart';
import 'package:logging/logging.dart';
import 'package:args/args.dart';

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
    log.info("Configuration is valid.");
  }
}

void error(String msg) {
  print("Error: $msg");
  print("Quitting.");
  exit(1);
}
