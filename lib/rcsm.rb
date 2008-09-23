require 'rubygems'
require 'fileutils'
require 'yaml'

$nodes = []

module Rcsm; end

Dir.glob(File.join(File.dirname(__FILE__), 'rcsm/**/*.rb')).each {|f| require f}

module Rcsm
  $CONF_DIR = "#{ENV["HOME"]}/.rcsm"
  $YAML_CONFIG = "#{$CONF_DIR}/config.yml"

  attr_reader :dir

  ##
  # Returns the config file as a hash, or just the section-relevant portion
  # if +:section+ option is given
  # === Parameters
  # [+options+] * +:section+ - will load a first-level subsection of the config.
  #               For example:
  #               
  #               <pre><code>
  #               :mongrel:
  #                 :environment: production
  #                 etc...
  #               </code></pre>
  #               
  #               could be loaded with :section => :mongrel (and would return 
  #               {:environment => "production"})
  #             * +:file+ - Defaults to ~/.rush/config.yml. Alternate configs
  #               are used mostly for testing.
  # === Returns
  # A Hash representing the loaded config. Will return everything if the
  # +:section+ option is not specified, otherwise will return just the
  # first-level section specified (see above).
  #
  # Returns {} if nothing is in the config, or the specified section
  # doesn't exist.
  # === Raises
  # Nothing
  def self.load_yaml(options = {})
    config_file = options[:file] || $YAML_CONFIG
    section = options[:section]
    
    FileUtils.mkdir($CONF_DIR) unless File.exists?($CONF_DIR)
    FileUtils.touch(config_file)
    config = YAML.load_file(config_file) || {}
    return section ? config[section] || {} : config
  end
  
  def self.initialize_nodes
    nodes_config = load_yaml(:section => :nodes)
    nodes_config.each do |hostname, options|
      options[:hostname] = hostname
      node = Rcsm::Node.new("#{options[:login] + "@"}#{hostname}", options)
      $nodes << node
    end
  end
end

Rcsm.initialize_nodes
