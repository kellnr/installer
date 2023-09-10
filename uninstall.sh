# Uninstall Kellnr


# Check if the script is in the right work directory
if [ ! -d ./kellnr ]; then
    echo "Cannot find Kellnr installation directory. Please run the script from the parent directory of the Kellnr installtion."
    exit 1
fi

# Disable and remove systemd service
SERVICE="/etc/systemd/system/kellnr.service"
if [ -f $SERVICE ]; then
    sudo systemctl stop kellnr
    sudo systemctl disable kellnr
    sudo rm $SERVICE
    echo "Removed Kellnr service"
fi

# Remove data directory
DATADIR=$(sed -n -e "/^data_dir/p" ./kellnr/config/default.toml | cut -d= -f2 | tr -d ' ' | tr -d '"')

if [ -d $DATADIR ]; then
    sudo rm -rf $DATADIR
    echo "Removed Kellnr data directory: $DATADIR"
else
    echo "Cannot find Kellnr data directory: $DATADIR"
    exit 1
fi

# Remove Kellnr installation
sudo rm -rf kellnr*
echo "Removed Kellnr installation"