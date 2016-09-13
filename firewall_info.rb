require 'snmp'

class FirewallInfo

  attr_reader :ip_address, :download_bytes, :upload_bytes

  OID_ifNumber = '1.3.6.1.2.1.2.1.0'
  OID_ifName = '1.3.6.1.2.1.31.1.1.1.1.?'
  OID_ifInOctets = '1.3.6.1.2.1.2.2.1.10.?'
  OID_ifOutOctets = '1.3.6.1.2.1.2.2.1.16.?'

  def initialize(ip_address)
    @ip_address = ip_address

    SNMP::Manager.open(
        host:         ip_address,
    ) do |manager|
      response = manager.get([ OID_ifNumber ])

      @interface_count = 0

      response.each_varbind do |vb|
        if vb.name.to_str == OID_ifNumber
          @interface_count = vb.value.to_i
        end
      end

      params = []
      @interface_count.times do |i|
        params << OID_ifName.gsub('?', (i + 1).to_s)
      end

      @outside_index = nil

      response = manager.get(params)
      response.each_varbind do |vb|
        if vb.value.to_s.downcase == 'outside'
          @outside_index = vb.name.to_str.rpartition('.')[2].to_i
        end
      end

      if @outside_index
        in_oid = OID_ifInOctets.gsub('?', @outside_index.to_s)
        out_oid = OID_ifOutOctets.gsub('?', @outside_index.to_s)

        params = [ in_oid, out_oid ]
        response = manager.get(params)
        response.each_varbind do |vb|
          case vb.name.to_str
            when in_oid
              @download_bytes = vb.value.to_i
            when out_oid
              @upload_bytes = vb.value.to_i
          end
        end
      else
        @download_bytes = 0
        @upload_bytes = 0
      end
    end
  end

end