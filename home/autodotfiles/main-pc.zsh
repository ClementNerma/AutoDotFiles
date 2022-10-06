#!/usr/bin/zsh

#
# This file contains commands and configuration which are specific to my main computer.
#

# Software: Android's Platform Tools
function adbtool() {
  local tool_path="$SOFTWAREDIR/PlatformTools"

  if [[ ! -f $tool_path/$1 ]]; then
    echoerr "Could not find Platform Tools binary \z[yellow]°$1\z[]° at path \z[yellow]°$tool_path\z[]°"
    return 1
  fi

  "$tool_path/$1" ${@:2}
}

alias adb="adbtool adb.exe"
alias fastboot="adbtool fastboot.exe"
