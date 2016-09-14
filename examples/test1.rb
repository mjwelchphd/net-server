#! /usr/bin/ruby

##
# put in your website address in place of www.example.com
# telnet www.example.com 2000

require 'net/server'
require 'logger'

class Receiver

  def initialize(connection)
    @connection = connection
  end

  def send(data)
    puts "<--  #{data}"
    @connection.write(data)
    @connection.write("\r\n")
  end

  def recv
    data = @connection.gets
    data = data.chomp if data
    puts " --> #{data}"
    return data
  end

  def receive(local_port, local_hostname, remote_port, remote_hostname, remote_ip)

    # send some connect information
    send("local_port      => #{local_port.inspect}")
    send("local_hostname  => #{local_hostname.inspect}")
    send("remote_port     => #{remote_port.inspect}")
    send("remote_hostname => #{remote_hostname.inspect}")
    send("remote_ip       => #{remote_ip.inspect}")
    send("options         => #{@options.inspect}")
    send(" ")
    send("Type 'q' to quit this connection only.")
    send(" ")

    # receive and echo anything sent by telnet
    text = ' '
    while text[0]!='q'
      text = recv
      send(text)
    end
  end
end

LOG = Logger::new('log/test1.log', 'daily')
LOG.formatter = proc do |severity, datetime, progname, msg|
  pname = if progname then '('+progname+') ' else nil end
  "#{datetime.strftime("%Y-%m-%d %H:%M:%S")} [#{severity}] #{pname}#{msg}\n"
end

options = {
  :server_name=>"www.example.com",
#  :private_key=>"server.key",
#  :certificate=>"server.crt",
  :listening_ports=>['2000','2001'],
#  :user_name=>"myusername",
#  :group_name=>"mygroupname"
}
Net::Server::new(options).start
