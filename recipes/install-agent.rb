include_recipe "build-essential"
include_recipe "python"

packages = value_for_platform(
	["ubuntu"] => {
		"default" => ["python-numpy"]
	},
	"default" => ["python-numpy"]
)


packages.each do |pkg|
	package pkg do
		action :install
	end
end

package "archipel-agent" do
	action :install
	provider Chef::Provider::Package::EasyInstall
end
