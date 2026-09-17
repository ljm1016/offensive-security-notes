#networking 

- OSI Model is the framework for dictating how all devices will send receive and interpret data and consists of 7 layers - each layer is has a different responsibility
	1. Physical - refers to the physical components of hardware used within networking (ex. ethernet cables)
	2. Data Link - focuses on the physical addressing of transmissions. retrieves a packer from the network layer and adds in a physical MAC address which is inside the NIC (Network Interface Card)
	3. Network - routing finds the most optimal path in which packets should be sent 
		- Packets are members of this layer and have the following characteristics:
			- TTL
			- Checksum
			- Source address
			- IP address
	4. Transport - how data is being send and through what protocol
		- TCP - transmission control protocol which is the most reliable delivery method - three way handshake
		- UDP - user datagram protocol which has no error checking but it is faster
	5. Session - once data has been transferred, session maintains the connection to the other computer and remains active
	6. Presentation - acts as a translator in which data is understood for the application layer and for the session layer
	7. Application - the actual program being run which a gui is presented for