require_relative 'dockerable'
require_relative 'setupable'

module Azure
  module Setup
    class Agent
      include Dockerable
      include Setupable

      boot_images :statsite, :agent
      setup_sh_path "setup_consul.sh.erb"

      def call
        write_and_copy_operator_files
        run_setup
      end
    end
  end
end
