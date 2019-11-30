#!/usr/bin/env osascript
tell application "Viscosity" to connect "Betterment"

tell application "System Events"
    repeat until exists (window "Viscosity" of application process "Viscosity")
        delay 0.5
    end repeat

    tell process "Viscosity"
        set value of text field 1 of window "Viscosity" to "push"
        delay 1
        click button "OK" of window "Viscosity"
    end tell
end tell
