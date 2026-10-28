# macOS keeps three separate machine names (HostName, Bonjour's LocalHostName,
# and the UI's ComputerName); System Settings doesn't update them all, so set
# the trio in one shot to keep them consistent
function scutil_set_hostname --argument-names name
  sudo scutil --set HostName "$name.local"
  sudo scutil --set LocalHostName "$name"
  sudo scutil --set ComputerName "$name"
end
