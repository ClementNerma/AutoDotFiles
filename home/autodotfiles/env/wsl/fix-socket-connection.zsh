
# Enable external connection for e.g. Explorer, VSCode, etc.
function __wsl_fix_parentof() {
        pid=$(ps -p ${1:-$$} -o ppid=;)
        echo ${pid// /}
}

function fix_socket_connection() {
  local interop_pid=$$

  while true ; do
    [[ -e /run/WSL/${interop_pid}_interop ]] && break
    local interop_pid=$(__wsl_fix_parentof ${interop_pid})
    [[ ${interop_pid} == 1 ]] && break
  done

  if [[ ${interop_pid} == 1 ]] ; then
      echo "Failed to find a parent process with a working interop socket.  Interop is broken."
  else
      export WSL_INTEROP=/run/WSL/${interop_pid}_interop
  fi
}

fix_socket_connection
