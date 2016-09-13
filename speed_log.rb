#!/usr/bin/env ruby

class SpeedLog

  class Record
    attr_accessor :month, :day, :year, :hour, :minute, :latency, :download, :upload, :fw_down, :fw_up

    def initialize(time, latency, download, upload, fw_down, fw_up)
      self.latency = latency
      self.download = download
      self.upload = upload
      self.fw_down = fw_down
      self.fw_up = fw_up
      self.month = time.month
      self.day = time.day
      self.year = time.year
      self.hour = time.hour
      self.minute = time.min
    end

    def time
      @time ||= Time.new(year, month, day, hour, minute)
    end

    def friendly(size)
      return '' unless size

      if size > 1<<30
        '%0.2f Gb' % (size.to_f / (1<<30))
      elsif size > 1<<20
        '%0.2f Mb' % (size.to_f / (1<<20))
      elsif size > 1<<10
        '%0.2f Kb' % (size.to_f / (1<<10))
      else
        "#{size} b"
      end
    end

    def to_s(csv = true)
      if csv
        "#{year},#{month},#{day},#{hour},#{minute},#{latency},#{download},#{upload},#{fw_down},#{fw_up}"
      else
        <<-EOS
Date: #{year.to_s.rjust(4,'0')}-#{month.to_s.rjust(2,'0')}-#{day.to_s.rjust(2,'0')}
Time: #{hour.to_s.rjust(2,'0')}:#{minute.to_s.rjust(2,'0')}
Latency: #{latency} ms
Test Download: #{friendly download}/s
Test Upload: #{friendly upload}/s
Other Download: #{friendly fw_down}/s
Other Upload: #{friendly fw_up}/s
        EOS
      end
    end

    def self.header
      'Year,Month,Day,Hour,Minute,Latency(ms),Test-Down,Test-Up,Other-Down,Other-Up'
    end

    def self.parse(line)
      y, m, d, h, n, l, td, tu, fd, fu = line.split(',').map{|v| v.to_i}
      SpeedLog::Record.new(Time.new(y, m, d, h, n), l, td, tu, fd, fu)
    end

  end

  attr_reader :path

  def records
    @records ||= []
  end

  def initialize(path)
    @path = path
    if File.exist?(path)
      lines = File.read(path).split("\n")
      lines.delete_at(0)
      lines.each do |line|
        records << SpeedLog::Record.parse(line)
      end
    end
  end

  def purge_older_than(max_days)
    max_days = 1 if max_days < 1
    cutoff = Time.now - (max_days * 86400)
    records.keep_if{|rec| rec.time >= cutoff}
  end

  def save
    File.open path, 'wt' do |f|
      f.write SpeedLog::Record.header
      f.write "\n"
      records.each do |rec|
        f.write rec.to_s
        f.write "\n"
      end
      f.flush
    end
  end

end



if __FILE__==$0
  require_relative './firewall_info.rb'

  def to_bps(val)
    n,x = val.split(' ')
    n = n.to_f
    x = case x.upcase
          when 'GBIT/S', 'GBPS'
            1 << 30
          when 'MBIT/S', 'MBPS'
            1 << 20
          when 'KBIT/S', 'KBPS'
            1 << 10
          when 'BIT/S', 'BPS'
            1
          else
            1
        end
    (n * x).to_i
  end

  def fw_stats(fw_addr)
    seconds = 5
    fw_start = FirewallInfo.new fw_addr
    sleep seconds
    fw_end = FirewallInfo.new fw_addr
    fw_ddiff = (fw_end.download_bytes - fw_start.download_bytes) * 8
    fw_udiff = (fw_end.upload_bytes - fw_start.upload_bytes) * 8

    fw_down = (fw_ddiff.to_f / seconds).to_i
    fw_up = (fw_udiff.to_f / seconds).to_i

    [ fw_down, fw_up ]
  end

  fw_addr = if ARGV.count > 0
              ARGV[0].to_s.strip
            else
              print 'Firewall Address: '
              STDIN.gets.to_s.strip
            end

  if %w(-? /? --help /help).include?(fw_addr)
    print "Usage: #{File.basename($0)} [firewall-ip-address [csv-file-path [server-id]]]\n"
    exit 0
  end

  csv_file = if ARGV.count > 1
               ARGV[1].to_s.strip
             else
               print 'CSV File: '
               STDIN.gets.to_s.strip
             end

  server_id = if ARGV.count > 2
                " --server #{ARGV[2].to_s.strip}"
              else
                ''
              end

  print "Gathering info, please wait...\n"

  fw_before = fw_stats fw_addr
  speedtest_lines = `speedtest-cli --simple#{server_id}`.split("\n").map{|v| v.strip}
  fw_after = fw_stats fw_addr

  latency = download = upload = nil

  speedtest_lines.each do |line|
    if line != ''
      var,val = line.split(':').map{|v| v.strip}
      if val
        case var.upcase
          when 'PING'
            latency = (val.split(' ')[0].to_f + 0.5).to_i

          when 'DOWNLOAD'
            download = to_bps(val)

          when 'UPLOAD'
            upload = to_bps(val)
        end
      end
    end
  end

  fw_down = (fw_before[0] + fw_after[0]) / 2
  fw_up = (fw_before[1] + fw_after[1]) / 2

  log = SpeedLog.new(csv_file)
  rec = SpeedLog::Record.new(Time.now, latency, download, upload, fw_down, fw_up)

  log.purge_older_than 28
  log.records << rec
  log.save

  print "#{rec.to_s false}\n"
end
