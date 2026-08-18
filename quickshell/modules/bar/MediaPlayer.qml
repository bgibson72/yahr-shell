import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../.."

Item {
    id: mediaPlayer
    implicitWidth: visible ? row.implicitWidth + 12 : 0
    implicitHeight: 40
    visible: Settings.showMediaPlayer && hasPlayer

    readonly property bool hasPlayer: activePlayer !== null
    property MprisPlayer activePlayer: null

    // Prefer Spotify over anything else, otherwise take the first player seen.
    Repeater {
        model: Mpris.players

        delegate: Item {
            required property MprisPlayer modelData

            Component.onCompleted: {
                if (modelData.identity === "Spotify"
                        || modelData.desktopEntry === "spotify"
                        || mediaPlayer.activePlayer === null) {
                    mediaPlayer.activePlayer = modelData
                }
            }

            Component.onDestruction: {
                if (mediaPlayer.activePlayer === modelData)
                    mediaPlayer.activePlayer = null
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: prevGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: "\udb81\udcae"
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeNormal
            opacity: activePlayer && activePlayer.canGoPrevious ? 1.0 : 0.35
            color: ThemeManager.fgSecondary
            scale: prevArea.pressed ? ThemeManager.iconPressScale : (prevArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            MouseArea {
                id: prevArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: activePlayer && activePlayer.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous()
            }
        }

        Text {
            id: playPauseGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
                  ? "\udb80\udfe4" : "\udb81\udc0a"
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeIcon
            opacity: activePlayer && activePlayer.canTogglePlaying ? 1.0 : 0.35
            color: ThemeManager.accentPurple
            scale: playPauseArea.pressed ? ThemeManager.iconPressScale : (playPauseArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            MouseArea {
                id: playPauseArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: activePlayer && activePlayer.canTogglePlaying ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (activePlayer && activePlayer.canTogglePlaying) activePlayer.togglePlaying()
            }
        }

        Text {
            id: nextGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: "\udb81\udcad"
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeNormal
            opacity: activePlayer && activePlayer.canGoNext ? 1.0 : 0.35
            color: ThemeManager.fgSecondary
            scale: nextArea.pressed ? ThemeManager.iconPressScale : (nextArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            MouseArea {
                id: nextArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: activePlayer && activePlayer.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (activePlayer && activePlayer.canGoNext) activePlayer.next()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!activePlayer) return ""
                const title = activePlayer.trackTitle
                const artist = activePlayer.trackArtist
                let combined = title && artist ? (artist + " - " + title) : (title || activePlayer.identity || "")
                return combined.length > 32 ? combined.substring(0, 32) + "\u2026" : combined
            }
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeSmall
            color: ThemeManager.fgPrimary
        }
    }
}
