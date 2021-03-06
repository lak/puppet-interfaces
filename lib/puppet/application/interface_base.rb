require 'puppet/application'
require 'puppet/interface'

class Puppet::Application::InterfaceBase < Puppet::Application
  should_parse_config
  run_mode :agent

  def preinit
    super
    trap(:INT) do
      $stderr.puts "Cancelling Interface"
      exit(0)
    end
  end

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  option("--format FORMAT") do |arg|
    @format = arg.to_sym
  end

  option("--mode RUNMODE", "-r") do |arg|
    raise "Invalid run mode #{arg}; supported modes are user, agent, master" unless %w{user agent master}.include?(arg)
    self.class.run_mode(arg.to_sym)
    set_run_mode self.class.run_mode
  end


  attr_accessor :interface, :type, :verb, :arguments, :format
  attr_writer :exit_code

  # This allows you to set the exit code if you don't want to just exit
  # immediately but you need to indicate a failure.
  def exit_code
    @exit_code || 0
  end

  def main
    # Call the method associated with the provided action (e.g., 'find').
    if result = interface.send(verb, *arguments)
      puts render(result)
    end
    exit(exit_code)
  end

  # Override this if you need custom rendering.
  def render(result)
    render_method = Puppet::Network::FormatHandler.format(format).render_method
    if render_method == "to_pson"
      jj result
      exit(0)
    else
      result.send(render_method)
    end
  end

  def setup
    Puppet::Util::Log.newdestination :console

    @verb = command_line.args.shift
    @arguments = command_line.args
    @arguments ||= []

    @arguments = Array(@arguments)

    @type = self.class.name.to_s.sub(/.+:/, '').downcase.to_sym

    unless Puppet::Interface.interface?(@type)
      raise "Could not find interface '#{@type}'"
    end
    @interface = Puppet::Interface.interface(@type)
    @format ||= @interface.default_format

    # We copy all of the app options to the interface.
    # This allows each action to read in the options.
    @interface.options = options

    validate
  end

  def validate
    unless verb
      raise "You must specify #{interface.actions.join(", ")} as a verb; 'save' probably does not work right now"
    end

    unless interface.action?(verb)
      raise "Command '#{verb}' not found for #{type}"
    end
  end
end
