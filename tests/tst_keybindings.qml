import QtQuick
import QtTest
import "../Model.js" as Model

TestCase {
  name: "KeyBindings"

  function test_reservedQtKeysAreRejected() {
    var reserved = [Qt.Key_unknown, Qt.Key_Escape, Qt.Key_Shift, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Alt, Qt.Key_AltGr]
    var defaults = [{ key: Qt.Key_A, label: "A" }]
    for (var i = 0; i < reserved.length; i++) {
      verify(!Model.isBindableKey(reserved[i]))
      var loaded = Model.normalizeKeyBindings([{ key: reserved[i], label: "Reserved" }], defaults)
      compare(loaded[0].key, Qt.Key_A)
    }
  }

  function test_supportedQtKeysRetainTheirCodes() {
    var supported = [Qt.Key_A, Qt.Key_Space, Qt.Key_Slash, Qt.Key_Eacute, Qt.Key_F1, Qt.Key_Left]
    for (var i = 0; i < supported.length; i++) {
      verify(Model.isBindableKey(supported[i]))
      var loaded = Model.normalizeKeyBindings([{ key: supported[i], label: "Key" }], [{ key: Qt.Key_B, label: "B" }])
      compare(loaded[0].key, supported[i])
    }
  }
}
