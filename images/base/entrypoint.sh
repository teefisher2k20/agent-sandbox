#!/bin/bash
set -e

# Initialize firewall if not already done
# Check if our REJECT rule exists (added at end of init-firewall.sh)
if ! sudo iptables -L OUTPUT -n 2>/dev/null | grep -q "REJECT"; then
  echo "Initializing firewall..."
  sudo /usr/local/bin/init-firewall.sh
else
  echo "Firewall already initialized."
fi

# Execute the provided command (or default to zsh)
exec "${@:-zsh}"
