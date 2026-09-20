import QtQuick
Item {
  id: root
  property var shell: null
  property var manifest: null
  property var settings: ({})
  property var omavoiceSettings: settings
  property var speechSettings: settings
  OmavoiceService { id: omavoice; shell: root.shell; manifest: root.manifest; settings: root.omavoiceSettings }
  SpeechService { id: speech; shell: root.shell; manifest: root.manifest }
  property alias omavoice: omavoice
  property alias speech: speech
}
