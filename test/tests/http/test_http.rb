# class TestHTTP << Test::Unit::TestCase
#     
#     def initialize
#         @adapter = 'default'
#         @port = find_open_port
#     end
#     
#     def setup
#         start_server()
#     end
#     
#     def teardown
#         @server.shutdown
#     end
#     
#     def test_connect
#     end
#     
#     # Tests
#     
#     def test_connect
#     
#     # Utility methods
#     
#     def start_server()
#         @server = Spider::HTTP::Server.get(@adapter)
#         @server.start(:port => @port)
#     end
#         
#     def find_open_port(port=80000)
#         begin
#             socket = Socket.new( AF_INET, SOCK_STREAM, 0 )
#             sockaddr = Socket.pack_sockaddr_in( port, '127.0.0.1' )
#             socket.bind( sockaddr )
#         rescue Errno::EADDRINUSE
#             socket.close
#             port += 1
#             retry
#         end
#         socket.close
#         return port
#     end
#     
# end