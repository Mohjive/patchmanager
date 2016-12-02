/*
 * Copyright (C) 2014 Lucien XU <sfietkonstantin@free.fr>
 *
 * You may use this file under the terms of the BSD license as follows:
 *
 * "Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in
 *     the documentation and/or other materials provided with the
 *     distribution.
 *   * The names of its contributors may not be used to endorse or promote
 *     products derived from this software without specific prior written
 *     permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.dbus 2.0
import org.SfietKonstantin.patchmanager 2.0

Page {
    id: container

    Component.onCompleted: {
        patchmanagerDbusInterface.listPatches()
    }

    DBusInterface {
        id: patchmanagerDbusInterface
        service: "org.SfietKonstantin.patchmanager"
        path: "/org/SfietKonstantin/patchmanager"
        iface: "org.SfietKonstantin.patchmanager"
        bus: DBus.SystemBus
        function listPatches() {
            typedCall("listPatches", [], function (patches) {
                for (var i = 0; i < patches.length; i++) {
                    patchModel.append(patches[i])
                }
                indicator.visible = false
            })
        }
    }

    SilicaListView {
        id: view
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }

            MenuItem {
                text: qsTr("Web catalog")
                onClicked: pageStack.replace(Qt.resolvedUrl("WebCatalogPage.qml"))
            }

            MenuItem {
                text: qsTr("Restart preloaded services")
                visible: PatchManager.appsNeedRestart || PatchManager.homescreenNeedRestart
                onClicked: pageStack.push(Qt.resolvedUrl("RestartServicesDialog.qml"))
            }
        }

        header: PageHeader {
            title: qsTr("Installed patches")
        }
        model: ListModel {
            id: patchModel
        }
        section.criteria: ViewSection.FullString
        section.delegate: SectionHeader {
            text: section
        }
        section.property: "category"

        delegate: BackgroundItem {
            id: background
            property bool applied: model.patched
            property bool canApply: true
            property bool applying: !appliedSwitch.enabled
            function doPatch() {
                appliedSwitch.enabled = false
                appliedSwitch.busy = true
                if (!background.applied) {
                    patchmanagerDbusInterface.typedCall("applyPatch",
                                                      [{"type": "s", "value": model.patch}],
                    function (ok) {
                        if (ok) {
                            background.applied = true
                        }
                        appliedSwitch.busy = false
                        PatchManager.patchToggleService(model.patch, model.categoryCode)
                        checkApplicability()
                    })
                } else {
                    patchmanagerDbusInterface.typedCall("unapplyPatch",
                                                      [{"type": "s", "value": model.patch}],
                    function (ok) {
                        if (ok) {
                            background.applied = false
                        }
                        appliedSwitch.busy = false
                        PatchManager.patchToggleService(model.patch, model.categoryCode)
                        if (!model.available) {
                            patchModel.remove(model.index)
                        } else {
                            checkApplicability()
                        }
                    })
                }
            }

            onClicked: {
                pageStack.push(Qt.resolvedUrl("LegacyPatchPage.qml"),
                               {modelData: model, delegate: background})
            }

            function checkApplicability() {
                appliedSwitch.enabled = background.canApply
            }

            Component.onCompleted: {
                checkApplicability()
            }

            Switch {
                id: appliedSwitch
                anchors.left: parent.left; anchors.leftMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                automaticCheck: false
                checked: background.applied
                onClicked: background.doPatch()
                enabled: false
            }

            Label {
                anchors.left: appliedSwitch.right; anchors.leftMargin: Theme.paddingMedium
                anchors.right: parent.right; anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: model.name
                color: background.down ? Theme.highlightColor : Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }

        ViewPlaceholder {
            enabled: patchModel.count == 0
            text: qsTr("No patches available")
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        id: indicator
        running: visible
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
    }
}


