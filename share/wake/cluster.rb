require 'forwardable'
require 'uri'
require 'fileutils'
require_relative 'json_file'
require_relative 'config'

path = File.expand_path(File.join(CONFIG_DIR, "clusters"))

unless File.exists?(path)
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, "w") do |f|
    f << "{}"
  end
end

WAKE_CLUSTERS = JSONFile.new(path)

class WakeCluster
  extend Forwardable

  NoDefaultClusterSet = Class.new(StandardError)

  def self.default
    name = WakeConfig.get("default_cluster")

    if name
      get(name)
    else
      fail NoDefaultClusterSet
    end
  end

  def self.clusters
    WAKE_CLUSTERS
  end

  def self.get(name)
    if clusters.key?(name)
      new(name)
    end
  end

  class AzureClusterInfo
    attr_accessor :resource_group, :storage_account, :vnet, :subnet, :vmi_uri

    def initialize(cluster)
      @cluster = cluster
    end

    def azure
      @cluster.require("azure")
    end

    def location
      azure.require("location")
    end

    def default_size
      azure.require("default_size")
    end

    def default_host_image_uri
      if azure["default_host_image_uri"]
        URI(azure["default_host_image_uri"])
      end
    end

    def self.get(m, &blk)
      ivar_name = :"@#{m}"
      string_name = m.to_s

      define_method(:"#{m}?") do
        !!azure[string_name]
      end

      define_method(m) do
        instance_variable_get(ivar_name) || instance_exec(&blk).tap do |result|
          instance_variable_set(ivar_name, result)
        end
      end
    end

    get :resource_group do
      Azure::ResourceGroup.new(subscription: Azure.subscription,
                               name: azure.require("resource_group"),
                               location: location)
    end

    get :storage_account do
      Azure::StorageAccount.new(resource_group: resource_group,
                                name: azure.require("storage_account"))
    end

    get :vnet do
      Azure::Vnet.new(resource_group: resource_group,
                      name: azure.require("vnet"))
    end

    get :subnet do
      Azure::Subnet.new(vnet: vnet, name: azure.require("subnet"))
    end
  end

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def full_key(key)
    "#{name}.#{key}"
  end

  def inspect
    "#<#{self.class.name} {#{name.inspect}}>"
  end

  def [](key)
    self.class.clusters[full_key(key)]
  end

  def require(key)
    self.class.clusters.require(full_key(key))
  end

  def update(key, value)
    self.class.clusters.update(full_key(key), value)
    @azure = nil
    persist
  end

  def to_hash
    self.class.clusters[name].merge("name" => name)
  end

  def azure
    @azure ||= AzureClusterInfo.new(self)
  end

  def iaas
    self["iaas"]
  end

  def dns_zone
    self["dns_zone"]
  end

  def collaborators
    self["collaborators"] || []
  end

  def delete
    self.class.clusters.delete(name)
    persist
  end

  def persist
    self.class.clusters.persist
  end
end
