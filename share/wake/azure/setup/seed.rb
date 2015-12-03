require 'erb'
require 'tmpdir'
require 'resolv'
require 'yaml'
require_relative '../ssh'
require_relative '../scp'
require_relative '../provisioning_state_poller'

module Azure
  module Setup
    class Seed
      include Dockerable

      compose :statsite

      attr_reader :cluster, :ip, :vm, :docker_user

      def initialize(cluster:, ip:, vm:, docker_user:)
        @cluster     = cluster
        @ip          = ip
        @vm          = vm
        @docker_user = docker_user
      end

      def fetch_public_key(name)
        uri = URI("https://github.com/#{name}.keys")
        keys = Net::HTTP.get(uri).chomp
      end

      def fetch_collaborators
        cluster.collaborators.map do |c|
          [c, fetch_public_key(c)]
        end
      end

      def setup_sh_template
        File.read(File.expand_path("../setup.sh.erb", __FILE__))
      end

      def render_setup_sh
        ERB.new(setup_sh_template).result(binding)
      end

      def render_and_copy_setup_sh
        Dir.mktmpdir do |tmpdir|
          Wake.log [:tmpdir, tmpdir]

          Dir.chdir(tmpdir) do
            File.open("setup.sh", "w") do |f|
              f << render_setup_sh
            end
            SCP.call(ip: ip, local_path: "setup.sh")
          end
        end
      end

      def dns_zone
        Azure::DNSZone.new(resource_group: cluster.azure.resource_group, name: cluster.require("dns_zone"))
      end

      def ns_server_ips
        result   = Azure.resources.dns_zones.record_sets!(dns_zone)
        body     = result.response.parsed_body
        ns_set   = body["value"].find { |s| s["id"] =~ %r{NS/@$} }
        ns_hosts = ns_set["properties"]["NSRecords"].flat_map(&:values)

        ns_hosts.map { |s| Resolv.getaddress(s) }
      end

      def dnsmasq_conf_template
        File.read(File.expand_path("../dnsmasq.conf.erb", __FILE__))
      end

      def render_dnsmasq_conf
        ERB.new(dnsmasq_conf_template).result(binding)
      end

      def render_and_copy_dnsmasq_conf
        Dir.mktmpdir do |tmpdir|
          Wake.log [:tmpdir, tmpdir]

          Dir.chdir(tmpdir) do
            File.open("dnsmasq.conf", "w") do |f|
              f << render_dnsmasq_conf
            end
            SCP.call(ip: ip, local_path: "dnsmasq.conf")
          end
        end
      end

      def local_sshd_config_path
        File.expand_path("../sshd_config", __FILE__)
      end

      def copy_docker_conf
        docker_conf_path = File.expand_path("../docker.conf", __FILE__)
        SCP.call(ip: ip, local_path: docker_conf_path)
      end

      def call
        SCP.call(ip: ip, local_path: local_sshd_config_path)

        copy_docker_conf
        write_and_copy_compose
        render_and_copy_dnsmasq_conf

        render_and_copy_setup_sh
        SSH.call(ip: ip, command: "sudo chmod +x setup.sh && sudo ./setup.sh && rm setup.sh")
      end
    end
  end
end
