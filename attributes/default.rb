default['archipel']['xmpp_server'] = nil # MUST be SET
default['archipel']['hypervisor_name'] = node['hostname']
default['archipel']['ip'] = node['ipaddress']
#default['archipel']['hypervisor_password']
#default['archipel']['uuid']

case node["platform"]
when "ubuntu"
	if node[:platform_version].to_f >= 9.10
		default['archipel']['init'] = "upstart"
	else
		default['archipel']['init'] = "init"
	end
else
	default['archipel']['init'] = "init"
end
