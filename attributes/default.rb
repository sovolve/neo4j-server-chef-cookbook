default[:neo4j][:server][:version]           = '1.9.4'

default[:neo4j][:server][:tarball][:url]     = "http://dist.neo4j.org/neo4j-community-#{node[:neo4j][:server][:version]}-unix.tar.gz"

default[:neo4j][:server][:jvm][:xms]         =  32
default[:neo4j][:server][:jvm][:xmx]         = 512
default[:neo4j][:server][:limits][:memlock]  = 'unlimited'
default[:neo4j][:server][:limits][:nofile]   = 48000

default[:neo4j][:server][:user]              = 'neo4j'

default[:neo4j][:server][:base_name]         = 'neo4j-server'
default[:neo4j][:server][:instance_name]     = 'main'

default[:neo4j][:server][:base_installation_dir] = "/usr/local/#{node[:neo4j][:server][:base_name]}"
default[:neo4j][:server][:base_lib_dir]           = "/var/lib/#{node[:neo4j][:server][:base_name]}"
default[:neo4j][:server][:run_dir]           = "/var/run/#{node[:neo4j][:server][:base_name]}"

# Will be relative to base_install_dir/instance_name
default[:neo4j][:server][:data_dir]          = "/data/graph.db"
default[:neo4j][:server][:conf_dir]          = "/conf"

default[:neo4j][:server][:enabled]           = true

default[:neo4j][:server][:http][:host]       = '0.0.0.0'
default[:neo4j][:server][:http][:port]       = 7474
default[:neo4j][:server][:https][:enabled]   = true

default[:neo4j][:server][:plugins][:spatial][:enabled]  = true
default[:neo4j][:server][:plugins][:spatial][:version]  = '0.9-SNAPSHOT'
default[:neo4j][:server][:plugins][:spatial][:url]      = "https://github.com/downloads/goodwink/neo4j-server-chef-cookbook/neo4j-spatial-#{node[:neo4j][:server][:plugins][:spatial][:version]}-server-plugin.zip"

default[:neo4j][:server][:node_auto_indexing][:enabled]         = false
default[:neo4j][:server][:node_auto_indexing][:keys_indexable]  = ''

default['java']['oracle']['accept_oracle_download_terms'] = true
default['java']['install_flavor'] = 'oracle'
default['java']['jdk_version'] = '7'
