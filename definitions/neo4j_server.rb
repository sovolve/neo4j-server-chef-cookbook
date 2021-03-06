#
# Cookbook Name:: neo4j-multi-server
# Recipe:: tarball
# Copyright 2013, Alex Willemsma <alex@sovovle.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

define :neo4j_server, instance_name: 'main', port: '4747', action: 'install' do
  # TODO: Implement more actions.
  raise "Only action supported is 'install'. You passed #{params[:action]}" unless params[:action] == 'install'

  include_recipe "java"
  package 'unzip'
  package 'lsof' # Required to launch the neo4j service

  # set paths for this instance:
  install_dir = "#{node.neo4j.server.base_installation_dir}/#{params[:instance_name]}"
  lib_dir = "#{node.neo4j.server.base_lib_dir}/#{params[:instance_name]}"
  run_dir = node.neo4j.server.run_dir
  data_dir = "#{install_dir}#{node.neo4j.server.data_dir}"
  conf_dir = "#{install_dir}#{node.neo4j.server.conf_dir}"
  lock_path = "#{run_dir}/#{node.neo4j.server.base_name}-#{params[:instance_name]}.lock"
  pid_path = "#{run_dir}/#{node.neo4j.server.base_name}-#{params[:instance_name]}.pid"
  user_name = "#{node.neo4j.server.base_name}-#{params[:instance_name]}"

  #
  # User accounts
  #

  user user_name do
    comment "Neo4J Server user"
    home    install_dir
    shell   "/bin/bash"
    action  :create
  end

  group user_name do
    (m = []) << user_name
    members m
    action :create
  end

  [install_dir, lib_dir, run_dir].each do |dir|
    directory dir do
      owner user_name
      group user_name
      recursive true
      action    :create
    end
  end

  # 1. Download the tarball to /tmp
  require "tmpdir"

  td          = Dir.tmpdir
  tmp         = File.join(td, "neo4j-community-#{node.neo4j.server.version}.tar.gz")
  tmp_spatial = File.join(td, "neo4j-spatial-#{node.neo4j.server.plugins.spatial.version}-server-plugin.zip")

  remote_file(tmp) do
    source node.neo4j.server.tarball.url

    not_if "which neo4j-#{params[:instance_name]}"
  end

  if node.neo4j.server.plugins.spatial.enabled
    remote_file(tmp_spatial) do
      source node.neo4j.server.plugins.spatial.url
      not_if "test -f {install_dir}/plugins/neo4j-spatial-#{node.neo4j.server.plugins.spatial.version}.jar"
    end
  end

  # 2. Extract it
  # 3. Copy to /usr/local/neo4j-server, update permissions
  bash "extract #{tmp}, move it to #{install_dir}" do
    user "root"
    cwd  "/tmp"

    code <<-EOS
      rm -rf #{install_dir}
      tar xfz #{tmp}
      mv --force `tar -tf #{tmp} | head -n 1 | cut -d/ -f 1` #{install_dir}
    EOS

    creates "#{install_dir}/bin/neo4j"
  end

  if node.neo4j.server.plugins.spatial.enabled
    bash "extract #{tmp_spatial}, move it to #{install_dir}/plugins" do
      user "root"
      cwd "/tmp"

      code <<-EOS
        unzip #{tmp_spatial} -d #{install_dir}/plugins
      EOS

      creates "#{install_dir}/plugins/neo4j-spatial-#{node.neo4j.server.plugins.spatial.version}.jar"
    end
  end

  [conf_dir, data_dir, File.join(data_dir, "log")].each do |dir|
    directory dir do
      owner     user_name
      group     user_name
      recursive true
      action    :create
    end
  end

  [lib_dir,
   data_dir,
   File.join(install_dir, "data"),
   File.join(install_dir, "system"),
   File.join(install_dir, "plugins"),
   install_dir].each do |dir|
    # Chef sets permissions only to leaf nodes, so we have to use a Bash script. MK.
    bash "chown -R #{user_name}:#{user_name} #{dir}" do
      user "root"

      code "chown -R #{user_name}:#{user_name} #{dir}"
    end
  end

  # 4. Symlink
  %w(neo4j neo4j-shell).each do |f|
    link "/usr/local/bin/#{f}-#{params[:instance_name]}" do
      owner user_name
      group user_name
      to    "#{install_dir}/bin/#{f}"
    end
  end

  # 5. init.d Service
  template "/etc/init.d/neo4j-#{params[:instance_name]}" do
    cookbook "neo4j-multi-server"
    source "neo4j.init.erb"
    owner 'root'
    mode  0755
    variables ({
      install_dir: install_dir,
      instance_name: params[:instance_name],
    })
  end

  # 6. Install config files
  template "#{conf_dir}/neo4j-server.properties" do
    cookbook "neo4j-multi-server"
    source "neo4j-server.properties.erb"
    owner user_name
    mode  0644
    notifies :restart, "service[neo4j-#{params[:instance_name]}]"
    variables ({
      port: params[:port],
      data_dir: data_dir,
      conf_dir: conf_dir,
    })
  end

  template "#{conf_dir}/neo4j-wrapper.conf" do
    cookbook "neo4j-multi-server"
    source "neo4j-wrapper.conf.erb"
    owner user_name
    mode  0644
    notifies :restart, "service[neo4j-#{params[:instance_name]}]"
    variables ({
      conf_dir: conf_dir,
      pid_path: pid_path,
      lock_path: lock_path,
      instance_name: params[:instance_name],
      user_name: user_name,
    })

  end

  template "#{conf_dir}/neo4j.properties" do
    cookbook "neo4j-multi-server"
    source "neo4j.properties.erb"
    owner user_name
    mode 0644
    notifies :restart, "service[neo4j-#{params[:instance_name]}]"
    variables ({
      install_dir: install_dir,
      instance_name: params[:instance_name],
    })
  end

  # 7. Know Your Limits
  # NOTE: This will over-ride with the last instance's settings. To use different
  # settings for different instances, use different user_names for each.
  template "/etc/security/limits.d/#{user_name}.conf" do
    cookbook "neo4j-multi-server"
    source "neo4j-limits.conf.erb"
    owner user_name
    mode  0644
    notifies :restart, "service[neo4j-#{params[:instance_name]}]"
    variables ({
      user_name: user_name,
    })
  end

  ruby_block "make sure pam_limits.so is required" do
    block do
      fe = Chef::Util::FileEdit.new("/etc/pam.d/su")
      fe.search_file_replace_line(/# session    required   pam_limits.so/, "session    required   pam_limits.so")
      fe.write_file
    end
    notifies :restart, "service[neo4j-#{params[:instance_name]}]"
  end

  service "neo4j-#{params[:instance_name]}" do
    supports :start => true, :stop => true, :restart => true
    if node.neo4j.server.enabled
      action [:restart, :enable] # It's important we start and enable the service here, so that it's up for other things that may use it (such as our app's migrations).
    else
      action :disable
    end
    subscribes :restart, "template[/etc/init.d/neo4j-#{params[:instance_name]}]"
  end
end
