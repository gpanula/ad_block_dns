# Build the docker image

```bash
docker build -t ad_block_dns .
```

# Create container from it

```bash
docker create --name=ad_block_dns -v /host/path/to/named/chroot:/var/named/chroot --restart unless-stopped -p 53:53/udp -p 53:53 ad_block_dns
```

# Start the container

```bash
docker start ad_block_dns
```

