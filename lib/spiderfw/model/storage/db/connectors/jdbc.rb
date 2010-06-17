module Spider; module Model; module Storage; module Db; module Connectors

    module JDBC
        Mutex = java.lang.Object.new
        DriverManager = java.sql.DriverManager
        Statement = java.sql.Statement
        Types = java.sql.Types

        
        def self.driver_class(name)
            driver_class ||= begin
                driver_class_const = (name[0...1].capitalize + name[1..name.length]).gsub(/\./, '_')
                JDBC::Mutex.synchronized do
                    unless JDBC.const_defined?(driver_class_const)
                        driver_class_name = name
                        JDBC.module_eval do
                            include_class(driver_class_name) { driver_class_const }
                        end
                    end
                end
                JDBC.const_get(driver_class_const)
            end
            JDBC::DriverManager.registerDriver(driver_class)
            @driver_classes ||= {}
            @driver_classes[name] = driver_class
            driver_class
        end
        
    end


end; end; end; end; end