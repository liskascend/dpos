# Run script
```
./DPOS --group Elite --account 2797084409072178585L
```

Before running you need to start lisk docker (read below) so the script is able to fetch real-time data from lisk database.   
The script takes in account:

- Delegate share perc. and upgrades,
- Voter's balance
- Number of voters for the delegate (more voters less each of them gets)

# DPOS

### Start Lisk
```
make up
```

### Rebuild database from snapshot

```
make coldstart
```

### Check status
```
http://localhost:8000/api/node/status

```

### Stop Lisk

```
docker-compose down
```

### Restart Lisk
```
docker-compose up
```

# Resources

https://github.com/vekexasia/dpos-tools-data