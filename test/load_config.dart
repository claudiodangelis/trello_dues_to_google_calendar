import 'package:trello_dues_to_google_calendar/lib.dart';
import 'package:unittest/unittest.dart';
import 'dart:io';
import 'dart:convert' show JSON;
main() {
  // TODO: more consistent tests here
  Trello2Cal t = new Trello2Cal({"id":"sb", "desc":"", "due":"", "url":""},
      "board");
  t.eventId = "123";

  Trello2Cal fromJson = new Trello2Cal.fromJson(t.toString());
  fromJson.cardId = "diverso";

  Trello2CalSet<Trello2Cal> set = new Trello2CalSet<Trello2Cal>();
  set.add(t);
  set.add(fromJson);

  List<String> list = [];

  set.forEach((Trello2Cal t2c) {
    list.add(t2c.toString());
  });

  test('Testing to/from String conversion', () {
    expect(true, t.eventId == fromJson.eventId);
  });

  Trello2CalSet<Trello2Cal> current = getCurrent();
  print(current);

/*
  updateConfiguration("config.json", "test", "hi");
  updateConfiguration("config.json", "k", "v");
  updateConfiguration("config.json", "current", list);
  * */
}