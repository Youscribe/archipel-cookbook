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

if node['chef_packages']['chef']['version'] <= "10.14.4" #CHEF-2320
  bash "install archipel-agent" do
    code "easy_install archipel-agent"
  end
else
  package "archipel-agent" do
    provider Chef::Provider::Package::EasyInstall
    action :install
  end
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
	not_if { node['archipel'].has_key?('uuid') }
	notifies(:restart, "service[archipel]")
end

ruby_block "generate password" do
	block do
		pass = (0...8).map{(65+rand(25)).chr}.join
		node['archipel']['hypervisor_password'] = pass
		node.save
	end
	not_if { node['archipel'].has_key?('hypervisor_password') }
	notifies(:restart, "service[archipel]")
end

ruby_block "generate key" do
	block do
		require 'openssl'
		rsa_key = OpenSSL::PKey::RSA.new 4096
		cert = OpenSSL::X509::Certificate.new
		cert.version = 2
		cert.serial = 1
		#OpenSSL::X509::Name.parse("/C=FR/ST=Ile-De-France/L=Paris/O=Youscribe/OU=IT/CN=youscribe.com/emailAddress=guilhem.lettron@youscribe.com")
		#cert.subject = ca
		#cert.issuer = ca
		cert.public_key = rsa_key.public_key
		cert.not_before = Time.now
		cert.not_after = Time.now + 2 * 365 * 24 * 60 * 60 # 2 years validity
		File.open("/etc/archipel/vnc.pem", "w") { |f| f.chmod(0600); f.write(rsa_key.to_pem + cert.to_pem) }
		node['archipel']['vnc_cert_expire'] = cert.not_after.to_i
		node.save
	end
	not_if { node['archipel'].has_key?('vnc_cert_expire') and Time.now < Time.at(node['archipel']['vnc_cert_expire']) }
	notifies(:restart, "service[archipel]")
end


template "/etc/archipel/archipel.conf" do
	source "archipel.conf.erb"
	variables(
		'xmpp_server' => node['archipel']['xmpp_server'],
		'uuid' => node['archipel']['uuid'],
		'hypervisor_name' => node['archipel']['hypervisor_name'],
		'hypervisor_password' => node['archipel']['hypervisor_password'],
		'ip' => node['archipel']['ipaddress']
	)
	notifies(:restart, "service[archipel]")
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
