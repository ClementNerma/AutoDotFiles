if [[ -d ~/.volta ]]; then
	mvbak ~/.volta
	echowarn "\z[yellow]°\!/ A previous version of \z[green]°Volta\z[]° was detected ==> backed it up to \z[magenta]°$LAST_MVBAK_PATH\z[]°...\z[]°"
fi

echoinfo ">\n> Installing Volta...\n>"
curl https://get.volta.sh | bash

export VOLTA_HOME="$HOME/.volta"    # Just for this session
export PATH="$VOLTA_HOME/bin:$PATH" # Just for this session

echoinfo ">\n> Installing Node.js & NPM...\n>"
volta install node@latest

echoinfo ">\n> Installing Yarn...\n>"
volta install yarn
yarn -v # Just to be sure Yarn was installed correctly
