library yust;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';

import 'models/yust_doc_setup.dart';
import 'models/yust_user.dart';
import 'yust_service.dart';
import 'yust_store.dart';

class Yust {
  static final store = YustStore();
  static final service = YustService();
  static YustDocSetup<YustUser> userSetup;

  static void initialize({YustDocSetup userSetup}) {
    Yust.userSetup = userSetup ?? YustUser.setup;
    Firestore.instance.settings(persistenceEnabled: true);

    Yust.store.authState = AuthState.waiting;
    FirebaseAuth.instance.onAuthStateChanged.listen(

        ///Calls [Yust.store.setState] on each event.
        (fireUser) async {
      if (fireUser != null) {
        YustUser user = await Yust.service
            .getDoc<YustUser>(Yust.userSetup, fireUser.uid)
            .first;

        Yust.store.setState(() {
          Yust.store.authState =
              (user == null) ? AuthState.signedOut : AuthState.signedIn;
          if (user != null) {
            Yust.store.currUser = user;
          }
        });
      } else {
        Yust.store.setState(() {
          Yust.store.authState = AuthState.signedOut;
          Yust.store.currUser = null;
        });
      }
    });
    // FirebaseAuth.instance.onAuthStateChanged.asyncMap<YustUser>((fireUser) {
    //   return Future<YustUser>(() async {
    //     if (fireUser == null) {
    //       return null;
    //     } else {
    //       return await Yust.service.getDocOnce<YustUser>(Yust.userSetup, fireUser.uid);
    //     }
    //   });
    // }).listen((user) {
    //   Yust.store.setState(() {
    //     Yust.store.authState = (user == null) ? AuthState.signedOut : AuthState.signedIn;
    //     if (user != null) {
    //       Yust.store.currUser = user;
    //     }
    //   });
    // });

    if (!kIsWeb) {
      PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        Yust.store.setState(() {
          Yust.store.packageInfo = packageInfo;
        });
      });
    }
  }
}
