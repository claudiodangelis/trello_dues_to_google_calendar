part of trello_dues_to_google_calendar;

final String CONFIG_FILE = 'config.json';

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