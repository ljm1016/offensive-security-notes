
#### Armitage:
Armitage is a GUI for Metasploit

Setup:
1. `root@kali$ git clone https://gitlab.com/kalilinux/packages/armitage.git && cd armitage`
2. Next up, we must build the current release; we can do so with the following command:
	1. `root@kali$ bash package.sh`
	2. After the building process finishes, the release build will be in the `./releases/unix/` folder.  You should check and verify that Armitage was able to be built successfully.
	3. In this folder, there are two key files that we will be using:
		1. **Teamserver**
		2. This is the file that will start the Armitage server that multiple users will be able to connect to. This file takes two arguments:
			1. IP Address
			- Your fellow Red Team Operators will use the IP Address to connect to your Armitage server.
			1. Shared Password
			- Your fellow Red Team Operators will use the Shared Password to access your Armitage server.
3. start and initialize the database before launching Armitage. In order to do so, we must execute the following commands:
	1. `systemctl start postgresql && systemctl status postgresql`
	2. Then set the `MSF_DATABASE_CONFIG` environment variable to the location of your Metasploit **database.yml** file, which in our case is at `/root/.msf4/database.yml`:
	3. `export MSF_DATABASE_CONFIG=/root/.msf4/database.yml`
4. After that, we can finally start the Armitage Team Server:
	- `cd /opt/armitage/release/unix && ./teamserver YourIP P@ssw0rd123`
5. Start the Client: `cd /opt/armitage/release/unix && ./armitage`
6. For operators to gain access to the server, you should create a new user account for them and enable SSH access on the server, and they will be able to SSH port forward TCP/55553.  Armitage **explicitly denies** users listening on 127.0.0.1