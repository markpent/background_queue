require 'timeout'

module BackgroundQueue::ClientLib
  #A connection to a backend queue server
  #Handles sending the command to the server and receiving the reply
  #For now connections are not pooled/reused
  class Connection
    def initialize(client, server)
      @client = client
      @server = server
      @socket = nil
    end
    
    #send a command to the server
    def send_command(command)
      check_connected
      send_with_header(command.to_buf)
      response = receive_with_header
      BackgroundQueue::ClientLib::Command.from_buf(response)
    end
    
    private
    
    def connect
      begin
        Timeout::timeout(3) {
          @socket = TCPSocket.open(@server.host, @server.port)
          true
        }
      rescue Timeout::Error
        raise BackgroundQueue::ClientLib::ConnectionError, "Timeout Connecting to #{@server.host}:#{@server.port}"
      rescue Exception=>e
        raise BackgroundQueue::ClientLib::ConnectionError, "Error Connecting to #{@server.host}:#{@server.port}: #{e.message}"
      end
    end
    
    def check_connected
      connect if @socket.nil?
    end
    
    def send_data(data)
      written = 0
      to_write = data.length
      while written < to_write do
        begin
          Timeout::timeout(5) {
            amt_written = @socket.write(data)
            written += amt_written
            if written < to_write
              data = data[amt_written, data.length - amt_written  ]
            end    
          }
        rescue Timeout::Error
          raise BackgroundQueue::ClientLib::ConnectionError, "Timeout Sending to #{@server.host}:#{@server.port}"
        rescue Exception=>e
          raise BackgroundQueue::ClientLib::ConnectionError, "Error Sending to #{@server.host}:#{@server.port}: #{e.message}"
        end
      end
      true
    end
    
    def self.add_header(data)
      length = data.length
      [1,length, data].pack("SLZ#{length}")
    end
    
    def send_with_header(data)
      send_data(BackgroundQueue::ClientLib::Connection.add_header(data))
    end
    
    def receive_data(length)
      to_read = length
      amt_read = 0
      sbuf = ""
      while amt_read < to_read do
        begin
          Timeout::timeout(5) {
            read_amt = to_read - amt_read
            tbuf = @socket.recvfrom(read_amt)[0]
            sbuf << tbuf
            amt_read += tbuf.length
          }
        rescue Timeout::Error
          raise BackgroundQueue::ClientLib::ConnectionError, "Timeout Receiving #{length} bytes from #{@server.host}:#{@server.port}"
        rescue Exception=>e
          raise BackgroundQueue::ClientLib::ConnectionError, "Error Receiving #{length} bytes from #{@server.host}:#{@server.port}: #{e.message}"
        end
      end
      sbuf
    end
    
    def receive_with_header
      header = receive_data(6).unpack("SL")
      receive_data(header[1])
    end
    
    
  end
  
  
  #Error raised when communication failure occurs
  class ConnectionError < Exception
    
  end
end
