#! /usr/bin/ruby

## For testing ...
# put in your website address in place of www.example.com
# swaks -s www.example.com:2000 -t coco@smith.com -f jamie@glock.com --ehlo example.com
# swaks -tls -s www.example.com:2000 -t coco@smith.com -f jamie@glock.com --ehlo example.com

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

  # don't use this as an example of how to write
  # an email receiver--it's just a simplified demo
  def receive(local_port, local_hostname, remote_port, remote_hostname, remote_ip)
    send("220 mail.example.com ESMTP");

    done = false
    tls_started = false
    while !done
      text = recv
      case
      when text.start_with?("QUIT")
        send("221 2.0.0 OK mail.example.com closing connection")
        break;
      when text.start_with?("EHLO")
        send("250-2.0.0 mail.example.com Hello")
        send("250-STARTTLS") if !tls_started
        send("250 HELP")
      when text.start_with?("STARTTLS")
        send("220 TLS go ahead")
        @connection.accept
        tls_started = true
      when text.start_with?("MAIL")
        send("250 OK")
      when text.start_with?("RCPT")
        send("250 OK")
      when text.start_with?("DATA")
        send("354 Enter message, ending with \".\" on a line by itself")
        while text.chomp!='.'
          text = recv
        end
        send("250 OK id=123456-654321-99")
      end
    end
  end
end

LOG = Logger::new('log/test2.log', 'daily')
LOG.formatter = proc do |severity, datetime, progname, msg|
  pname = if progname then '('+progname+') ' else nil end
  "#{datetime.strftime("%Y-%m-%d %H:%M:%S")} [#{severity}] #{pname}#{msg}\n"
end

options = {
  :server_name=>"www.example.com",
#  :private_key=>"server.key",
#  :certificate=>"server.crt",
  :listening_ports=>['2000','2001']
#  :user_name=>"myusername",
#  :group_name=>"mygroupname",
#  :daemon = true
}
Net::Server::new(options).start
