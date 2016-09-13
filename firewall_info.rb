class FirewallInfo

  attr_accessor :all_records

  def initialize(ip_address, snmp_group = 'public', snmp_version = 1)
    @ip_address = ip_address
    @snmp_group = snmp_group
    @snmp_version = snmp_version
    @all_records = {}

    read_snmp get_snmp
  end

  def interface_count
    @interface_count ||= all_records['IF-MIB::IFNUMBER.0'] || 0
  end

  def outside_index
    @outside_index ||=
        begin
          if interface_count > 0
            v = 0
            interface_count.times do |index|
              if all_records["IF-MIB::IFNAME.#{index}"].to_s.upcase == 'OUTSIDE'
                v = index
                break
              end
            end
            v
          else
            0
          end
        end
  end

  def download_bytes
    oid = "IF-MIB::ifInOctets.#{outside_index}"
    @download_bytes ||=
        if outside_index == 0
          0
        else
          @all_records[oid.upcase]
        end
  end

  def upload_bytes
    oid = "IF-MIB::ifOutOctets.#{outside_index}"
    @upload_bytes ||=
        if outside_index == 0
          0
        else
          @all_records[oid.upcase]
        end
  end

  def uptime
    oid = "DISMAN-EVENT-MIB::sysUpTimeInstance"
    @uptime ||= @all_records[oid.upcase]
  end

  def outside
    @outside ||=
        if outside_index == 0
          { }
        else
          ret = {}

          rex = /^IF-MIB::(.*)\.#{outside_index}$/

          @all_records.each do |k,v|
            if (match = rex.match(k))
              ret[match[1]] = v
            end
          end

          ret
        end
  end

  private

  def get_snmp(oid = nil)
    if oid
      `snmpwalk -c #{@snmp_group} -v #{@snmp_version} #{@ip_address} #{oid}`
    else
      `snmpwalk -c #{@snmp_group} -v #{@snmp_version} #{@ip_address}`
    end
  end

  def read_snmp(results)
    results = results.force_encoding(Encoding::ASCII)

    white = " \t\r\n".bytes
    results.bytes.each_with_index do |b,i|
      unless white.include?(b) || (b >= 32 && b <= 127)
        results[i] = '.'
      end
    end

    results = results.split("\n")

    results.each do |line|
      line = line.strip
      if line != ''
        key, value = line.split('=', 2).map{ |v| v.strip }
        type, value =
            if value
              value.split(':', 2).map{ |v| v.strip }
            else
              [ 'NIL', nil ]
            end

        type = type.upcase
        value = value.to_s

        # parse non-string types.
        value =
            if %w(INTEGER GAUGE32 COUNTER32).include?(type)
              # to an integer
              value.to_i
            elsif type == 'TIMETICKS'
              # to a float (seconds)
              /^\((\d+)\)/.match(value)[1].to_i / 100.0
            else
              # leave as a string
              value
            end

        @all_records[key.upcase] = value
      end
    end
  end

end