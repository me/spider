require 'rbconfig'

if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
    begin
      require 'win32ole'
    rescue LoadError
    end
end

module Spider

    module Memory

        def self.get_memory_usage
            if defined? WIN32OLE
                wmi = WIN32OLE.connect("winmgmts:root/cimv2")
                mem = 0
                query = "select * from Win32_Process where ProcessID = #{$$}"
                wmi.ExecQuery(query).each do |wproc|
                    mem = wproc.WorkingSetSize
                end
                mem.to_i / 1000
            elsif proc_file = File.new("/proc/#{$$}/smaps") rescue nil
                proc_file.map do |line|
                    size = line[/Size: *(\d+)/, 1] and size.to_i
                end.compact.inject(0){ |s, v| s += v }
            else
                `ps -o vsz= -p #{$$}`.to_i
            end
        end

    end

end