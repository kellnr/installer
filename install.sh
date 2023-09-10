#!/bin/bash

function usage {
    echo "Usage: $(basename $0) [-tdhvpas]" 2>&1
    echo '      -h              shows help'
    echo
    echo '      -a              [required] API address for Kellnr. Hostname where Kellnr will be reachable.'
    echo
    echo '      -s              [optional] Create a systemd service and run Kellnr. Needs "sudo" rights.'
    echo '      -d data_dir     [optional] directory where Kellnr saves all data. Must be different to the install directory. (default = $HOME/kdata)'
    echo '      -v version      [optional] install a specific version. (default = latest)'
    echo '      -p password     [optional] password for admin user. (default = random)'
    echo '      -t access_token [optional] Cargo access token for admin user. (default = random)'
    exit 1
}

function parseArgs () {
    optstring="shv:t:p:a:d:"
    local OPTIND
    
    # Defaults
    DIRECTORY="$HOME/kdata"
    
    # Parse arguments from command line
    while getopts ${optstring} arg; do
        case ${arg} in
            a)
                ADDRESS="${OPTARG}"
            ;;
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
            h)
                usage
            ;;
            s)
                SERVICE='true'
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

    if test -z $ADDRESS; then
        echo "ERROR: No API address set."
        usage
        exit 1
    fi
}

function checkDeps {
    for c in git unzip curl sed rustc
    do
        if ! command -v $c &> /dev/null
        then
            echo "ERROR: $c not found. Please install the package that contains $c."
            MISSING_CMD='true'
        fi
    done
    
    if ! test -z $MISSING_CMD
    then
        echo "ERROR: Missing dependencies."
        exit 1
    fi
}

function downloadKellnr {
    BASE_URL="https://github.com/kellnr/kellnr/releases/download"
    LATEST_URL="$BASE_URL/latest"
    VERSION_URL="$BASE_URL/v$VERSION"
    ARCH_X86_X64="x86_64-unknown-linux-gnu"
    ARCH_AARCH64="aarch64-unknown-linux-gnu"
    ARCH_ARMV7="armv7-unknown-linux-gnueabihf"

    ARCH=$(lscpu | grep Architecture | tr -d ' ' | cut -d : -f 2)
    if [ $ARCH = "aarch64" ]; then 
        if test -z "$VERSION"
        then
            KELLNR_URL="$LATEST_URL/kellnr-$ARCH_AARCH64.zip"
            KELLNR_ZIP="kellnr-latest.zip"
        else
            KELLNR_URL="$VERSION_URL/kellnr-$ARCH_AARCH64.zip"
            KELLNR_ZIP="kellnr-$VERSION.zip"
        fi
    elif [ $ARCH = "armv7" ]; then 
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
            KELLNR_URL="$LATEST_URL/kellnr-$ARCH_X86_X64.zip"
            KELLNR_ZIP="kellnr-latest.zip"
        else
            KELLNR_URL="$VERSION_URL/kellnr-$ARCH_X86_X64.zip"
            KELLNR_ZIP="kellnr-$VERSION.zip"
        fi
    fi
    
    STATUSCODE=$(curl -L --silent --output $KELLNR_ZIP --write-out "%{http_code}" $KELLNR_URL)
    if test $STATUSCODE -ne 200; then
        echo "ERROR: Faild to download from: $KELLNR_URL"
        echo "ERROR: Failed to download Kellnr. Statuscode: $STATUSCODE"
        rm $KELLNR_ZIP
        exit 1
    fi
}

function unpack {
    echo "INFO: Unpack Kellnr"
    unzip -qq -o $KELLNR_ZIP -d ./kellnr
}

function genPwd {
    < /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-$1};
}

function configure {
    echo "INFO: Configure Kellnr"

    # Set API address
    echo "INFO: API address set to \"$ADDRESS\""
    sed -i "s/api_address =.*/api_address = \"$ADDRESS\"/" ./kellnr/config/default.toml
    
    # Set admin password
    if test -z "$ADMIN_PWD"
    then
        ADMIN_PWD=$(genPwd 12)
    fi
    echo "INFO: Admin password set to \"$ADMIN_PWD\""
    sed -i "s/admin_pwd =.*/admin_pwd = \"$ADMIN_PWD\"/" ./kellnr/config/default.toml
    
    # Set admin access token for Cagro
    if test -z "$ACCESS_TOKEN"
    then
        ACCESS_TOKEN=$(genPwd 32)
    fi
    echo "INFO: Admin cargo access token set to: \"$ACCESS_TOKEN\""
    sed -i "s/admin_token =.*/admin_token = \"$ACCESS_TOKEN\"/" ./kellnr/config/default.toml
    
    # Set and create data directory
    echo "INFO: Data directory set to: \"$DIRECTORY\""
    sed -i "s,data_dir =.*,data_dir = \"$DIRECTORY\"," ./kellnr/config/default.toml
    if [ ! -d $DIRECTORY ]; then
        mkdir -p $DIRECTORY
    fi
}

function createService {
local service=$(cat <<EOF
[Unit]
Description=Kellnr Crate Registry
After=network.target syslog.target

[Service]
Type=simple
ExecStart=$PWD/kellnr/kellnr
ExecStop=/usr/bin/pkill kellnr
ExecStopPost=/usr/bin/pkill git
WorkingDirectory=$PWD/kellnr

[Install]
WantedBy=multi-user.target
EOF
)

echo "$service" | sudo tee /etc/systemd/system/kellnr.service > /dev/null
}

function finish {
    echo "INFO: Installation finished"
    echo
    echo "TODO: Open the ports 8000 and 9418 if not configured differently in \"./config/default.toml\""
    echo
    
    if test -z $SERVICE; then
        echo 'TODO: Start Kellnr from the Kellnr directory with "cd ./kellnr && ./kellnr"'
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
unpack
configure
if ! test -z $SERVICE; then
    createService
fi
finish
