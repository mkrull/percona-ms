if !File.exists? '/tmp/percona_installed'
    execute 'apt-get-update' do
        command 'apt-get update'
    end

    cookbook_file 'mysqlsampledatabase.sql' do
        source 'mysqlsampledatabase.sql'
        path '/tmp/mysqlsample.sql'
    end

    package 'python-software-properties' do
        action :install
    end

    execute 'add-percona-key' do
        command 'apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A'
    end

    execute 'add-apt-repository' do
        command 'apt-add-repository -y "deb http://repo.percona.com/apt precise main"'
    end

    execute 'apt-get-update' do
        command 'apt-get update'
    end

    package 'percona-server-5.5' do
        action :install
    end

    package 'percona-xtrabackup' do
        action :install
    end

    cookbook_file 'my.cnf' do
        source 'my.cnf'
        path '/etc/mysql/my.cnf'
    end

    execute 'restart mysql' do
        command '/etc/init.d/mysql restart'
    end

    execute 'create sample database' do
        command 'mysql < /tmp/mysqlsample.sql'
    end

    file '/tmp/percona_installed' do
        action :create
    end
end

case node.name
when 'master'
    directory '/root/.ssh' do
        owner 'root'
        group 'root'
        mode '0700'
        action :create
    end

    file 'id_rsa' do
        path '/root/.ssh/id_rsa'
        content node['priv_key']
        owner 'root'
        group 'root'
        mode '0600'
        action :create
    end

    file 'id_rsa.pub' do
        path '/root/.ssh/id_rsa.pub'
        content node['pub_key']
        owner 'root'
        group 'root'
        mode '0600'
        action :create
    end

    file 'known_hosts' do
        path '/root/.ssh/known_hosts'
        content node['known_hosts']
        owner 'root'
        group 'root'
        mode '0600'
        action :create
    end

    if !File.exists? '/tmp/replication_set_up'
        directory '/var/perconabak' do
            owner 'root'
            group 'root'
            mode '0700'
            action :create
        end

        execute 'run mysql backup' do
            command 'innobackupex /var/perconabak'
        end

        execute 'apply log' do
            # hacky glob
            command 'innobackupex --apply-log /var/perconabak/*/'
        end

        execute 'stop mysql on slave' do
            command "ssh root@#{node['slaveip']} '/etc/init.d/mysql stop'"
        end

        execute 'rsync backup to slave' do
            # hacky glob
            command "rsync -avpP -e ssh /var/perconabak/*/ root@#{node['slaveip']}:/var/lib/mysql/"
        end

        execute 'grant slave access' do
            command "mysql -e \"grant replication slave on *.* to '#{node['repluser']}'@'#{node['slaveip']}' identified by '#{node['replpass']}'\""
        end

        execute 'run slave setup' do
            command "ssh root@#{node['slaveip']} 'bash /tmp/setup_slave.sh'"
        end

        file '/tmp/replication_set_up' do
            action :create
        end
    end

when 'slave'
    directory '/root/.ssh' do
        owner 'root'
        group 'root'
        mode '0700'
        action :create
    end

    file 'authorized_keys' do
        path '/root/.ssh/authorized_keys'
        content node['pub_key']
        owner 'root'
        group 'root'
        mode '0600'
        action :create
    end

    template '/tmp/setup_slave.sh' do
        source 'setup_slave.sh.erb'
        mode 0600
        variables(
            :master => node['masterip'],
            :user => node['repluser'],
            :pass => node['replpass']
        )
        ignore_failure true
    end
end
