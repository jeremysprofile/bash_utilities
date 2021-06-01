#!/bin/bash
# Source this file to get quality-of-life improvements to your docker workflows.

# Provides the following functions:
# dockerstart: starts the docker desktop for mac application
# dockerstop: stops that app
# dcon: displays your docker configuration (what image you build and where you can push) in editable format.
# dbuild[p]: build the Dockerfile in CWD [passing in proxy settings as build args]
# dpush: push your image
# dpull: pull your image
# drun: run your image (accepts command-line args that get passed to the container)
# drunsh: Run your image with your CMD and ENTRYPOINT replaces with /bin/sh
# dexec: Exec into a shell of your running image
# dkill: stop your running image
# dscratch: 'drunsh' with alpine:latest instead of your image




#--------------------------------------DOCKER-------------------------------------------------------
__dockerc="$HOME/.docker/config.json"
alias dockerc='vim $__dockerc'

if [[ -z "$dimage" ]]; then
    export dimage='test'
fi
if [[ -z "$dtag" ]]; then
    export dtag='latest'
fi
if [[ -z "$dproj" ]]; then
    export dproj='jeremydr2'
fi

dcon() {
  if [[ $# -gt 0 ]]; then
    local input="$1"
    dtag=${input##*:}
    input=${input%:*}
    dimage=${input##*/}
    if [[ "$input" =~ ^"$__hub" ]]; then
      input=${input##$__hub/}
    fi
    dproj=${input%/*}
  else
    read -e -i "$dimage" -p "Image name: " dimage
    read -e -i "$dtag" -p "Tag name: " dtag
    read -e -i "$dproj" -p "Project name (in $__hub): " dproj
  fi
  echo "Set to build/run/push ${__hub+$__hub/}$dproj/$dimage:$dtag"
}

alias dbuildp='echo "building $dimage:$dtag with proxies"; docker build . \
  --build-arg http_proxy=$http_proxy --build-arg https_proxy=$http_proxy \
  --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$http_proxy \
  --build-arg no_proxy="$no_proxy" --build-arg NO_PROXY="$no_proxy" -t $dimage:$dtag'
alias dbuild='echo "building $dimage:$dtag"; docker build . -t $dimage:$dtag --platform linux/x86_64'
alias dpush='echo "pushing ${__hub+$__hub/}$dproj/$dimage:$dtag"; \
    docker tag $dimage:$dtag ${__hub+$__hub/}$dproj/$dimage:$dtag; \
    docker push ${__hub+$__hub/}$dproj/$dimage:$dtag'
alias dpull='echo "pulling $__hub/$dproj/$dimage:$dtag or $dimage:$dtag"; \
    { docker pull $__hub/$dproj/$dimage:$dtag && \
      docker tag $__hub/$dproj/$dimage:$dtag $dimage:$dtag; } || docker pull $dimage:$dtag'
drun() {  # runs the docker image in stdout
  if [[ $# -gt 0 ]]; then
    echo "running $@"
    docker run -it --rm --name test "$@" --platform linux/x86_64
  else
    echo "running $dimage:$dtag"
    docker run -it --rm --name test $dimage:$dtag
  fi
}
drunsh() {
  if [[ $# -gt 0 ]]; then
    echo "running $@"
    docker run -it --rm --entrypoint /bin/sh --platform linux/x86_64 --name test "$@"
  else
    echo "running $dimage:$dtag"
    docker run -it --rm --entrypoint /bin/sh --platform linux/x86_64 --name test $dimage:$dtag
  fi
}
drunarmsh() {
  if [[ $# -gt 0 ]]; then
    echo "running $@"
    docker run -it --rm --entrypoint /bin/sh --platform linux/arm64 --name test "$@"
  else
    echo "running $dimage:$dtag"
    docker run -it --rm --entrypoint /bin/sh --platform linux/arm64 --name test $dimage:$dtag
  fi
}
alias dexec='docker exec -it test /bin/sh'
alias dkill='echo "killing test"; docker kill test'
alias dscratch='echo "running alpine"; docker run \
  -e HTTP_PROXY="$HTTP_PROXY" -e HTTPS_PROXY="$HTTPS_PROXY" -e NO_PROXY="$NO_PROXY" \
  -e http_proxy="$http_proxy" -e https_proxy="$https_proxy" -e no_proxy="$no_proxy" \
  -it --rm alpine:latest /bin/sh'

dockerstart() {
    [[ "$__os" == 'mac' ]] || { echo "This only runs on macOS." >&2; return 2; }
    echo "-- Starting Docker.app, if necessary..."

    open -g -a Docker.app || return

    # Wait for the server to start up, if applicable.  
    i=0
    while ! docker system info &>/dev/null; do
      (( i++ == 0 )) && printf %s '-- Waiting for Docker to finish starting up...' || printf '.'
      sleep 1
    done
    (( i )) && printf '\n'

    echo "-- Docker is ready."
}
dockerstop() {
    [[ "$__os" == 'mac' ]] || { echo "This only runs on macOS." >&2; return 2; }
    echo "-- Quitting Docker.app, if running..."

    osascript - <<-'EOF' || exit
    tell application "Docker"
      if it is running then quit it
    end tell
	EOF
    #yup, that's a required tab right there. irritating, right?

    echo "-- Docker is stopped."
    echo "Caveat: Restarting it too quickly can cause errors."
}

alias dockerclean='docker rm $(docker ps -aq)'
alias dockerls='docker ps'
alias dlogin='docker login $__hub'

