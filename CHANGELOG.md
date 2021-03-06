## 0.1.0 - 2019-07-23

* Initial release
* Firebase Authentication
* Firestore load and save services
* Widgets to handle firebase requests

## 0.2.0 - 2019-07-31

* Improve filters
* Add random string generator
* Add account screen
* Improvements and hotfixes

## 0.3.0 - 2019-10-25

* Improve doc builder
* Add sorting for queries
* Add getDocOnce and getDocsOnce queries
* Add switch tile widget
* Add notifications and badges
* Add progress button
* Add account edit screen
* Use firebase document merging
* Improvements and hotfixes

## 0.4.0 - 2020-01-17

* Update to Flutter 1.12
* Add insights to doc builder
* Improve date picker
* Improve push notifications
* Enable offline persistance
* Improve sign in and sign up
* Improve routing
* Make user extendable
* Improve descanding ordering

## 0.5.0 - 2020-06-05

* Improve authentication
* Improve filtering
* Improve user subscriber
* Support Flutter Web
* Support Firestore timestamps:
  Set `useTimestamps` in `Yust.initialize` to `true`
* Improve JSON Serialization
* Add useful widgets
* Add documentation
* Fix issues

Breaking changes:
* `createdAt` in YustDoc changed type from String to DateTime.
* Use `formatDate` and `formatTime` in YustService if you switch to Firebase timestamps. Use `formatIsoDate` and `formatIsoTime` for the old ISO Datetime format.