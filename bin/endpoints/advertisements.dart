import 'dart:convert';

import 'package:firebase_dart/core.dart';
import 'package:firebase_dart/database.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';

import '../adv.dart';
import '../animal.dart';
import '../configurations.dart';

class Advertisements {
  Future<FirebaseApp> initApp() async {
    late FirebaseApp app;

    try {
      app = Firebase.app();
    } catch (e) {
      app = await Firebase.initializeApp(
          options: FirebaseOptions.fromMap(Configurations.firebaseConfig));
    }

    return app;
  }

  Handler get handler {
    final router = Router();

    router.post('/add', (Request request) async {
      final requestData = await request.readAsString();
      if (requestData.isEmpty) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'No data found'}),
            headers: {'Content-Type': 'application/json'});
      }

      final payload = jsonDecode(requestData);

      final animal = Animal.fromJson(payload['animal']);
      final state = payload['state']; //pierdut gasit
      final uid = payload['id_user'];
      final latitude = payload['latitude'];
      final longitude = payload['longitude'];

      if (animal == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'Missing animal data'}),
            headers: {'Content-Type': 'application/json'});
      } else if (uid == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'Missing id_user'}),
            headers: {'Content-Type': 'application/json'});
      } else if (state == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'Missing state'}),
            headers: {'Content-Type': 'application/json'});
      } else if (latitude == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'Missing latitude'}),
            headers: {'Content-Type': 'application/json'});
      } else if (longitude == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'error': 'Missing longitude'}),
            headers: {'Content-Type': 'application/json'});
      }

      try {
        final app = await initApp();
        final db =
            FirebaseDatabase(app: app, databaseURL: Configurations.databaseUrl);
        final ref = db.reference().child('animals');
        final newPostKey = ref.push().key;
        animal.setId(newPostKey!);
        await ref.child(newPostKey).update({
          "name": animal.name,
          "rasa": animal.rasa,
          "description": animal.description,
          "photoUrl": animal.photoUrl,
          "found": animal.found
        });

        final ref2 = db.reference().child('advertisements');
        final newPostKey2 = ref2.push().key;
        await ref2.child(newPostKey2!).update({
          "id_animal": newPostKey,
          "id_user": uid,
          "created_at": DateTime.now().toString(),
          "state": state,
          "latitude": latitude,
          "longitude": longitude,
        });

        return Response.ok(jsonEncode({'success': true}), headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Credentials': 'true'
        });
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'success': false, 'error': e.toString()}),
            headers: {'Content-Type': 'application/json'});
      }
    });

    router.get('/get/<state>', (Request request, String state) async {
      var app = await initApp();

      final db =
          FirebaseDatabase(app: app, databaseURL: Configurations.databaseUrl);
      final ref = db.reference().child("advertisements");
      List<Advertisement> responseData = [];

      final value = await ref.get();
      if (value != null) {
        Map<dynamic, dynamic> array = value;
        List<Future> fetchAnimalFutures = [];

        array.forEach((key, value) {
          if (value['state'] == state) {
            Future fetchAnimal = db
                .reference()
                .child("animals")
                .child(value['id_animal'])
                .once()
                .then((value2) {
              Map<String, dynamic> animalData = value2.value;
              Animal animal = Animal.fromJson(animalData);
              animal.setId(value2.key!);
              Advertisement advertisement =
                  Advertisement.fromJson(value, key, animal);
              responseData.add(advertisement);
            });

            fetchAnimalFutures.add(fetchAnimal);
          }
        });

        await Future.wait(fetchAnimalFutures);
      }

      return Response.ok(json.encode(responseData), headers: {
        'content-type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      });
    });
    return router;
  }
}
