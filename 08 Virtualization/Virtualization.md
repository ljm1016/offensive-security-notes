#virtualization
- Virtualization - allows multiple applications to be run on the same physical server safely
- Hypervisor - the software that actually allows virtual hosts to behave independently as it provides the sharing of resources, isolation, and the lifecycle of the VMs
	- Type 1 - runs directly on the physical hardware which is fast and efficient
	- Type 2 - run on an existing OS which is easiest to install/manage (using something like virtualbox)
- Container - the isolated environment that runs a single application and the necessary components to support it and borrows the existing system by running on the kernel so it can actually share resources - they also must match the OS types due to the shared kernel
	- Easiest way to deploy them is thru docker


- No notes on this yet but there are different exploits out there for virtualization architecture whther its docker, esxi hosts, etc