module Spider
    
    module ConsoleWizard
        
        def notify(msg)
            puts msg
        end
        
        def notify_partial(msg, finish=false)
            print msg
            puts if finish
        end
        
        def error(msg)
            puts msg
        end
        
        def ask_error
            res = ask?(_("Do you want to change your settings?"), :default => true)
            !res
        end
        
        def do_ask(msg, var_name, options)
            trap('TERM', lambda{ puts _(" Exiting."); exit })
            trap('INT', lambda{ puts _(" Exiting."); exit })
            str = msg
            options ||= {}
            if options[:choices]
                str += "\n"
                if options[:allow_cancel]
                    cancel_str = options[:allow_cancel] == true ? _("Cancel") : options[:allow_cancel]
                    str += "0) #{cancel_str} "
                end
                options[:choices].each_with_index do |c, i|
                    str += "#{i+1}) #{c} "
                end
            end
            prompt = ""
            yes = no = y = n = nil
            curr = nil
            if var_name
                add_key(var_name)
                curr = get_value(var_name)
            end
            if options[:type] == Spider::Bool
                yes = _("yes")
                no = _("no")
                y = yes[0].chr
                n = no[0].chr
                if options[:default] == true
                    y = y.upcase
                elsif options[:default] == false
                    n = n.upcase
                end
                prompt = "[#{y}/#{n}]: "
            elsif curr
                prompt = "[#{curr}]: "
            elsif options[:default]
                prompt = "[#{options[:default]}]: "
            else
                prompt = ">> "
            end
            
            
            good = false
            puts str
            
            while !good

                print prompt
            
                res = $stdin.gets.strip
                
                good = true
                if options[:type] == Spider::Bool
                    if res == yes || res == y
                        res = true
                    elsif res == no || res == n
                        res = false
                    elsif options[:default]
                        res = options[:default]
                    else
                        good = false
                    end
                elsif res.to_s.empty?
                    if curr
                        res = curr
                    elsif options[:default]
                        res = options[:default]
                    end
                end
                if options[:choices]
                    if options[:allow_cancel] && res == "0"
                        res = nil
                    else
                        if res =~ /\d+/
                            res = res.to_i - 1
                            unless options[:return_index]
                                res = options[:choices][res]
                                good = false unless res
                            end
                        else
                            good = false unless options[:choices].include?(res)
                            if options[:return_index]
                                res = options[:choices].index(res)
                            end
                        end
                    end
                    
                end

                if res.to_s.empty? && options[:required]
                    good = false
                end
            end
            set_value(var_name, res) if var_name
            res
        end
        
        
        
    end
    
    class Wizard
        
        def initialize
            @_keys = {}
        end
        
        def ask(msg, *args)
            var_name = args.shift if args[0] && !args[0].is_a?(Hash)
            options = args.shift
            do_ask(msg, var_name, options)
        end
        
        def ask?(msg, options={})
            options[:type] = Spider::Bool
            do_ask(msg, nil, options)
        end
        
        def ask!(msg, *args)
            var_name = args.shift if args[0] && !args[0].is_a?(Hash)
            options = args.shift || {}
            options[:required] = true
            do_ask(msg, var_name, options)
        end
            
        
        def do_ask
        end
        
        def implementation(mod)
            extend mod
            @implementation = mod
        end
        
        def wizard_instance(klass)
            wizard = klass.new
            wizard.implementation(@implementation)
            wizard
        end
        
        def add_key(name)
            @_keys[name] = true
        end
        
        def set_value(name, val)
            @_keys[name] = true
            instance_variable_set("@#{name}", val)
        end
        
        def get_value(name)
            instance_variable_get("@#{name}")
        end
        
        def values
            @_keys.keys.map{ |k|
                get_value(k)
            }
        end
        
    end
    
    class SpiderSetupWizard < Wizard
        attr_accessor :first_run
        
        def run
        
            if ask? _("Do you want to configure a database?"), :default => (@first_run ? true : nil)
                ask _("Which database do you want to configure?"), :db_label, :default => 'default'
                conf = Spider.conf.get("storages.#{@db_label}")
                url_db_type = nil
                if conf && conf["url"]    
                    if conf["url"] =~ /db:(\w+):\/\//
                        url_db_type = $1
                    end
                end
                ask _("Database type: "), :db_type, :choices => ['mysql', 'oracle'], \
                    :default => url_db_type
                break unless @db_type
                db = wizard_instance(get_db_wizard(@db_type))
                db.parse_url(conf["url"]) if conf && conf["url"] && @db_type == url_db_type
                db.run
                editor = Spider.config.get_editor
                editor.set('storages', @db_label, 'url', db.get_url)
                editor.save
                puts _("Configuration saved.")
            end
            
        end
        
        
        def get_db_wizard(db_type)
            {
                'mysql' => MySQLSetupWizard,
                'oracle' => OracleSetupWizard
            }[db_type]
        end
        
    end
    
    
    class MySQLSetupWizard < Wizard
        
        def run
            
            require 'rubygems'
            require 'rubygems/command.rb'
            require 'rubygems/dependency_installer.rb'
            unless Gem.available?('mysql') || Gem.available?('ruby-mysql')
                if ask? _("Mysql gem is not available. Install?")
                    ok = false
                    while !ok
                        inst = Gem::DependencyInstaller.new
                        begin
                            inst.install 'mysql'
                        rescue
                            begin
                                inst.install 'ruby-mysql'
                            rescue
                                error _("Installation of mysql gem failed.")
                                return
                            end
                            puts _(
                            "The mysql gem failed to compile, so the pure-ruby version was installed.
                            You should install the compiled version manually for better performance.")
                        end
                    end
                else
                    error _("Can't configure mysql without the mysql gem.")
                    return
                end
            end
            require 'mysql'
            
            local = discovery
            use_local = nil
            unless local.empty?
                local_str = local.map{ |l|
                    l[:socket] ? l[:socket] : "#{l[:host]}:#{l[:port]}"
                }
                use_local = ask _("We found the following MySQL instances. Do you want to use one of them?"), 
                    :choices => local_str, :return_index => true, :allow_cancel => _("No")
                use_local = local[use_local] if use_local
            end
            @socket = nil
            @host = nil
            @port = nil
            if use_local
                @socket = use_local[:socket]
                @host = use_local[:host]
                @port = use_local[:port]
            else
                ok = false
                while !ok
                    if (ask _("Do you want to connect via socket or via network?"), 
                            :choices => ['socket', 'network']) == 'network'
                        ask _("Host:"), :host, :default => 'localhost'
                        ask _("Port:"), :port, :default => 3306
                    else
                        ask _("Socket location"), :socket
                    end
                    if @socket
                        if File.socket?(@socket)
                            ok = true
                        else
                            error _("%s does not seem to be a socket") % @socket
                        end
                    else
                        begin
                            s = TCPSocket::open(@host, @port)
                            ok = true
                        rescue
                            error _("Connection to %s failed") % "#{@host}:#{@port}"
                            ok = ask_error
                        end
                    end
                    
                end
            end
            ok = false
            connect_ok = false
            while !ok
                ask! _("Username"), :user
                ask _("Password"), :pass
                conn = @socket ? @socket : "#{@host}:#{@port}"
                notify_partial _("Trying to connect to mysql at %s ... ") % conn
                begin
                    m = ::Mysql.new(@host, @user, @pass, nil, @port, @socket)
                    m.ping
                    m.close
                    connect_ok = true
                    ok = true
                    notify_partial("Ok.", true)
                rescue
                    notify_partial("", true)
                    error _("Connection failed.")
                    ok = ask_error
                end
            end
            ok = false
            while !ok
                ask _("Db name:"), :db_name
                if connect_ok
                    notify_partial _("Checking if db exists... ")
                    begin
                        m = ::Mysql.new(@host, @user, @pass, @db_name, @port, @socket)
                        ok = true
                        notify_partial("Ok.", true)
                    rescue => exc
                        notify_partial("", true)
                        error _("Database %s does not exist.") % @db_name
                        ok = ask_error
                    end
                else
                    ok = true
                end
            end
        end
        
        def discovery
            check = ['/tmp/mysql.sock', '/var/lib/mysql/mysql.sock']
            local = []
            check.each do |c|
                local << {:socket => c} if File.socket?(c)
            end
            if local.empty?
                localhost = true
                begin
                    s = TCPSocket::open('localhost', 3306)
                    s.close
                rescue
                    localhost = false
                end
                local << {:host => 'localhost', :port => 3306} if localhost
            end
            local
        end
        
        def get_url
            return nil unless @user && @pass && @db_name && ((@host && @port) || @socket)
            @host ||= 'localhost'
            "db:mysql://#{@user}:#{@pass}@#{@host}:#{(@port || @socket)}/#{@db_name}"
        end
        
        def parse_url(url)
            @host, @user, @pass, @db_name, @port, @socket = Spider::Model::Storage::Db::Mysql.parse_url(url)
        end
        
    end
    
    class OracleSetupWizard < Wizard
    end
    
end