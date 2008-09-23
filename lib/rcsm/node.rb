require 'net/ssh'

class Rcsm::Node
  attr_accessor :ssh

  # Instantiates a new Rcsm::Node
  # === Parameters
  # [+host+] A String representing the host. If not 'localhost',
  #          'user@hostname' syntax can be used to specify the user. If no user
  #          indicated, it will use the currently logged in user.
  # [+*options+] An array that will be converted into a hash of options,
  #              then initialized as instance variables. However, there are 
  #              three options that will be used in the case of a remote
  #              connection, and will not be initialized into the box:
  #              * +:password+ - both the ssh login password and sudo password
  #              (see Enumerable.to_options_hash and Object.initialize_options)
  #              * +:port+ - the ssh port to connect on (defaults to 22)
  #              * +:user+ - the login/username to use for logging in and when
  #                a sudo password is requested. This can also be specified in
  #                the +host+ argument, but if given here will override any
  #                prior declarations (namely the username in the host argument)
  # === Returns
  # nothing in particular
  # === Raises
  # nothing
  def initialize(host, *options)
    options = options.to_options_hash
    user_and_hostname = get_host_and_user(host, options)
    initialize_options(options.merge(user_and_hostname))
  end
  
  ##
  # Executes a command locally or over ssh. Seems simple enough, but supporting sudo 
  # makes it difficult.
  def exec(cmd)
    return `#{cmd}` if self.local?
    
    # the built in ssh.exec wraps some stuff up for us, but to catch sudo we 
    # have to construct the whole thing ourselves, starting with the channel.
    channel = ssh.open_channel do |channel|
      # now we request a "pty" (i.e. interactive) session so we can send data
      # back and forth if needed. it WILL NOT WORK without this, and it has to
      # be done before any call to exec.
      channel.request_pty do |ch, success|
        raise "Could not obtain pty (i.e. an interactive ssh session)" if !success
      end

      channel.exec(cmd) do |ch, success|
        # 'success' isn't related to bash exit codes or anything, but more
        # about ssh internals (i think... not bash related anyways).
        # not sure why it would fail at such a basic level, but it seems smart
        # to do something about it.
        abort "could not execute command" unless success
        
        # on_data is a hook that fires when the loop that this block is fired
        # in (see below) returns data. This is what we've been doing all this
        # for; now we can check to see if it's a password prompt, and 
        # interactively return data if so (see request_pty above).
        channel.on_data do |ch, data|
          if data == "Password:"
            raise "The connection asked for a sudo password, and I don't have one" unless @password
            channel.send_data "#{@password}\n"
          else
            # ssh channels can be treated as a hash for the specific purpose of
            # getting values out of the block later
            channel[:result] ||= ""
            channel[:result] << data
          end 
        end
        
        channel.on_extended_data do |ch, type, data|
          raise "SSH command returned on stderr: #{data}"
        end
      end
    end

    # Nothing has actually happened yet. Everything above will respond to the
    # server after each execution of the ssh loop until it has nothing left
    # to process. For example, if the above recieved a password challenge from
    # the server, ssh's exec loop would execute twice - once for the password,
    # then again after clearing the password (or twice more and exit if the
    # password was bad)
    channel.wait
    
    # it returns with \r\n at the end
    return channel[:result] ? channel[:result].strip : nil
  end
  
  # returns the ssh connection opened for the node, or starts a new one if none
  # existed
  def ssh
    @ssh ||= Net::SSH.start(
      @hostname,
      @user,
      :password => @password,
      :port => (@port || 22)
    )
  end

  ##
  # Gets the host and user from host and options.
  # === Parameters
  # [+host+] A String representing the host.
  #          'user@hostname' syntax can be used to specify the user. If no user
  #          indicated, it will use the user currently logged in to the OS.
  # [+options+] A hash of options (probably from initialize), of which :user
  #             will be set above any other method of getting the user.
  # === Returns
  # an array of [user, host]
  # === Raises
  # nothing
  def get_host_and_user(host, options = {})
    hostname = host.split("@").last
    if host.split("@").size > 1
      user = host.split("@").first
    else
      # TODO: MS compatability for getting the currently logged in user.
      # The SysUtils gem has a cross-platform method for getting the user
      # but I don't want to add a dependency for everyone just 'cuz MS needs
      # SysUtils. Thus, for MS compatability we would need to check whether
      # we're on windows, then require SysUtils and use it to check for the
      # current user, else use Etc. Some other time...
      user = Etc.getlogin
    end
    user = options.delete(:user) if options[:user]
    return {:user => user, :hostname => hostname}
  end
  
  def to_s
    "#{@hostname}#{" (#{@ip}) " if @ip}"
  end
  
  alias :inspect! :inspect
  def inspect
    to_s
  end
  
  ##
  # Access services on the box.
  # === Parameters
  # [+key+] Look up a service running on this box, e.g.
  #         box[:mongrel]
  # === Returns
  # A subclass of Rcsm::Service (see Rcsm::Service.factory)
  # === Raises
  # nothing
  def [](key)
    Rcsm::Service.factory(key.to_sym, self)
  end
  
  def method_missing(method, *args, &block)
    Rcsm::Service.factory(method.to_sym, self)
  end
  
  ##
  # Returns boolean value for whether or not this node is local, taking into
  # account the computer's real hostname (i.e. not just localhost)
  def local?
    case @hostname
    when 'localhost'
      true
    when @sys_hostname ||= Socket.gethostname
      true
    else
      false
    end
  end
  
end