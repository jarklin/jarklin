#!/usr/bin/env bash
set -e  # fail on any error
shopt -s nullglob  # dont return the glob-pattern if nothing found

function success() {
  echo -e "\e[32m" "$@" "\e[39m"
}
function info() {
  echo -e "\e[33m" "$@" "\e[39m"
}
function error() {
  echo -e "\e[31m" "$@" "\e[39m"
}


if ! command -v whiptail >/dev/null; then
  error "whiptail not found. required for the wizard"
  exit 1
fi
if ! command -v pip3 >/dev/null; then
  error "pip3 not found. required for some parts of the wizard"
  exit 1
fi


if [[ ${#BASH_SOURCE[@]} -eq 0 ]]; then
  # 'curl ... | bash' or 'wget ... | bash'
  INTERACTIVE_WITH_CURL=true
else
  # 'bash wizard' or './wizard'
  INTERACTIVE_WITH_CURL=false
fi
ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")"
CWD="$(realpath "$(pwd)")"


# shellcheck disable=SC2120
function wiz_ask_directory() {
  SELECTED="."
  TITLE="Jarklin-Wizard"
  TEXT="Select a directory"

  while [[ $# -gt 0 ]]; do
    case $1 in
    --title)
        TITLE="$2"
        shift; shift;
      ;;
    --text)
        TEXT="$2"
        shift; shift;
      ;;
    *)
      if [[ "$SELECTED" = "." ]]; then
        SELECTED="$1"
      else
        echo "unknown parameter '$1'"
        exit 1
      fi
      ;;
    esac
  done

  SELECTED=$(realpath "$SELECTED")
  while true; do
    OPTIONS=("." "@select" ".." "..")
    for entry in "$SELECTED"/*/; do
      entry=$(basename "$entry")
      OPTIONS+=("$entry" "$entry")
    done
    CHOICE=$(
      whiptail --title "$TITLE" --menu "$TEXT\n$SELECTED" 20 60 10 --notags --ok-button "Open" \
      "${OPTIONS[@]}" \
      3>&2 2>&1 1>&3
    )
    if [[ "$CHOICE" = "." ]]; then
      break
    fi
    SELECTED=$(realpath "$SELECTED/$CHOICE")
  done
  echo "$SELECTED"
}


function check_is_jarklin() {
  executable="${1:-.}/jarklin"
  if [[ ! -f "$executable" ]] || [ "$("$executable" --verify-jarklin)" != "jarklin" ]; then
    return 1
  fi
  return 0
}


function wiz_download_jarklin_server() {
    wget "https://github.com/jarklin/jarklin-server/releases/download/latest/jarklin.tgz" -O "$1"
}

function wiz_download_web_ui() {
    wget "https://github.com/jarklin/jarklin-web/releases/download/latest/web-ui.tgz" -O "$1"
}


function wizard_install() {
  if [[ ! -w . ]]; then
      whiptail --title "Jarklin-Wizard - Install" --msgbox "You don't have permissions to install Jarklin here.
$(pwd)" 20 60
    return 0
  fi

  FEATURES=$(
    whiptail --title "Jarklin-Wizard - Install" --checklist "Which features do you want to install?" 20 60 10 --notags --separate-output \
    "jarklin" "Jarklin server/backend" ON \
    "web-ui" "Default WEB-UI" ON \
    "better-exceptions" "Better exceptions logging" OFF \
    3>&2 2>&1 1>&3
#    "web.service" "jarklin-server.service" OFF \
#    "cache.service" "jarklin-cache.service" OFF \
  )
  JARKLIN=false
  WEB_UI=false
  BETTER_EXCEPTIONS=false
#  WEB_SERVICE=false
#  CACHE_SERVICE=false
  for FEATURE in $FEATURES; do
    case $FEATURE in
    "jarklin") JARKLIN=true ;;
    "web-ui") WEB_UI=true ;;
#    "web.service") WEB_SERVICE=true ;;
#    "cache.service") CACHE_SERVICE=true ;;
    "better-exception") BETTER_EXCEPTIONS=true;
    esac
  done

  if [[ $JARKLIN = true ]] && [[ -d "./jarklin/" ]] && ! whiptail --yesno "'$(pwd)/jarklin/' seems to exist. It will be overwritten." 20 60 --yes-button "Continue" --no-button "Cancel"; then
    return 0;
  fi

  if [[ $JARKLIN = true ]]; then
    JARKLIN_ARCHIVE="./jarklin.tgz"

    info "Downloading Jarklin..."
    wiz_download_jarklin_server "$JARKLIN_ARCHIVE"

    info "Cleanup..."
    rm -rf "./jarklin/"

    info "Extracting Jarklin..."
    tar -xf "$JARKLIN_ARCHIVE" -C .
    rm "$JARKLIN_ARCHIVE"

    info "Installing dependencies..."
    rm -rf "./jarklin/_deps/"
    mkdir -p "./jarklin/_deps/"
    python3 -m pip install -r "./jarklin/requirements.txt" -t "./jarklin/_deps/" --disable-pip-version-check
  fi

  if [[ $WEB_UI = true ]]; then
    WEB_UI_ARCHIVE="./web-ui.tgz"
    WEB_UI_DIR="./jarklin/web/web-ui/"

    info "Downloading Web-UI..."
    wiz_download_web_ui "$WEB_UI_ARCHIVE"

    info "Cleanup..."
    rm -rf "$WEB_UI_DIR"

    info "Extracting Web-UI..."
    mkdir -p "$WEB_UI_DIR"
    tar -xf "$WEB_UI_ARCHIVE" -C "$WEB_UI_DIR"
    rm "$WEB_UI_ARCHIVE"
  fi

  if [[ $BETTER_EXCEPTIONS = true ]]; then
    info "Installing better-exceptions..."
    python3 -m pip install -U better-exceptions -t "./jarklin/_deps/" --disable-pip-version-check
  fi

  OUTDIR="$(realpath "./jarklin")"

  whiptail --title "Jarklin-Wizard - Install" --msgbox "Jarklin was successfully installed.

Installation: $OUTDIR
Executable:   $OUTDIR/jarklin" 20 60
}

function wizard_update() {
  cd "$ROOT"
  whiptail --title "Jarklin-Wizard - Update" --msgbox "Update is currently not available.\nReinstalling should do the job." 20 60
  return 1
}


function check_can_uninstall() {
  # check if we have permissions
  if [[ ! -w "$ROOT" ]]; then
    return 1
  fi
  if check_is_jarklin "$ROOT"; then
    return 0
  fi
  return 1
}

function wizard_uninstall() {
  cd "$ROOT/"
  if ! check_is_jarklin; then
    whiptail --title "Jarklin-Wizard - Uninstall" --msgbox "Could not find Jarklin installation\n($(pwd))" 20 60
    return 0
  fi
  cd ".."
  if whiptail --title "Jarklin-Wizard - Uninstall" --yesno "Are you sure want to uninstall Jarklin?\n$ROOT/" 20 60; then
    rm -rf "$ROOT"
    if [[ "$CWD" = "$ROOT" ]]; then
      CWD="$(dirname "$CWD")"
    fi
    ROOT=$(dirname "$ROOT")  # dunno how smart
    whiptail --title "Jarklin-Wizard - Uninstall" --msgbox "Jarklin was uninstalled" 20 60
  fi
}


function wizard_create_config() {
  TITLE="Jarklin-Wizard - Create Config"

  DEST=$(wiz_ask_directory --title "$TITLE" --text "Select where you want to create the config-file")
  FP="$DEST/.jarklin.yaml"

  if [[ -f "$FP" ]]; then
    if ! whiptail --title "$TITLE" --msgbox "A configuration file already exists. It will be overwritten." 20 60; then
      return 0
    fi
  fi

  BASEURL=$(
    whiptail --title "$TITLE - Server" --inputbox "Under which baseurl do you want to serve jarklin?
If jarklin is the only thing that's running on your server, then leave it as '/'.
If you have multiple services then you could change it to something like '/jarklin'" 20 60 "/" 3>&2 2>&1 1>&3
  )

  if whiptail --title "$TITLE - Server" --yesno "Bind to a Port or Unix-Domain-Socket (UDS)?
Port: eg. https://10.20.30.40:9898/
UDS: eg. /tmp/jarklin.sock" --yes-button "Port" --no-button "UDS" 20 60; then
    if whiptail --title "$TITLE - Server" --yesno "Should jarklin be publicly available?
Public: every device can access jarklin.
Private: Only programs on this device can access jarklin." --yes-button "Public" --no-button "Private" 20 60; then
      HOST="*"  # * is waitress wildcard
    else
      HOST="localhost"
    fi
    PORT=$(
      whiptail --title "$TITLE - Server" --inputbox "Under which port should jarklin be available?
(eg. https://10.20.30.40:9898/)
Port:" 20 60 "9898" 3>&2 2>&1 1>&3
    )
  else
    UDS=$(
      whiptail --title "$TITLE - Server" --inputbox "Where should the UDS be placed" 20 60 "/tmp/jarklin.sock" 3>&2 2>&1 1>&3
    )
  fi

  if whiptail --title "$TITLE - Server" --yesno "gzip content?
This can reduce the response-size and thus loading time of text-based responses on cost of CPU-Time.
Note: Should be done by the Proxy-Server if possible. Otherwise, this is the option." 20 60; then
    GZIP="yes"
  else
    GZIP="no"
  fi

  OPTIMIZATIONS=$(
    whiptail --title "$TITLE - Server" --checklist "Allow media optimization?
Enabling this allows for faster downloads as supported media is just-in-time optimized.
Important: only use this option for slow internet or a very small userbase as it can take up lots of system-resources." 20 60 6 --notags --separate-output \
    "image" "Image optimization" OFF \
    "video" "Video optimization (buggy)" OFF \
    3>&2 2>&1 1>&3
  )
  OPTIMIZE_IMAGES=false
  OPTIMIZE_VIDEOS=false
  for OPTIMIZATION in $OPTIMIZATIONS; do
    case $OPTIMIZATION in
    "image") OPTIMIZE_IMAGES=true ;;
    "video-ui") OPTIMIZE_VIDEOS=true ;;
    esac
  done

  if whiptail --title "$TITLE - Auth" --yesno "Do you want to require authentication?" 20 60; then
    USERNAME=$(
      whiptail --title "$TITLE - Auth" --inputbox "Username:" 20 60 3>&2 2>&1 1>&3
    )
    PASSWORD=$(
      whiptail --title "$TITLE - Auth" --passwordbox "Password:" 20 60 3>&2 2>&1 1>&3
    )
  fi

  if whiptail --title "$TITLE - Filtering" --yesno "Should the content be whitelisted or blacklisted?
Whitelist: directories or files are allowed/enabled
Blacklist: directories or files are disabled/hidden" --yes-button "Whitelist" --no-button "Blacklist" 20 60; then
    WHITELIST=true
  else
    WHITELIST=false
  fi

  LOGGINGLEVEL=$(whiptail --title "$TITLE" --menu "How detailed should the logs be?" 20 60 10 --notags \
    "CRITICAL" "CRITICAL" \
    "ERROR" "ERROR" \
    "WARNING" "WARNING" \
    "INFO" "INFO" \
    "DEBUG" "DEBUG" \
    3>&2 2>&1 1>&3
  )

  LOG2FILE=false  # file logging is buggy
#  if whiptail --title "$TITLE - Logging" --yesno "Should the logs be saved to a file?" 20 60; then
#    LOG2FILE=true
#  else
#    LOG2FILE=false
#  fi

  {
    echo "web:"
    if [[ -n "$BASEURL" ]]; then
      echo "  baseurl: \"$BASEURL\""
    fi
    echo "  server:"
    if [[ -n "$UDS" ]]; then
      echo "    unix_socket: \"$UDS\""
    else
      echo "    host: \"$HOST\""
      echo "    port: $PORT"
      echo "    ipv4: yes"
      echo "    ipv6: yes"
    fi
    echo "    threads: 8  # browsers send ~6 requests at once"
    if [[ -n "$USERNAME" ]] && [[ -n "$PASSWORD" ]]; then
      echo "  auth:"
      echo "    username: \"$USERNAME\""
      echo "    password: \"$PASSWORD\""
      echo "#    userpass: \".jarklin/userpass.txt\""
    fi
    echo "  session:"
    echo "    secret_key: \"$(python3 -c 'import secrets; print(secrets.token_hex(32))')\""
    echo "    permanent: yes"
    echo "#    lifetime: 604800  # 1w"
    echo "    refresh_each_request: yes"
    echo "  gzip: $GZIP"
    if [[ $OPTIMIZE_IMAGES = true ]] || [[ $OPTIMIZE_VIDEOS = true ]]; then
      echo "  optimize:"
      if [[ $OPTIMIZE_IMAGES = true ]]; then
        echo "    image: yes"
      fi
      if [[ $OPTIMIZE_VIDEOS = true ]]; then
        echo "    video: yes"
      fi
    fi
    echo "cache:"
    echo "  ignore:"
    if [[ $WHITELIST = true ]]; then
      echo "    - \"/*\""
      echo "#    - \"!/allowed\""
    else
      echo "#    - \"/hidden\""
    fi
    echo "logging:"
    echo "  console: yes"
    echo "  level: $LOGGINGLEVEL"
    if [[ $LOG2FILE = true ]]; then
      echo "  file:"
    fi

  } > "$FP"

  whiptail --title "$TITLE" --msgbox "Config file was created
$FP

For more or detailed options see https://jarklin.github.io/config/config-options" 20 60
}


function wizard_update_itself() {
  SCRIPT_FILE="$(realpath "${BASH_SOURCE[0]:-$0}")"
  if [[ ! -f "$SCRIPT_FILE" ]]; then
    >&2 echo "Wizard file does not exist"
    return 1
  fi
  NEW_CONTENT="$(curl -Ls https://github.com/jarklin/jarklin/raw/main/scripts/wizard.sh)"
  echo "$NEW_CONTENT" > "$SCRIPT_FILE"
  whiptail --title "$TITLE" --msgbox "Wizard was updated with the latest version

It is highly recommended to restart this script as the running version is the old one

Wizard: $SCRIPT_FILE" 20 60
}


function wizard_main() {
  while true; do
    cd "$CWD"  # reset in case a sub-command changes the directory

    OPTIONS=()
    OPTIONS+=("wizard_install" "Install Jarklin here")
#    OPTIONS+=("wizard_update" "Update Jarklin")
    if check_can_uninstall; then
      OPTIONS+=("wizard_uninstall" "Uninstall Jarklin")
    fi
    OPTIONS+=("wizard_create_config" "Generate a new config")
    if [[ $INTERACTIVE_WITH_CURL != true ]]; then
      OPTIONS+=("wizard_update_itself" "Update the Wizard")
    fi

    CHOICE=$(whiptail --title "Jarklin-Wizard" --menu "What do you want to do?" 20 60 10 --cancel-button "Exit" --notags \
      "${OPTIONS[@]}" \
      "exit" "Exit the Wizard" \
      3>&2 2>&1 1>&3
      )
    "$CHOICE" || whiptail --title "Jarklin-Wizard" --msgbox "Something went wrong.

(@$CHOICE)" 20 60
  done
}

case $1 in
install)
  wizard_install ;;
uninstall)
  wizard_uninstall ;;
"")  # no command
  wizard_main "${@:2}" ;;
-h | --help)
  echo "wizard [-h|--help]"
#  echo "wizard install  -  install jarklin"
#  echo "wizard uninstall  -  uninstall jarklin"
;;
*)
  error "Unknown command '$1'"
  exit 1
;;
esac
