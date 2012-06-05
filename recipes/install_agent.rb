include_recipe "build-essential"
include_recipe "python::package"

packages = value_for_platform(
	["ubuntu"] => {
		"default" => ["python-numpy", "python-libvirt"]
	},
	"default" => ["python-numpy"]
)


packages.each do |pkg|
	package pkg do
		action :install
	end
end

package "archipel-agent" do
	provider Chef::Provider::Package::EasyInstall
	action :install
end

directories = %w{
	/var/lib/archipel/
	/etc/archipel/
	/vm/
}

directories.each do |dir|
	directory dir do
		owner "root"
		group "root"
		mode "0755"
		action :create
	end
end

remote_directory "/var/lib/archipel/avatars" do
	source "avatars"
	files_backup false
end

cookbook_file "/var/lib/archipel/names.txt" do
	source "names.txt"
	backup false
end

#python_pip "archipel-agent" do
#	action :install
#end

case node[:platform]
when "ubuntu"
	apt_package "ruby-uuidtools"
else
	chef_gem "uuidtools"
end

ruby_block "generate uuid" do
		block do
			require 'uuidtools'
			uuid = UUIDTools::UUID.random_create
			node['archipel']['uuid'] = uuid
			node.save
		end
		# TODO generate with specif BITS
#		notifies(:reload, "service[tinc]")
		not_if { node['archipel'].has_key?('uuid') }
end

ruby_block "generate password" do
	block do
		pass = (0...8).map{(65+rand(25)).chr}.join
		node['archipel']['hypervisor_password'] = pass
		node.save
	end
	not_if { node['archipel'].has_key?('hypervisor_password') }
end

template "/etc/archipel/archipel.conf" do
	source "archipel.conf.erb"
	variables(
		'xmpp_server' => node['archipel']['xmpp_server'],
		'uuid' => node['archipel']['uuid'],
		'hypervisor_name' => node['archipel']['hypervisor_name'],
		'hypervisor_password' => node['archipel']['hypervisor_password']
	)
end

# Sercvice installation
case node['archipel']['init']
when "init"

	template "/etc/init.d/archipel" do
		source "init_archipel.erb"
		mode "0755"
	end

	service "archipel" do
		action [:enable, :start]
	end

when "upstart"
	template "/etc/init/archipel.conf" do
		source "upstart_archipel.conf.erb"
	end

	service "archipel" do
		provider Chef::Provider::Service::Upstart
		action [:enable, :start]
	end
end
