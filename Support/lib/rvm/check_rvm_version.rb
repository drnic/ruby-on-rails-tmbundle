CURRENT_RVM_VERSION = "0.1.33"
regex = /rvm (\d+\.\d+\.\d+)/

if `rvm version`.scan(regex).flatten.first < CURRENT_RVM_VERSION
  TextMate::UI.tool_tip("RVM is outdated. Update with 'rvm update'.")
  exit
end
