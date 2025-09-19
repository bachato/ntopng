# Debugging and Developing Traffic Recording

Working on traffic recording in ntopng can be tricky when it comes to debugging or adding new features.  
This is because Continuous Recording requires ntopng to run as a systemd service. 
In this mode, ntopng automatically configures and starts an n2disk (specifically, n2disk-ntopng)
service with a service dependency. As a result, the n2disk service may continuously restart during 
testing, making debugging difficult.  

To simplify development and debugging, it is recommended to run ntopng manually (in the foreground) 
while having access to Pro Lua scripts (otherwise compressed when running as a service) and traffic recording. 
This can be achieved by configuring an external Traffic Recording Provider, which removes the service 
dependency and allows n2disk to run independently as a service.  

## Workflow

### 1. Create an n2disk Configuration File

Example configuration file /etc/n2disk/n2disk-eno1.conf:

```bash
--interface=eno1
--dump-directory=/storage/n2disk/eno1/pcap
--timeline-dir=/storage/n2disk/eno1/timeline
--disk-limit=10%
--max-file-len=256
--buffer-len=1024
--index
--writer-cpu-affinity=0
--reader-cpu-affinity=1
--indexer-cpu-affinity=2
```

Always verify that the n2disk configuration matches your capture environment (interfaces, directories, disk limits).  

### 2. Start the n2disk Service

```bash
sudo systemctl restart n2disk@eno1
```

### 3. Configure the external Traffic Recording Provider in ntopng

With n2disk running as a service, configure ntopng to use it as external provider.  
In this setup:

- n2disk runs independently in the background.  
- ntopng can be launched manually in the foreground for easier debugging.  

Traffic Recording Provider configuration under Interface Details Settings:

<img width="1387" height="991" alt="external-provider" src="https://github.com/user-attachments/assets/135ef39f-ddf7-4d53-9577-9bfae35dc94f" />

The n2disk status should be now reported in the recording section:

<img width="1398" height="761" alt="status" src="https://github.com/user-attachments/assets/070c1a0d-42b6-4d5a-a094-29e569cc6af8" />

Extraction should become available from pages including the historical chart:

<img width="1394" height="957" alt="extraction" src="https://github.com/user-attachments/assets/92917511-e385-49ef-bc5c-b576d2ee0450" />


