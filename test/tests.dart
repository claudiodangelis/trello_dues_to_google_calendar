import 'package:trello_dues_to_google_calendar/lib.dart';
import 'package:unittest/unittest.dart';

main() {

  var a = new Trello2Cal({"id":"a", "desc":"", "due":"", "url":""}, "board");
  var a_current = new Trello2Cal({"id":"a", "desc":"", "due":"", "url":""}, "board");
  a_current.eventId = "there's no track of eventId in original `a` right now, yet `a_current` equals `a`";

  var b_edit = new Trello2Cal({"id":"b", "desc":"new", "due":"", "url":""}, "board");
  var b = new Trello2Cal({"id":"b", "desc":"", "due":"", "url":""}, "board");
  var c = new Trello2Cal({"id":"c", "desc":"", "due":"", "url":""}, "board");
  var d = new Trello2Cal({"id":"d", "desc":"", "due":"", "url":""}, "board");
  var f = new Trello2Cal({"id":"f", "desc":"", "due":"", "url":""}, "board");
  var x_edit = new Trello2Cal({"id":"x", "desc":"new", "due":"", "url":""}, "board");
  var x = new Trello2Cal({"id":"x", "desc":"", "due":"", "url":""}, "board");
  var z = new Trello2Cal({"id":"z", "desc":"", "due":"", "url":""}, "board");

  Trello2CalSet<Trello2Cal> next = new Trello2CalSet<Trello2Cal>();
  Trello2CalSet<Trello2Cal> current = new Trello2CalSet<Trello2Cal>();

  next.addAll([a, b_edit, c, z, f, x_edit]);
  current.addAll([a, b, d, x, z]);

  test("Testing identities", () {
    expect(true, a == a_current);
    expect(false, b == b_edit);
  });



  Set<Trello2Cal> intersection = current.intersection(next);
  // If two `Trello2Cal`'s are equal, then do nothing with them
  Set<Trello2Cal> skip = intersection;
  // If a T2C is in next, but not in next<>current intersection, then add to cal
  Set<Trello2Cal> add = next.difference(intersection);
  // If a T2C is in current, but not in n<>c intersection, then delete from cal
  Set<Trello2Cal> delete = current.difference(intersection);

  // At the end of the process, we create a new "current", merging together
  // "skip" and "add" sets
  Set<Trello2Cal> newCurrent = skip.union(add);


  test("Testing set: 'skip'", () {
    expect(2, skip.length);
    expect(true, skip.containsAll([a,z]));
  });

  test("Testing set: 'add'", () {
    expect(4, add.length);
    expect(true, add.containsAll([b_edit, c, f, x_edit]));
  });

  test("Testing set: 'delete'", () {
    expect(3, delete.length);
    expect(true, delete.containsAll([b, d, x]));
  });

  test("Testing set: 'newCurrent'", () {
    expect(6, newCurrent.length);
    expect(true, newCurrent.containsAll([a,z,c,f,b_edit, x_edit]));
  });

}