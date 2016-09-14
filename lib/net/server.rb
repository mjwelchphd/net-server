# = net/server.rb
#
# Copyright (c) 2016 Michael J. Welch, Ph.D.
#
# Written and maintained by Michael J. Welch, Ph.D. <mjwelchphd@gmail.com>
#
# This work is not derived from any other work. It is original software.
#
# Documented by Michael J. Welch, Ph.D. <mjwelchphd@gmail.com>
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms as Ruby itself.
#
# See the README.md for documentation.
#

require 'openssl'
require 'socket'

module Net

  # :stopdoc:
  class ServerTerminate < Exception; end
  class ServerQuit < Exception; end
  # :startdoc:

  # == An Internet server
  class Server

private

    def initialize(options={})
      path = __FILE__.chomp('server.rb')
      @option_list = [[:server_name, "example.com"], [:listening_ports, ["25","486","587"]], \
        [:private_key, "#{path}server.key"], [:certificate, "#{path}server.crt"], \
        [:user_name, nil], [:group_name, nil], [:working_directory, File::realpath('.')], \
        [:pid_file, "pid"], [:daemon, false]]
      @options = {}
      @option_list.each do |key,value|
        @options[key] = if options.has_key?(key) then options[key] else value end
      end
    end # initialize

    include Socket::Constants

    #
    # This is the code executed after the process has been
    # forked and root privileges have been dropped.
    #
    def process_call(connection, local_port, remote_port, remote_ip, remote_hostname, remote_service)
      begin
        Signal.trap("INT") { } # ignore ^C in the child process
        LOG.info("%06d"%Process::pid) {"Connection accepted on port #{local_port} from port #{remote_port} at #{remote_ip} (#{remote_hostname})"} if LOG

        # a new object is created here to provide separation between server and receiver
        # this call receives the email and does basic validation
        Receiver::new(connection, @options).receive(local_port, Socket::gethostname, remote_port, remote_hostname, remote_ip)
      rescue ServerQuit
        # nothing to do here
      end
    end # process_call

    #
    # This method drops the process's root privileges for security reasons.
    #
    def drop_root_privileges(user_name, group_name, working_directory)
      # drop root privileges
      if Process::Sys.getuid==0
        user = Etc::getpwnam(user_name)
        group = Etc::getgrnam(group_name)
        Dir.chdir(user.dir)
        Dir.chdir(working_directory) if not working_directory.nil?
        Process::GID.change_privilege(group.gid)
        Process::UID.change_privilege(user.uid)
      end
    end # drop_root_privileges

    #
    # both the AF_INET and AF_INET6 families use this DRY method
    # to bind to the socket.
    #
    def bind_socket(family,port,ip)
      socket = Socket.new(family, SOCK_STREAM, 0)
      sockaddr = Socket.sockaddr_in(port.to_i,ip)
      socket.setsockopt(:SOCKET, :REUSEADDR, true)
      socket.bind(sockaddr)
      socket.listen(0)
      return socket
    end # bind_socket

    #
    # The listening thread is established in this method depending on the ListenPort
    # argument passed to it -- it can be '<ipv6>/<port>', '<ipv4>:<port>', or just '<port>'.
    #
    def listening_thread(local_port)
      LOG.info("%06d"%Process::pid) {"listening on port #{local_port}..."} if LOG

      # establish an SSL context
      $ctx = OpenSSL::SSL::SSLContext.new
      $ctx.key = $prv
      $ctx.cert = $crt
      
      # check the parameter to see if it's valid
      m = /^(([0-9a-fA-F]{0,4}:{0,1}){1,8})\/([0-9]{1,5})|(([0-9]{1,3}\.{0,1}){4}):([0-9]{1,5})|([0-9]{1,5})$/.match(local_port)
      #<MatchData "2001:4800:7817:104:be76:4eff:fe05:3b18/2000" 1:"2001:4800:7817:104:be76:4eff:fe05:3b18" 2:"3b18" 3:"2000" 4:nil 5:nil 6:nil 7:nil>
      #<MatchData "23.253.107.107:2000" 1:nil 2:nil 3:nil 4:"23.253.107.107" 5:"107" 6:"2000" 7:nil>
      #<MatchData "2000" 1:nil 2:nil 3:nil 4:nil 5:nil 6:nil 7:"2000">
      case
        when !m[1].nil? # it's AF_INET6
          socket = bind_socket(AF_INET6,m[3],m[1])
        when !m[4].nil? # it's AF_INET
          socket = bind_socket(AF_INET,m[6],m[4])
        when !m[7].nil?
          socket = bind_socket(AF_INET6,m[7],"0:0:0:0:0:0:0:0")
        else
          raise ArgumentError.new(local_port)
      end # case
      ssl_server = OpenSSL::SSL::SSLServer.new(socket, $ctx);

      # main listening loop starts in non-encrypted mode
      ssl_server.start_immediately = false
      loop do
        # we can't use threads because if we drop root privileges on any thread,
        # they will be dropped for all threads in the process--so we have to fork
        # a process here in order that the reception be able to drop root privileges
        # and run at a user level--this is a security precaution--the other reason
        # to use processes is that they can be run on multiple processors
        connection = ssl_server.accept
        Process::fork do
          # now we're in the child process
          begin
            drop_root_privileges(@options[:user_name],@options[:group_name],@options[:working_directory]) if !@options[:user_name].nil?
            remote_hostname, remote_service = connection.io.remote_address.getnameinfo
            remote_ip, remote_port = connection.io.remote_address.ip_unpack
            process_call(connection, local_port, remote_port.to_s, remote_ip, remote_hostname, remote_service)
          ensure
            # here we close the child's copy of the connection --
            # since the parent already closed it's copy, this
            # one will send a FIN to the client, so the client
            # can terminate gracefully
            connection.close
            LOG.info("%06d"%Process::pid) {"Connection closed on port #{local_port} by #{@options[:server_name]}"} if LOG
            # and finally, close the child's link to the log
            LOG.close if LOG
          end
          # the child process ends here
        end # fork
        # now we're in the parent process
        # here we close the parent's copy of the connection --
        # the child (created by the Process::fork above) has another copy --
        # if this one is not closed, when the child closes it's copy,
        # the child's copy won't send a FIN to the client -- the FIN
        # is only sent when the last process holding a copy to the
        # socket closes it's copy
        connection.close
      end # loop
    end # listening_thread

public

    #
    # This is the main setup and loop.
    #
    def start
      # generate the first log messages
      LOG.info("%06d"%Process::pid) {"Starting RubyMTA at #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}, pid=#{Process::pid}"} if LOG
      LOG.info("%06d"%Process::pid) {"Options specified: #{ARGV.join(", ")}"} if LOG && ARGV.size>0

      # get the certificates, if any; they're needed for STARTTLS
      # we do this before daemonizing because the working folder might change
      $prv = if @options[:private_key] then OpenSSL::PKey::RSA.new File.read(@options[:private_key]) else nil end
      $crt = if @options[:certificate] then OpenSSL::X509::Certificate.new File.read(@options[:certificate]) else nil end

      # daemonize it if the option was set--it doesn't have to be root to daemonize it
      Process::daemon if @options[:daemon]

      # get the process ID and the user id AFTER demonizing, if that was requested
      pid = Process::pid
      uid = Process::Sys.getuid
      gid = Process::Sys.getgid
      
      LOG.info("%06d"%Process::pid) {"Daemonized at #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}, pid=#{pid}, uid=#{uid}, gid=#{gid}"} if LOG && @options[:daemon]

      # store the pid of the server session
      begin
        puts "RubyMTA running as PID=>#{pid}, UID=>#{uid}, GID=>#{gid}"
        File.open(@options[:pid_file],"w") { |f| f.write(pid.to_s) }
      rescue Errno::EACCES => e
        LOG.warn("%06d"%Process::pid) {"The pid couldn't be written. To save the pid, create a directory for '#{@options[:pid_file]}' with r/w permissions for this user."} if LOG
        LOG.warn("%06d"%Process::pid) {"Proceeding without writing the pid."} if LOG
      end

      # if ssltransportagent was started as root, make sure UserName and
      # GroupName have values because we have to drop root privileges
      # after we fork a process for the receiver
      if uid==0 # it's root
        if @options[:user_name].nil? || @options[:group_name].nil?
          LOG.error("%06d"%Process::pid) {"ssltransportagent can't be started as root unless UserName and GroupName are set."} if LOG
          exit(1)
        end
      end

      # this is the main loop which runs until admin enters ^C
      Signal.trap("INT") { raise ServerTerminate.new }
      Signal.trap("HUP") { restart if defined?(restart) }
      Signal.trap("CHLD") do
        begin
        Process.wait(-1, Process::WNOHANG)
        rescue Errno::ECHILD => e
          # ignore the error
        end
      end # trap-chld
      threads = []
      # start the server on multiple ports (the usual case)
      begin
        @options[:listening_ports].each do |port|
          threads << Thread.start(port) do |port|
            listening_thread(port)
          end
        end
        # the joins are done ONLY after all threads are started
        threads.each { |thread| thread.join }
      rescue ServerTerminate
        LOG.info("%06d"%Process::pid) {"#{@options[:server_name]} terminated by admin ^C"} if LOG
      end

      # attempt to remove the pid file
      begin
        File.delete(@options[:pid_file])
      rescue Errno::ENOENT => e
        LOG.warn("%06d"%Process::pid) {"No such file: #{e.inspect}"} if LOG
      rescue Errno::EACCES, Errno::EPERM
        LOG.warn("%06d"%Process::pid) {"Permission denied: #{e.inspect}"} if LOG
      end
    end # start
  end
end
