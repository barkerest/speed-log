# speed-log

A very simple ruby script that uses 'speedtest-cli' to run a speedtest and ruby-snmp to query a firewall for other bandwidth usage.
This script serves a very specific use case, I want to be able to log speedtest results for my internet connection throughout the day.

## Usage

`ruby speed_log.rb 192.168.1.1 speed-log.csv 6962`

The first parameter would be the IP address for the gateway device.  In my case, this is a Cisco firewall.  If this parameter is not
supplied, then the script will prompt the user.

The gateway device would need to support SNMP polling.  The script asks the device how many interfaces it has using the 'ifNumber.0' OID.
Then it iterates through the 'ifName.X' OIDs until it finds the interface named 'outside'.  Once it finds that interface, it asks for the
'ifInOctets' and 'ifOutOctets'.  The script then waits for 5 seconds and asks for the same information again.  The difference in the 
inbound(download) and outbound(upload) bytes is then used to determine the other bandwidth usage.  This check is performed before
and after the speed test so we have a somewhat accurate picture of the actual internet bandwidth usage.

The second parameter is the path to a CSV log file.  If this parameter is not supplied, then the script will prompt the user.

The script will read the contents of the CSV, perform the speed test, resort the data, and then save the CSV with the new record.
Any records more than 28 days old will be purged before the log is resaved.

The third parameter is optional, but if supplied must be the numeric ID for the speedtest server to use.  This can be retrieved by using
the `speedtest-cli --list` command.

## License
Copyright (c) 2016 [Beau Barker](mailto:beau@barkerest.com)

This script is available under the terms of the [MIT License](http://opensource.org/licenses/MIT).
