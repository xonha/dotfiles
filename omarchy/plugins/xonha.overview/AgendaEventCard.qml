import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
                  property var eventData: null
                  required property var panel
                  width: parent.width
                  height: eventContentCol.implicitHeight + Style.space(12)
                  radius: Style.cornerRadius
                  color: Style.hoverFillFor(panel.contentForeground, Color.accent)

                  // Calendar color accent strip
                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.space(4)
                    width: Style.space(3)
                    radius: Style.cornerRadius > 0 ? width / 2 : 0
                    color: eventData.color || Color.accent
                  }

                  // Delete button for writable events
                  PanelActionButton {
                    visible: Boolean(eventData.writable)
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(4)
                    iconText: "󰆴"
                    tooltipText: "Delete event from " + (eventData.calendar || "calendar")
                    foreground: panel.contentForeground
                    fontFamily: panel.contentFontFamily
                    opacity: 0.65
                    onClicked: panel.deleteEvent(eventData)
                  }

                  Column {
                    id: eventContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(14)
                    anchors.rightMargin: eventData.writable ? Style.space(32) : Style.space(10)
                    spacing: Style.space(2)

                    Row {
                      width: parent.width
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText
                        text: eventData.allDay ? "ALL DAY" : panel.eventTimeRange(eventData, " – ")
                        color: Qt.darker(panel.contentForeground, 1.4)
                        font.family: panel.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText
                        visible: eventData.calendar !== ""
                        text: "· " + eventData.calendar.toUpperCase()
                        color: Qt.darker(panel.contentForeground, 1.8)
                        font.family: panel.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width
                      text: eventData.title
                      color: panel.contentForeground
                      font.family: panel.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Row {
                      visible: eventData.location && eventData.location.length > 0
                      width: parent.width
                      spacing: Style.space(4)

                      Text {
                        textFormat: Text.PlainText
                        text: "󰍎"
                        color: Qt.darker(panel.contentForeground, 1.6)
                        font.family: panel.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width - Style.space(16)
                        text: eventData.location
                        color: eventData.meetingUrl ? Color.accent : Qt.darker(panel.contentForeground, 1.6)
                        font.family: panel.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.underline: Boolean(locMouse.containsMouse && eventData.meetingUrl)
                        elide: Text.ElideRight

                        MouseArea {
                          id: locMouse
                          anchors.fill: parent
                          hoverEnabled: Boolean(eventData.meetingUrl)
                          cursorShape: eventData.meetingUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                          onClicked: {
                            if (eventData.meetingUrl) {
                              panel.openExternalUrl(eventData.meetingUrl, eventData.calendar)
                              panel.close()
                            }
                          }
                        }
                      }
                    }

                    // One-Click Join Meeting Link
                    Row {
                      spacing: Style.space(6)
                      topPadding: Style.space(3)

                      Rectangle {
                        id: joinBtn
                        visible: panel.enableMeetingLinks && Boolean(eventData.meetingUrl && eventData.meetingUrl.length > 0)
                        width: joinRow.implicitWidth + Style.space(16)
                        height: Style.space(22)
                        radius: Style.cornerRadius > 0 ? 4 : 0
                        color: joinMouse.containsMouse ? Color.accent : Style.hoverFillFor(panel.contentForeground, Color.accent)
                        border.width: 1
                        border.color: Color.accent

                        Row {
                          id: joinRow
                          anchors.centerIn: parent
                          spacing: Style.space(5)

                          Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰕧"
                            color: joinMouse.containsMouse ? Color.background : Color.accent
                            font.family: panel.contentFontFamily
                            font.pixelSize: Style.font.caption
                          }

                          Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: eventData.meetingProvider === "Google Meet"
                              ? "Join Meet"
                              : (eventData.meetingProvider ? "Join " + eventData.meetingProvider : "Join Meeting")
                            color: joinMouse.containsMouse ? Color.background : panel.contentForeground
                            font.family: panel.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }

                        MouseArea {
                          id: joinMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            panel.openExternalUrl(eventData.meetingUrl, eventData.calendar)
                            panel.close()
                          }
                        }

                        PanelToolTip {
                          text: eventData.meetingUrl
                          fontFamily: panel.contentFontFamily
                        }
                      }

                      Rectangle {
                        width: openCalendarRow.implicitWidth + Style.space(16)
                        height: Style.space(22)
                        radius: Style.cornerRadius > 0 ? 4 : 0
                        color: openCalendarMouse.containsMouse ? Color.accent : "transparent"
                        border.width: 1
                        border.color: Qt.darker(panel.contentForeground, 1.5)

                        Row {
                          id: openCalendarRow
                          anchors.centerIn: parent
                          spacing: Style.space(5)

                          Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰃭"
                            color: openCalendarMouse.containsMouse ? Color.background : panel.contentForeground
                            font.family: panel.contentFontFamily
                            font.pixelSize: Style.font.caption
                          }

                          Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Open Calendar"
                            color: openCalendarMouse.containsMouse ? Color.background : panel.contentForeground
                            font.family: panel.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }

                        MouseArea {
                          id: openCalendarMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            panel.openExternalUrl("https://calendar.google.com", eventData.calendar)
                            panel.close()
                          }
                        }
                      }
                    }
                  }
                }
