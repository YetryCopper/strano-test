require 'aws/ec2'

set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "strano-test"
set :repository,  "."
set :scm, :none

set :user, "ubuntu"
set :deploy_via, :copy
set :deploy_to, "/home/ubuntu/strano-test"
set :use_sudo, false

region = 'us-east-1'
image = 'ami-2b663142'
instance_type = 't1.micro'
key = 'strano'
security_group = 'dm4'
tag = 'strano-test'

task :create_vm do
  init_aws
  ec2 = AWS::EC2.new(:region => region)
  instance = ec2.instances.create( 
                                  :image_id => image,
                                  :instance_type => instance_type,
                                  :count => 1, 
                                  :key_pair => ec2.key_pairs[key],
                                  :security_groups => security_group)

  logger.debug("Waiting vm to initialize")
  while instance.status == :pending
    sleep(1)
  end
  logger.debug("Vm initialized")

  instance.tag(tag)
  logger.debug("Tagged vm as '#{tag}'")

  server instance.dns_name, :app, :web, :db, :primary => true

  wait_for_ssh(instance,ssh_options[:keys][0])
  deploy.setup
  install(instance)
end

task :destroy_vm do
  init_aws
  ec2 = AWS::EC2.new(:region => region)
  instances = ec2.instances.tagged(tag)
  instances.each{|instance| 
    instance.stop
  }
end

task :create_file do
  run_locally("touch /tmp/local")
end

task :delete_file do
  run_locally("rm /tmp/local")
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end

  task :finalize_update do ; end
  task :migrate         do ; end

  task :restart do ; end
end

def install(instance)
  server instance.dns_name, :app, :web, :db, :primary => true  
  
  deploy.cold
  
  sudo "aptitude update -y"
  sudo "apt-get install python-pip python-dev build-essential -y"
  sudo "pip install --upgrade pip"
  sudo "pip install web.py"
  sudo "cp #{current_path}/scripts/server_py /etc/init.d/server_py"
  sudo "chmod +x /etc/init.d/server_py"
  sudo "update-rc.d server_py defaults"
  sudo "chmod +x #{current_path}/web/server.py"
  sudo "/etc/init.d/server_py start"
end


def init_aws
  AWS.config(YAML.load_file("config/aws.yml"))
end

def wait_for_ssh(instance, key_file)
    logger.debug "Wait for it to boot"

    accessible_trough_ssh = proc do
      begin
        Timeout::timeout(5) do
        run_locally("ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i #{key_file} ubuntu@#{instance.dns_name} true")
        end
      rescue
        false
      end
    end

  while !accessible_trough_ssh.call
    sleep(5)
  end
end
