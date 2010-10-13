class Mysql < Spider::Master::DbResource
    PROVIDES = [:db, :mysql]
    
    OPTIONS = {
        :user => {
            :name       => _('MySQL username'),
            :notes      => _('Specify the username to connect with'),
            :default    => 'root'
        },
        :password => {
            :name       => _('MySQL password'),
            :notes      => _('Specify the password to connect with'),
            :attributes => ['password']
        },
        :host => {
            :name       => _('MySQL host'),
            :notes      => _("Specify something other than 'localhost' to connect via TCP")
        },
        :port => {
            :name       => _('MySQL port'),
            :notes      => _('Specify the port to connect to MySQL with (if nonstandard)')
        },
        :socket => {
            :name       => _('MySQL socket'),
            :notes      => _('Specify the location of the MySQL socket')
        }
    }
    
    def plugins
        {
            :mysql_query_statistics => {
                :options => {
                    :user => options[:user],
                    :password => options[:password],
                    :host => options[:host],
                    :port => options[:port],
                    :socket => options[:socket]                    
                }
                :override => true
            }
        }
    end
       
    
end