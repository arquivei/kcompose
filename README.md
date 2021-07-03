# kcompose
Utility tool for managing kafka

## Instalation

### Arch Based Distros
This package is distributed on the AUR repository. Simply run:
```
yay -S kcompose
```

### Debian Based Distros
Download the `.deb` installer on https://github.com/andremissaglia/kcompose/releases/latest

## Getting Started

Run `kcompose setup` to set up the connection variables. Try `kcompose topic list` to see if it worked.


## Usage

### Topics
```bash
# To list all topics
kcompose topic list

# To describe a topic
kcompose topic describe TOPIC

# To remove a topic
kcompose topic remove TOPIC

# To create a topic (`--replication-factor` and `--partitions` are mandatory)
kcompose topic create TOPIC [OPTIONS]
# example:
kcompose topic create TOPIC --replication-factor 1 --partitions 1
```

### Production
```bash
# To produce in a topic
kcompose produce TOPIC
```

### Consumption
```bash
# To consume from a a topic
kcompose consume TOPIC
```

### Groups
```bash
# To list all groups
kcompose group list

# To describe a group
kcompose group describe GROUP

# To remove a group
kcompose group remove GROUP

# To reset offsets in a group
kcompose group reset GROUP [OPTIONS]
# examples
kcompose group reset GROUP --topic TOPIC --to-earliest --execute
kcompose group reset GROUP --topic TOPIC --to-offset 15 --execute
kcompose group reset GROUP --topic TOPIC --to-datetime "2018-07-01T15:29:54.134" --execute
```

### Authorization
```bash
# To list all ACL rules
kcompose acl list

# To allow a user some rule
kcompose acl user USER allow --add [RULE]

# To deny a user some rule
kcompose acl user USER deny -add [RULE]

# To remove an "allow" rule
kcompose acl user USER allow --remove [RULE]

# Examples:
kcompose acl user USER allow --add --producer --topic '*'
kcompose acl user USER allow --add --consumer --topic TOPIC --group '*'
```

### Etc

```bash
# To show current kcompose variables
kcompose env
```

## Changelog

### 0.9.2

 - \[Bug\] Fix --consumer.config when authentication method is set to NONE

### 0.9.1

 - \[Bug\] Fix --command-config when authentication method is set to NONE

### 0.9.0

 - Add additional ACL listing commands

### 0.8.1

 - \[Bug\] Fix problem in `kcompose topic alter`: 

### 0.8.0

 - Updated kafka to 2.7.0
 - Improved DevEx printing the usage when the command is wrong
 - Reformated code with shfmt
