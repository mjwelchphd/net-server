# Net::Server
The Net::Server Ruby gem is a server for web apps. It's purpose is to establish one or more listeners, and create a process to handle each incoming request. 

#### It has the following features:
1. It can listen on any number of ports simultaneously.
2. It starts a separate receiver process to handle each connection.
3. The server may run as root, but the processes will lose their root privileges soon after creation. This is a security feature.
4. The receiver processes can switch on full encryption (STARTTLS in a mail server, for example).
5. A log file will be used, if it exists. You create the log using the 'logger' gem.
7. Runs until terminated by a `KILL -INT <pid>` or `^C`.
9. Two example programs are included.

### TODO
* RSPEC tests.

# Gem Dependancies
This gem requires the following:
```ruby
require 'openssl'
require 'socket'
```
Both of these packages are found in the Ruby Standard Library (stdib 2.2.2 at the time of this writing). They are required in the gem itself, so you don't have to require them.

# Creating a Self-Signed Certificate
Use OpenSSL to create a self-signed certificate for testing as follows:
```bash
$ openssl req -x509 -newkey rsa:2048 -keyout example.key -out example.crt -days 9000 -nodes
$ chmod 400 example.key
$ chmod 444 example.crt
```
Put the two files anywhere you want, and specify their path in the start call (see the last line of the example programs). If you don't specify these two files, they will default to the ones that come with the gem, but since anyone can download the gem and look at the files, they are not secure.

# How to Get Net::Server Gem

To install the gem, simply use the *gem* application:
```bash
$ sudo gem install net-server
```
Alternately, you can clone the project on GitHub at:
```bash
https://github.com/mjwelchphd/net-server
```
and build it yourself.

The example programs are only found in the source on GitHub at github.com/mjwelchphd/net-server.

If you're using Builder, follow your normal routine for adding gems.

# How to Build a Basic Server

The basic server looks like this:
```ruby
require 'net/server'

class Receiver

  def initialize(connection, options)
    @connection = connection
    @options = options
  end

  def receive(local_port, local_hostname, remote_port, remote_hostname, remote_ip)
    <send and receive data>
    # when this method exits, the process is cleaned up and terminated by Net::Server
  end

end

LOG = Logger::new(<log-file-path>, <log-file-name>)

Net::Server.new(<options>).start
```
There are two test applications included in the gem in the examples folder. Test1 just echos a telnet connection. Test2 implements a simple email receiver you can test with swaks.

## Options
  
  Option | Default | Description
  --- | --- | ---
  :server_name | "example.com" | This name is only used in error messages.
  :listening_ports | ["25","486","587"] | An array of one or more ports to listen on.
  :private_key | Internal key | The key for encrypting/decrypting the data when in TLS mode.
  :certificate | Internal self-signed certificate | The certificate for encrypting/decrypting the data when in TLS mode. This may be your own self-signed certificate, or one you purchase from a Certificate Authority, or you can become a Certificate Authority and sign your own.
  :user_name | nil | This name is the user name to which each process will be switched after it is created. If it is nil, the ownership of the process will not be changed after creation. If you are using a port less than 1024, you must start the server as root, and the user name and group name of the process _must be_ specified.
  :group_name | nil | This name is the group name to which each process will be switched after it is created.
  :working_directory | the current path | The location of the program running the server.
  :pid_file | "pid" | The PID of the server will be stored in this file.
  :daemon | false | If this option is true, the server will be started as a daemon.

You can pass Receiver options thru here also because these options are passed to the Receiver during the instantiation of the Receiver object. You can add options that you'll use in your own programming as well. Net::Server only looks for it's own options, so the presence of other options does no harm.

## Logging

The log file must be created by the 'logger' gem, and must be named LOG.

## Terminating the Server

### HUP and INT (^C) traps

A `kill -INT <pid>` or `<ctrl-C>` will terminate the server.
```bash
$ test1.rb
^C
test1 terminated by admin ^C
$
```
or
```bash
sudo kill -INT `cat /run/net-server/net-server.pid`
```

A `kill -HUP <pid>` will activate a restart method, if you have one defined in your code. For example, if you put this in your code:
```ruby
class Server
  def restart
  	puts "I just got a HUP request."
  end
end
```
then at another terminal enter:
```ruby
$ ps ax | grep test1
  823 pts/0    Sl+    0:00 test1.rb
  829 pts/1    S+     0:00 grep --color=auto test1
$ kill -hup 823
```
or
```bash
kill -HUP `cat pid`
```
it will result in:
```bash
net-server received a HUP request
I just got a HUP request.
```
at the terminal where `test1.rb` is running, with no other action. The first message comes from `net-server` itself, and the second comes from the `def restart` you defined.

#### Example

If you define your options in a class variable Hash object, say @options, if the values change, the new values take effect immediately, except for :daemon which requires a manual restart. For instance,

```ruby
@options = {
  :server_name=>"www.example.com",
  :private_key=>"server.key",
  :certificate=>"server.crt",
  :listening_ports=>['2000','2001']
  :user_name=>"myusername",
  :group_name=>"mygroupname",
  :daemon = true
}
Net::Server::new(@options).start
```
starts the server, then
```ruby
class Server
  def restart
    @options = {
      :user_name=>"yourusername",
      :group_name=>"yourgroupname"}
  end
end
```
will change the user name and group name for all new processes when the HUP is received.


FIN
