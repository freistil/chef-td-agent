#
# Cookbook Name:: td-agent
# Recipe:: configure
#
#

Chef::Recipe.send(:include, TdAgent::Version)
Chef::Provider.send(:include, TdAgent::Version)

reload_action = (reload_available?) ? :reload : :restart

major_version = major

# To force the user/group into the init script
template '/etc/init.d/td-agent' do
  source 'td-agent.init.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables(
    :user => node["td_agent"]["user"],
    :group => node["td_agent"]["group"]
  )
  notifies :restart, "service[td-agent]", :delayed
end
# ToDO: Do the right systemd-thing

template "/etc/td-agent/td-agent.conf" do
  owner  node["td_agent"]["user"]
  group  node["td_agent"]["group"]
  mode "0644"
  cookbook node['td_agent']['template_cookbook']
  source "td-agent.conf.erb"
  variables(
    :major_version => major_version
  )
  notifies reload_action, "service[td-agent]", :delayed
end

node["td_agent"]["plugins"].each do |plugin|
  if plugin.is_a?(Hash)
    plugin_name, plugin_attributes = plugin.first
    td_agent_gem plugin_name do
      plugin true
      %w{action version source options gem_binary}.each do |attr|
        send(attr, plugin_attributes[attr]) if plugin_attributes[attr]
      end
      notifies :restart, "service[td-agent]", :delayed
    end
  elsif plugin.is_a?(String)
    td_agent_gem plugin do
      plugin true
      notifies :restart, "service[td-agent]", :delayed
    end
  end
end

service "td-agent" do
  supports :restart => true, :reload => (reload_action == :reload), :status => true
  restart_command "/etc/init.d/td-agent restart || /etc/init.d/td-agent start"
  action [ :enable, :start ]
end

##### /var/log/td-agent
##### /var/log/td-agent/buffer
