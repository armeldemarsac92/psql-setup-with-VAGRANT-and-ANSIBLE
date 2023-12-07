# Setting Up PostgreSQL with Vagrant and Ansible

This project provides a setup for PostgreSQL using Vagrant and Ansible. Follow the instructions below to clone the repository and set up your environment.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Git**: To clone the repository.
- **Vagrant**: For creating and managing virtual development environments.
- **VirtualBox**: As a provider for Vagrant.
- **Ansible**: For automated configuration management.

## Installation Steps

### 1. Install Git

- **Windows**: Download and install from [Git for Windows](https://gitforwindows.org/).
- **macOS**: Install using Homebrew with `brew install git`, or download from [Git for macOS](https://git-scm.com/download/mac).
- **Linux (Ubuntu/Debian)**: Install using `sudo apt-get install git`.

### 2. Install VirtualBox

Download and install VirtualBox from [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads).

### 3. Install Vagrant

Download and install Vagrant from [Vagrant Downloads](https://www.vagrantup.com/downloads).

### 4. Install Ansible

- **macOS/Linux**:
  - Install using Homebrew (macOS) with `brew install ansible`, or
  - For Linux, use `sudo apt-get install ansible` (Ubuntu/Debian).
- **Windows**: Windows support is more complex, see [Installing Ansible on Windows](https://docs.ansible.com/ansible/latest/user_guide/windows_faq.html) for details.

## Cloning the Repository

Run the following command to clone the repository:

```bash
git clone https://github.com/armeldemarsac92/psql-setup-with-VAGRANT-and-ANSIBLE.git
cd psql-setup-with-VAGRANT-and-ANSIBLE
```


# PostgreSQL 13 Master-Standby Streaming Replication

PostgreSQL has various types of replication available and it could be a little bit confusing to figure out what has to be done to just configure a simple master-standby replicated database setup. 
Digging my way through documentation I decided to write my own little guide on how to setup simple replication in PostgreSQL 13. 

### How it works
Streaming replication works by streaming the contents of WAL (Write-Ahead Logging) file from one server to another. Each transaction is first written into the WAL file, so essentially every change on the primary server will be replicated on the standby server. Standby server could be used for read-only operations, but can't be written to. 
Ofcourse, transferring data over the network takes time and there is a small lag before data written to one server becomes available on the other. To guarrantee data consistency on both servers at the time of read operation we can enable synchronous replication mode. This way, database client will receive 'commit successfull' message only after data is written to both primary and standby server, though at the cost of slightly increased write times.

### Starting point
Configuration below was tested on 2 FreeBSD 13 VMs with PostgreSQL 13 installed. It should work fine on any Linux distro, the only thing that's changing between the two being PGDATA (Postgres installation directory) path.

### Walkthrough
First, we will configure primary server with all of the configuration options required for enabling replication and then perform initial one-time synchronization of PostgreSQL data and configuration to the standby server using pg_basebackup command.
Before starting, make sure that your firewall doesn't block port TCP/5432.

##### Configuring primary server
Switch to postgres user

`sudo -i postgres` or `su postgres`

Create user for replication purposes with replication role assigned

```createuser repluser -P --replication```

Create replication slot (see description below)
As a postgres user
```
psql
SELECT * FROM pg_create_physical_replication_slot('repl_slot');`
```
Edit postgresql.conf, change the following lines
```
listen_addresses = '*'
max_wal_senders = 10
wal_level = replica
wal_log_hints = on
#wal_keep_size = 512
max_replication_slots = 10
hot_standby = on 

primary_conninfo = 'user=repluser host=[primary_ip] port=5432 sslmode=prefer sslcompression=1'
primary_slot_name = 'repl_slot'

#synchronous_commit = on
#synchronous_standby_names = '*'
```

`listen_addresses` - here we allow postgresql to listen on all of the network addresses on the server, so that the standby server could access it.

`max_wal_senders` - wal_sender processes are required to stream WAL data to standby server. 10 is the default value and should be enough for most applications.

`wal_level` - sets the level of data written to WAL, replica ensures that data written to WAL will be sufficient for replication purposes.

`wal_keep_size` - specified in MB, defines maximum size of WAL files kept for replication to standby. In the event of standby server going off-grid for some time, keeping larger amounts of WAL data will help standby server to get in-sync with primary. If WAL data reaches size limit and removed before standby server comes online, standby server will be out-of-sync and will need to be restored from base backup once again. Basically useless after replication slots introduction (that's why it is commented), but still figured it would be good to know about.

`max_replication_slots` - replication slots were introduced in PostgreSQL 9.4 and is used to retain the WAL files even when the standby is offline. Prior to that, we could only increase `wal_keep_size` parameter in hopes that we wouldn't run into the limit before standby goes online. With replication slots, the primary server can keep the WAL file for indefinitely long time if standby didn't sync it yet.

Following configuration options will be ignored by primary server, but we nevertheless keep it, as we will copy the config to the standby server:

`hot_standby` - allows performing read-only operations on the standby server.

`primary_conninfo` - standby server will use this connection string to connect to primary server.

`primary_slot_name` - replication slot name to be used.

Allow replication connections in pg_hba.conf. Append the following to the end of pg_hba.conf.

`host	replication		repluser	[standby-ip]/32		md5`

This line allows standby server access from repluser from specified IP address using password.

Restart PostgreSQL service

`service postgresql restart` or `systemctl restart postgresql`

Name of the service could be different depending on the OS.

##### Configuring standby server
Stop PostgreSQL service

`service postgresql stop` or `systemctl stop postgresql`

Remove everything from postgres data directory (PGDATA). By default it is the home directory of postgres user. In FreeBSD it's /var/db/postgres.

`rm -rf /var/db/postgres/*`

Get base backup from primary server and restore it on the standby server. This will provide initial DB sync.
As postgres user:

`pg_basebackup -h [primary IP] -D [postgres_data_directory] -U repluser -v -P -R -X stream -c fast`

Enter the password for repluser and all of the data from primary postgres installation, including config files will be transferred to the standby server.

Create signal file to let current PostgreSQL instance know that it should work in standby mode:

`touch [postgresql_data_directory]/standby.signal`

Start PostgreSQL service

`service postgresql start` or `systemctl start postgresql`

You should see from the output that it started to work in standby mode.

##### Testing configuration
If everything is fine, you should see wal_sender processes working on primary and wal_receiver processes working on standby server

On primary:

`ps aux | grep walsender`

You should see output similar to this:

```
postgres 22372   0.0  0.3 177344 27648  -  Ss   Tue17        0:01.47 postgres: walsender repluser [ip]:(port)  (postgres)
```

On standby:

`ps aux | grep walreceiver`

You should see output similar to this:

```
postgres 11752   0.0  0.3 177704 25364  -  Ss   Tue17       1:25.57 postgres: walreceiver  (postgres)
```

Additionally, check if replication works by creating some tables or databases and ensuring that they exist on both of the servers.

These two commands could also be useful as they show replication metrics:

```
select * from pg_stat_replication;
select * from pg_stat_wal_receiver;
```


### Failover

Failover in case of primary server shutdown is manual. To make standby server primary:

`pg_ctl _promote`

If you wanted automated failover, you should dig much deeper, thinking about escaping split-brain situations, setting up fencing mechanisms and witness servers.

### P.S.
Please, note that I've described the most simplified configuration that should be ok for most of the use cases. Check the documentation for configuration options that you may wish to tweak.

If you see some errors or want to suggest an improvement, please don't hesitate to contact me.

### Links:
What is WAL - https://www.postgresql.org/docs/13.0/wal-intro.html

Streaming Replication - https://www.postgresql.org/docs/13/warm-standby.html#STREAMING-REPLICATION

Replication Slots - https://hevodata.com/learn/postgresql-replication-slots/
