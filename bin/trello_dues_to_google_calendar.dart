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
  parser.addFlag('configure', negatable: false, callback: (configure) {
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
}

