#!/bin/bash

function usage {
    echo "Usage: $(basename "$0") [-tdhvpasmi]" 2>&1
    echo '      -h              shows help'
    echo
    echo '      -s              [optional] Create a systemd service and run Kellnr. Needs "sudo" rights.'
    echo '      -i install_dir  [optional] directory where Kellnr binary is installed. (default = /usr/local/bin)'
    echo '      -d data_dir     [optional] directory where Kellnr saves all data. Must be different to the install directory. (default = /var/lib/kellnr)'
    echo '      -v version      [optional] install a specific version. (default = latest)'
    echo '      -p password     [optional] password for admin user. (default = random)'
    echo '      -t access_token [optional] Cargo access token for admin user. (default = random)'
    echo '      -m              [optional] Install static binary, compiled with musl to support more Linux distributions. (default = false)'
    exit 1
}

function parseArgs () {
    optstring="shmv:t:p:d:i:"
    local OPTIND

    # Defaults
    INSTALL_DIR="/usr/local/bin"
    DIRECTORY="/var/lib/kellnr"
    STATIC="false"

    # Parse arguments from command line
    while getopts ${optstring} arg; do
        case ${arg} in
            v)
                VERSION="${OPTARG}"
            ;;
            p)
                ADMIN_PWD="${OPTARG}"
            ;;
            t)
                ACCESS_TOKEN="${OPTARG}"
            ;;
            d)
                DIRECTORY="${OPTARG}"
            ;;
            i)
                INSTALL_DIR="${OPTARG}"
            ;;
            h)
                usage
            ;;
            s)
                SERVICE='true'
            ;;
            m)
                STATIC='true'
            ;;
            :)
                echo "$0: Must supply an argument to -$OPTARG." >&2
                echo
                usage
            ;;
            ?)
                echo "Invalid option:  -${OPTARG}."
                echo
                usage
            ;;
        esac
    done
}

function checkDeps {
    for c in unzip curl sed
    do
        if ! command -v $c &> /dev/null
        then
            echo "ERROR: $c not found. Please install the package that contains $c."
            MISSING_CMD='true'
        fi
    done
    
    if ! test -z "$MISSING_CMD"
    then
        echo "ERROR: Missing dependencies."
        exit 1
    fi
}

function downloadKellnr {
    BASE_URL="https://github.com/kellnr/kellnr/releases"
    LATEST_URL="$BASE_URL/latest/download"
    VERSION_URL="$BASE_URL/download/v$VERSION"
    
    if [ "$STATIC" = "true" ]; then
        LINKAGE="musl"
    else
        LINKAGE="gnu"
    fi

    ARCH_X86_64="x86_64-unknown-linux-$LINKAGE"
    ARCH_AARCH64="aarch64-unknown-linux-$LINKAGE"
    ARCH_ARMV7="armv7-unknown-linux-${LINKAGE}eabihf"

    ARCH=$(lscpu | grep Architecture | tr -d ' ' | cut -d : -f 2)
    if [ "$ARCH" = "aarch64" ]; then 
        if test -z "$VERSION"
        then
            KELLNR_URL="$LATEST_URL/kellnr-$ARCH_AARCH64.zip"
            KELLNR_ZIP="kellnr-latest.zip"
        else
            KELLNR_URL="$VERSION_URL/kellnr-$ARCH_AARCH64.zip"
            KELLNR_ZIP="kellnr-$VERSION.zip"
        fi
    elif [ "$ARCH" = "armv7" ]; then 
        if test -z "$VERSION"
        then
            KELLNR_URL="$LATEST_URL/kellnr-$ARCH_ARMV7.zip"
            KELLNR_ZIP="kellnr-latest.zip"
        else
            KELLNR_URL="$VERSION_URL/kellnr-$ARCH_ARMV7.zip"
            KELLNR_ZIP="kellnr-$VERSION.zip"
        fi
    else
        if test -z "$VERSION"
        then
            KELLNR_URL="$LATEST_URL/kellnr-$ARCH_X86_64.zip"
            KELLNR_ZIP="kellnr-latest.zip"
        else
            KELLNR_URL="$VERSION_URL/kellnr-$ARCH_X86_64.zip"
            KELLNR_ZIP="kellnr-$VERSION.zip"
        fi
    fi
    
    STATUSCODE=$(curl -L --silent --output "$KELLNR_ZIP" --write-out "%{http_code}" "$KELLNR_URL")
    if test "$STATUSCODE" -ne 200; then
        echo "ERROR: Faild to download from: $KELLNR_URL"
        echo "ERROR: Failed to download Kellnr. Statuscode: $STATUSCODE"
        rm "$KELLNR_ZIP"
        exit 1
    fi
}

function install {
    echo "INFO: Install Kellnr to $INSTALL_DIR"

    # Create install directory if it does not exist
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi

    # Unpack directly to install directory
    unzip -qq -o "$KELLNR_ZIP" -d "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/kellnr"

    # Clean up
    rm -f "$KELLNR_ZIP"
}

function genPwd {
    < /dev/urandom tr -dc A-Z-a-z-0-9 | head -c"${1:-$1}";
}

function configure {
    echo "INFO: Configure Kellnr"

    CONFIG_DIR="/etc/kellnr"
    CONFIG_FILE="$CONFIG_DIR/kellnr.toml"

    # Create config directory
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi

    # Generate default config file
    echo "INFO: Generating config file at $CONFIG_FILE"
    "$INSTALL_DIR/kellnr" config init -o "$CONFIG_FILE"

    # Set admin password
    if test -z "$ADMIN_PWD"
    then
        ADMIN_PWD=$(genPwd 12)
    fi
    echo "INFO: Admin password set to \"$ADMIN_PWD\""
    sed -i "s/admin_pwd = .*/admin_pwd = \"$ADMIN_PWD\"/" "$CONFIG_FILE"

    # Set admin access token for Cargo
    if test -z "$ACCESS_TOKEN"
    then
        ACCESS_TOKEN=$(genPwd 32)
    fi
    echo "INFO: Admin cargo access token set to: \"$ACCESS_TOKEN\""
    sed -i "s/admin_token = .*/admin_token = \"$ACCESS_TOKEN\"/" "$CONFIG_FILE"

    # Set data directory
    echo "INFO: Data directory set to: \"$DIRECTORY\""
    sed -i "s,data_dir = .*,data_dir = \"$DIRECTORY\"," "$CONFIG_FILE"

    # Create data directory
    if [ ! -d "$DIRECTORY" ]; then
        mkdir -p "$DIRECTORY"
    fi
}

function createService {
local service=$(cat <<EOF
[Unit]
Description=Kellnr Crate Registry
After=network.target syslog.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/kellnr -c $CONFIG_FILE run
ExecStop=/usr/bin/pkill kellnr
ExecStopPost=/usr/bin/pkill git

[Install]
WantedBy=multi-user.target
EOF
)

echo "$service" | sudo tee /etc/systemd/system/kellnr.service > /dev/null
}

function finish {
    echo "INFO: Installation finished"
    echo
    echo "INFO: Kellnr installed to: $INSTALL_DIR/kellnr"
    echo "INFO: Config file: $CONFIG_FILE"
    echo "INFO: Data directory: $DIRECTORY"
    echo "INFO: Admin password: $ADMIN_PWD"
    echo "INFO: Admin token: $ACCESS_TOKEN"
    echo
    echo "TODO: Open port 8000, if not configured differently"
    echo

    if test -z "$SERVICE"; then
        echo "TODO: Start Kellnr with:"
        echo "      kellnr -c $CONFIG_FILE run"
    else
        echo 'TODO: Enable the Kellnr service with: "sudo systemctl enable kellnr"'
        echo '      Start the Kellnr service with: "sudo systemctl start kellnr"'
        echo '      [Optional] Check if the service started: "sudo systemctl status kellnr"'
    fi
}

if [[ ${#} -eq 0 ]]; then
    usage
fi

echo "INFO: Start Kellnr installation"
parseArgs "$@"
checkDeps
downloadKellnr
install
configure
if ! test -z "$SERVICE"; then
    createService
fi
finish
