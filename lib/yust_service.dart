import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yust/yust_store.dart';

import 'models/yust_doc.dart';
import 'models/yust_doc_setup.dart';
import 'models/yust_exception.dart';
import 'models/yust_user.dart';
import 'yust.dart';

class YustService {
  final FirebaseAuth fireAuth = FirebaseAuth.instance;

  Future<void> signIn(
    BuildContext context,
    String email,
    String password, {
    String targetRouteName,
    dynamic targetRouteArguments,
  }) async {
    if (email == null || email == '') {
      throw YustException('Die E-Mail darf nicht leer sein.');
    }
    if (password == null || password == '') {
      throw YustException('Das Passwort darf nicht leer sein.');
    }
    await fireAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await waitForSignIn(
      Navigator.of(context),
      targetRouteName: targetRouteName,
      targetRouteArguments: targetRouteArguments,
    );
  }

  Future<void> signUp(
    BuildContext context,
    String firstName,
    String lastName,
    String email,
    String password,
    String passwordConfirmation, {
    YustGender gender,
    String targetRouteName,
    dynamic targetRouteArguments,
  }) async {
    if (firstName == null || firstName == '') {
      throw YustException('Der Vorname darf nicht leer sein.');
    }
    if (lastName == null || lastName == '') {
      throw YustException('Der Nachname darf nicht leer sein.');
    }
    if (password != passwordConfirmation) {
      throw YustException('Die Passwörter stimmen nicht überein.');
    }
    final AuthResult authResult = await fireAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = Yust.userSetup().newDoc()
      ..email = email
      ..firstName = firstName
      ..lastName = lastName
      ..gender = gender
      ..id = authResult.user.uid;

    await Yust.service().saveDoc<YustUser>(Yust.userSetup(), user);

    await waitForSignIn(
      Navigator.of(context),
      targetRouteName: targetRouteName,
      targetRouteArguments: targetRouteArguments,
    );
  }

  Future<void> signOut(BuildContext context) async {
    await fireAuth.signOut();

    final completer = Completer<void>();
    void complete() => completer.complete();

    Yust.store().addListener(complete);

    ///Awaits that the listener registered in the [Yust.initialize] method completed its work.
    ///This also assumes that [fireAuth.signOut] was successfull, of which I do not know how to be certain.
    await completer.future;
    Yust.store().removeListener(complete);

    Navigator.of(context).pushNamedAndRemoveUntil(
      Navigator.defaultRouteName,
      (_) => false,
    );
  }

  Future<void> waitForSignIn(
    NavigatorState navigatorState, {
    String targetRouteName,
    dynamic targetRouteArguments,
  }) async {
    targetRouteName ??= Navigator.defaultRouteName;

    final completer = Completer<bool>();

    void Function() listener = () {
      switch (Yust.store().authState) {
        case AuthState.signedIn:
          completer.complete(true);
          break;
        case AuthState.signedOut:
          completer.complete(false);
          break;
        case AuthState.waiting:
          break;
      }
    };

    Yust.store().addListener(listener);

    bool successful = await completer.future;

    Yust.store().removeListener(listener);

    if (successful) {
      navigatorState.pushNamedAndRemoveUntil(
        targetRouteName,
        (_) => false,
        arguments: targetRouteArguments,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (email == null || email == '') {
      throw YustException('Die E-Mail darf nicht leer sein.');
    }
    await fireAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> changeEmail(String email, String password) async {
    final AuthResult authResult = await fireAuth.signInWithEmailAndPassword(
      email: Yust.store().currUser.email,
      password: password,
    );
    await authResult.user.updateEmail(email);
    Yust.store().setState(() {
      Yust.store().currUser.email = email;
    });
    Yust.service().saveDoc<YustUser>(Yust.userSetup(), Yust.store().currUser);
  }

  Future<void> changePassword(String newPassword, String oldPassword) async {
    final AuthResult authResult = await fireAuth.signInWithEmailAndPassword(
      email: Yust.store().currUser.email,
      password: oldPassword,
    );
    await authResult.user.updatePassword(newPassword);
  }

  /// Initialises a document with an id and the time it was created.
  ///
  /// Optionally an existing document can be given, which will still be
  /// assigned a new id becoming a new document if it had an id previously.
  T initDoc<T extends YustDoc>(YustDocSetup<T> modelSetup, [T doc]) {
    if (doc == null) {
      doc = modelSetup.newDoc();
    }
    doc.id = Firestore.instance
        .collection(modelSetup.collectionName)
        .document()
        .documentID;
    doc.createdAt = toStandardDateTimeString(DateTime.now());
    if (modelSetup.forEnvironment) {
      doc.envId = Yust.store().currUser.currEnvId;
    }
    if (modelSetup.forUser) {
      doc.userId = Yust.store().currUser.id;
    }
    if (modelSetup.onInit != null) {
      modelSetup.onInit(doc);
    }
    return doc;
  }

  ///[filterList] each entry represents a condition that has to be met.
  ///All of those conditions must be true for each returned entry.
  ///
  ///Consists at first of the column name followed by either 'ASC' or 'DESC'.
  ///Multiple of those entries can be repeated.
  ///
  ///[filterList] may be null.
  Stream<List<T>> getDocs<T extends YustDoc>(
    YustDocSetup<T> modelSetup, {
    List<List<dynamic>> filterList,
    List<String> orderByList,
  }) {
    Query query = Firestore.instance.collection(modelSetup.collectionName);
    if (modelSetup.forEnvironment) {
      query = query.where('envId', isEqualTo: Yust.store().currUser.currEnvId);
    }
    if (modelSetup.forUser) {
      query = query.where('userId', isEqualTo: Yust.store().currUser.id);
    }
    query = _executeFilterList(query, filterList);
    query = _executeOrderByList(query, orderByList);
    return query.snapshots().map((snapshot) {
      // print('Get docs: ${modelSetup.collectionName}');
      return snapshot.documents.map((docSnapshot) {
        final doc = modelSetup.fromJson(docSnapshot.data);
        if (modelSetup.onMigrate != null) {
          modelSetup.onMigrate(doc);
        }
        return doc;
      }).toList();
    });
  }

  Future<List<T>> getDocsOnce<T extends YustDoc>(
    YustDocSetup<T> modelSetup, {
    List<List<dynamic>> filterList,
    List<String> orderByList,
  }) {
    Query query = Firestore.instance.collection(modelSetup.collectionName);
    query = _executeStaticFilters(query, modelSetup);
    query = _executeFilterList(query, filterList);
    query = _executeOrderByList(query, orderByList);
    return query.getDocuments(source: Source.server).then((snapshot) {
      // print('Get docs once: ${modelSetup.collectionName}');
      return snapshot.documents.map((docSnapshot) {
        final doc = modelSetup.fromJson(docSnapshot.data);
        if (modelSetup.onMigrate != null) {
          modelSetup.onMigrate(doc);
        }
        return doc;
      }).toList();
    });
  }

  Stream<int> getNumberMatching<T extends YustDoc>(
    YustDocSetup modelSetup, {
    List<List<dynamic>> filterList,
  }) {
    Query query = Firestore.instance.collection(modelSetup.collectionName);
    query = _executeStaticFilters(query, modelSetup);
    query = _executeFilterList(query, filterList);

    return query.snapshots().map<int>(
          (QuerySnapshot querySnapshot) => querySnapshot.documents.length,
        );
  }

  Future<int> getNumberMatchingOnce<T extends YustDoc>(
    YustDocSetup<T> modelSetup, {
    List<List<dynamic>> filterList,
  }) async {
    Query query = Firestore.instance.collection(modelSetup.collectionName);
    query = _executeStaticFilters(query, modelSetup);
    query = _executeFilterList(query, filterList);

    final QuerySnapshot querySnapshot =
        await query.getDocuments(source: Source.server);

    return querySnapshot.documents.length;
  }

  Stream<T> getDoc<T extends YustDoc>(
    YustDocSetup<T> modelSetup,
    String id,
  ) {
    return Firestore.instance
        .collection(modelSetup.collectionName)
        .document(id)
        .snapshots()
        .map((snapshot) {
      // print('Get doc: ${modelSetup.collectionName} $id');
      if (snapshot.data == null) return null;
      final doc = modelSetup.fromJson(snapshot.data);
      if (modelSetup.onMigrate != null) {
        modelSetup.onMigrate(doc);
      }
      return doc;
    });
  }

  Future<T> getDocOnce<T extends YustDoc>(
    YustDocSetup<T> modelSetup,
    String id,
  ) {
    return Firestore.instance
        .collection(modelSetup.collectionName)
        .document(id)
        .get(source: Source.server)
        .then((snapshot) {
      // print('Get doc: ${modelSetup.collectionName} $id');
      final doc = modelSetup.fromJson(snapshot.data);
      if (modelSetup.onMigrate != null) {
        modelSetup.onMigrate(doc);
      }
      return doc;
    });
  }

  ///Emits null events if no document was found.
  Stream<T> getFirstDoc<T extends YustDoc>(
    YustDocSetup<T> modelSetup,
    List<List<dynamic>> filterList, {
    List<String> orderByList,
  }) {
    Query query = Firestore.instance.collection(modelSetup.collectionName);
    if (modelSetup.forEnvironment) {
      query = query.where('envId', isEqualTo: Yust.store().currUser.currEnvId);
    }
    if (modelSetup.forUser) {
      query = query.where('userId', isEqualTo: Yust.store().currUser.id);
    }
    query = _executeFilterList(query, filterList);
    query = _executeOrderByList(query, orderByList);
    return query.snapshots().map<T>((snapshot) {
      if (snapshot.documents.length > 0) {
        final doc = modelSetup.fromJson(snapshot.documents[0].data);
        if (modelSetup.onMigrate != null) {
          modelSetup.onMigrate(doc);
        }
        return doc;
      } else {
        return null;
      }
    });
  }

  /// If [merge] is false a document with the same name
  /// will be overwritten instead of trying to merge the data.
  ///
  /// Returns the document how it was saved to
  /// accommodate for a possible merge with the data online.
  Future<T> saveDoc<T extends YustDoc>(
    YustDocSetup<T> modelSetup,
    T doc, {
    bool merge = true,
  }) async {
    var collection = Firestore.instance.collection(modelSetup.collectionName);
    if (doc.createdAt == null) {
      doc.createdAt = toStandardDateTimeString(DateTime.now());
    }
    if (doc.userId == null && modelSetup.forUser) {
      doc.userId = Yust.store().currUser.id;
    }
    if (doc.envId == null && modelSetup.forEnvironment) {
      doc.envId = Yust.store().currUser.currEnvId;
    }
    if (modelSetup.onSave != null) {
      await modelSetup.onSave(doc);
    }

    if (doc.id != null) {
      await collection.document(doc.id).setData(doc.toJson(), merge: merge);
    } else {
      var ref = await collection.add(doc.toJson());
      doc.id = ref.documentID;
      await ref.setData(doc.toJson());
    }

    return getDocOnce<T>(modelSetup, doc.id);
  }

  Future<void> deleteDocs<T extends YustDoc>(
    YustDocSetup<T> modelSetup, {
    List<List<dynamic>> filterList,
  }) async {
    final docs = await getDocsOnce(modelSetup, filterList: filterList);
    for (var doc in docs) {
      await deleteDoc(modelSetup, doc);
    }
  }

  Future<void> deleteDoc<T extends YustDoc>(
    YustDocSetup<T> modelSetup,
    T doc,
  ) async {
    if (modelSetup.onDelete != null) {
      await modelSetup.onDelete(doc);
    }
    var docRef = Firestore.instance
        .collection(modelSetup.collectionName)
        .document(doc.id);
    await docRef.delete();
  }

  /// Initialises a document and saves it.
  ///
  /// If [onInitialised] is provided, it will be called and
  /// waited for after the document is initialised.
  ///
  /// An existing document can be given which will instead be initialised.
  Future<T> saveNewDoc<T extends YustDoc>(
    YustDocSetup<T> modelSetup, {
    T doc,
    Future<void> Function(T) onInitialised,
  }) async {
    doc = initDoc<T>(modelSetup, doc);

    if (onInitialised != null) {
      await onInitialised(doc);
    }

    await saveDoc<T>(modelSetup, doc);

    return doc;
  }

  void showAlert(BuildContext context, String title, String message) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              FlatButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<bool> showConfirmation(
      BuildContext context, String title, String action) {
    return showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            actions: <Widget>[
              FlatButton(
                child: Text(action),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
              FlatButton(
                child: Text("Abbrechen"),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
            ],
          );
        });
  }

  Future<String> showTextFieldDialog(
      BuildContext context, String title, String placeholder, String action) {
    final controller = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: placeholder),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(action),
                onPressed: () {
                  Navigator.of(context).pop(controller.text);
                },
              ),
              FlatButton(
                child: Text("Abbrechen"),
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
              ),
            ],
          );
        });
  }

  /// Creates a string formatted just as the [YustDoc.createdAt] property is.
  String toStandardDateTimeString(DateTime dateTime) =>
      dateTime.toIso8601String();

  /// Returns null if the string cannot be parsed.
  DateTime fromStandardDateTimeString(String dateTimeString) =>
      DateTime.tryParse(dateTimeString);

  /// Does not return null.
  String formatDate(String isoDate, {String format}) {
    if (isoDate == null) return '';

    var now = DateTime.parse(isoDate);
    var formatter = DateFormat(format ?? 'dd.MM.yyyy');
    return formatter.format(now);
  }

  /// Does not return null.
  String formatTime(String isoDate, {String format}) {
    if (isoDate == null) return '';

    var now = DateTime.parse(isoDate);
    var formatter = DateFormat(format ?? 'HH:mm');
    return formatter.format(now);
  }

  String randomString({int length = 8}) {
    final rnd = new Random();
    const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
    var result = "";
    for (var i = 0; i < length; i++) {
      result += chars[rnd.nextInt(chars.length)];
    }
    return result;
  }

  Query _executeStaticFilters<T extends YustDoc>(
    Query query,
    YustDocSetup<T> modelSetup,
  ) {
    if (modelSetup.forEnvironment) {
      query = query.where('envId', isEqualTo: Yust.store().currUser.currEnvId);
    }
    if (modelSetup.forUser) {
      query = query.where('userId', isEqualTo: Yust.store().currUser.id);
    }
    return query;
  }

  ///[filterList] may be null.
  ///If it is not each contained list may not be null
  ///and has to have a length of three.
  Query _executeFilterList(Query query, List<List<dynamic>> filterList) {
    if (filterList != null) {
      for (var filter in filterList) {
        assert(
          filter != null && filter.length == 3,
          'A condition does not have the usual number of three elements: operand operator operand',
        );
        var operand1 = filter[0], operator = filter[1], operand2 = filter[2];

        switch (operator) {
          case '==':
            query = query.where(operand1, isEqualTo: operand2);
            break;
          case '<':
            query = query.where(operand1, isLessThan: operand2);
            break;
          case '<=':
            query = query.where(operand1, isLessThanOrEqualTo: operand2);
            break;
          case '>':
            query = query.where(operand1, isGreaterThan: operand2);
            break;
          case '>=':
            query = query.where(operand1, isGreaterThanOrEqualTo: operand2);
            break;
          case 'in':
            // If null is passed for the filter list, no filter is applied at all.
            // If an empty list is passed, an error is thrown.
            // I think that it should behave the same and return no data.

            if (operand2 == null) {
            } else if (operand2 is Iterable) {
              if ((operand2 as Iterable).isEmpty) {
                operand2 = null;
              } else {
                final List typedOperand2 = operand2.toList();
                final onlyStringElements = typedOperand2.whereType<String>();

                assert(
                  typedOperand2.length == onlyStringElements.length,
                  'One of the operands is not of type string.',
                );

                operand2 = typedOperand2;
              }
            }

            query = query.where(operand1, whereIn: operand2);

            // Makes sure that no data is returned.
            if (operand2 == null) {
              query = query.where(operand1, isEqualTo: true, isNull: true);
            }
            break;
          case 'arrayContains':
            query = query.where(operand1, arrayContains: operand2);
            break;
          case 'isNull':
            query = query.where(operand1, isNull: operand2);
            break;
          default:
            throw 'The operator "$operator" is not supported.';
        }
      }
    }
    return query;
  }

  Query _executeOrderByList(Query query, List<String> orderByList) {
    if (orderByList != null) {
      orderByList.asMap().forEach((index, orderBy) {
        if (orderBy.toUpperCase() != 'DESC' && orderBy.toUpperCase() != 'ASC') {
          final desc = (index + 1 < orderByList.length &&
              orderByList[index + 1].toUpperCase() == 'DESC');
          query = query.orderBy(orderBy, descending: desc);
        }
      });
    }
    return query;
  }
}
