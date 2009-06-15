module Spider
    
    class ControllerIO < IO
        BUFSIZE = 1024*4
        
        def write
            raise NotImplementedError
        end
        
        def flush
            raise NotImplementedError
        end
        
        def set_body_io(io)
            if (io.is_a?(String))
                write(io)
            else
                while (buf = io.read(BUFSIZE))
                    write(buf)
                end
            end
        end
        
    end
    
end