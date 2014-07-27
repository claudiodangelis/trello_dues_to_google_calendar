part of trello_dues_to_google_calendar;

final String CONFIG_FILE = 'config.json';
// TODO: add a logger
void wizard() {
  print("Starting configuration wizard. Your current configuration will be deleted. Do you want to go on? [y/n] (default: y)");
  String _answer = stdin.readLineSync();

  // Default to yes
  if (_answer == "") {
    _answer = 'y';
  }

  if (_answer[0].toLowerCase() == 'y') {
    // TODO
    // Yes
    // Scrivi file conf vuoto
    createEmptyConfiguration();
    // Acquisisci trello key
    print("""
Please visit

https://trello.com/1/appKey/generate

in order to generate Trello API Key and Secret.
""");

    print("Insert Trello API Key:");
    String _trelloApiKey = stdin.readLineSync();
    // FIXME: add a loop
    if (_trelloApiKey.trim().isEmpty) {
      print("Trello Key must not be empty");
      exit(1);
    }
    updateConfiguration("trello_key", _trelloApiKey.trim());

    // Acquisisci trello_secret
    print("Insert Trello API Secret:");
    String _trelloApiSecret = stdin.readLineSync();
    if (_trelloApiSecret.trim().isEmpty) {
      print("Trello secret must not be empty");
      exit(1);
    }
    updateConfiguration("trello_secret", _trelloApiSecret.trim());

    // Google API
    // TODO: add more instructions to create an application and get keys
    print(
"""
Good, now you need to generate Google Cloud keys. Please visit

https://cloud.google.com

create a new app, make sure to enable Google Calendar
APIs. When you're ready paste here the following keys:
1) Google Client Id
2) Google Client Secret.
""");

    // Acquisisci google_client_id
    print("Insert 'Google Client ID':");
    String _googleClientId = stdin.readLineSync();
    if (_googleClientId.trim().isEmpty) {
      print("Google Client ID must not be empty");
      exit(1);
    }

    updateConfiguration("google_client_id", _googleClientId.trim());

    // Acquisisci google_lient_secret
    print("Insert 'Google Client Secret':");
    String _googleClientSecret = stdin.readLineSync();
    if (_googleClientSecret.trim().isEmpty) {
      print("Google Client Secret must not be empty");
      exit(1);
    }

    updateConfiguration("google_client_secret", _googleClientSecret.trim());

    // Creo campi vuoti:
    // Trello token
    updateConfiguration("trello_token", "");
    // id_trello_calendar
    updateConfiguration("id_trello_calendar", "");
    // google_credentials
    updateConfiguration("google_credentials", "google.credentials.json");
    // google_scopes
    updateConfiguration("google_scopes",
        ["https://www.googleapis.com/auth/calendar"]);


  } else if (_answer[0].toLowerCase() == 'n') {
    // No
    exit(0);
  } else {
    // Errore
    print("Please answer yes or no");
    exit(1);
  }

}

String getFilePath(String path) {
  Directory _parent = new Directory.fromUri(Platform.script).parent;
  return _parent.path  + Platform.pathSeparator + CONFIG_FILE;
}

Map<String, dynamic> updateConfiguration(String key, dynamic value) {
  Map<String, dynamic> _config = readConfiguration();
  File f = new File(getFilePath(CONFIG_FILE));
  if (!f.existsSync()) {
    createEmptyConfiguration();
  }
  _config[key] = value;
  f.writeAsStringSync(JSON.encode(_config), mode: WRITE);
  return _config;
}

Map<String, dynamic> readConfiguration() {
  File f = new File(getFilePath(CONFIG_FILE));
  if (!f.existsSync()) {
    createEmptyConfiguration();
  }
  return JSON.decode(f.readAsStringSync());
}

void createEmptyConfiguration() {
  File f = new File(getFilePath(CONFIG_FILE));
  f.writeAsStringSync('{}');
}

/*
Trello2CalSet<Trello2Cal> getCurrent() {
  // TODO: write this function
  File configFile = new File(CONFIG_FILE);
  Map<String, dynamic> config = JSON.decode(configFile.readAsStringSync());
  Trello2CalSet<Trello2Cal> _set = new Trello2CalSet<Trello2Cal>();
  if (config["current"] != null) {
    List<String> currentAsList = config["current"];
    currentAsList.forEach((String json) {
      _set.add(new Trello2Cal.fromJson(json));
    });
    return _set;
  }
  updateConfiguration("current", []);
  return _set;
}

// TODO:
// TODO: if possible, pretty-print json
bool updateConfiguration(String key, dynamic value) {
  print("Updating config, key: $key");
  print("Updating config, value: $value");
  File configFile = new File(getFilePath(CONFIG_FILE));
  if (!configFile.existsSync()) {
    configFile.createSync();
    configFile.writeAsStringSync('{}');
  }
  // Read the conf
  // FIXME: what if the contents are not valid json?
  Map<String, dynamic> config = JSON.decode(configFile.readAsStringSync());
  // Add/replace the key
  config[key] = value;
  // Write down the conf again
  try {
    configFile.writeAsStringSync(JSON.encode(config), mode: WRITE);
    return true;
  } catch (FileSystemException) {
    print(FileSystemException);
  }
  return false;
}

bool configure() {

  return true;
}

Map<String, dynamic> getConfiguration() {
  File configFile = new File(getFilePath(CONFIG_FILE));
  if (!configFile.existsSync()) {
    print("Fatal error, config.json not found.");
    print("Please run this script and add the '--configure' flag");
    exit(1);
  }
  return JSON.decode(configFile.readAsStringSync());
}

String getFilePath(String path) {
  Directory _parent = new Directory.fromUri(Platform.script).parent;
  return _parent.path  + Platform.pathSeparator + CONFIG_FILE;
}
*/