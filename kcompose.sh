#!/bin/bash
# Copyright (C) 2018  André Missaglia<andre.missaglia@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -f # Disables Globbing
defaultConfigFile=$HOME/.kcompose/config

# Config chain
# Defaults
zookeeper="localhost:2181"
zookeeperPath="/kafka"
broker="localhost:9092"
credentialsFile=""
kafkaLocation="/usr/share/kcompose/kafka"
configFile=${KCOMPOSE_CONFIG_FILE:-$defaultConfigFile}


# Config file
readConfig() {
    local KCOMPOSE_ZOOKEEPER
    local KCOMPOSE_ZOOKEEPER_PATH
    local KCOMPOSE_BROKER
    local KCOMPOSE_CREDENTIALS_FILE
    local KCOMPOSE_KAFKA_LOCATION
    source $configFile
    zookeeper=${KCOMPOSE_ZOOKEEPER:-$zookeeper} 
    zookeeperPath=${KCOMPOSE_ZOOKEEPER_PATH:-$zookeeperPath} 
    broker=${KCOMPOSE_BROKER:-$broker} 
    credentialsFile=${KCOMPOSE_CREDENTIALS_FILE:-$credentialsFile} 
    kafkaLocation=${KCOMPOSE_KAFKA_LOCATION:-$kafkaLocation}
}
if [ -f $configFile ]; then 
    readConfig
fi

# Environment variables
zookeeper=${KCOMPOSE_ZOOKEEPER:-$zookeeper} 
zookeeperPath=${KCOMPOSE_ZOOKEEPER_PATH:-$zookeeperPath} 
broker=${KCOMPOSE_BROKER:-$broker} 
credentialsFile=${KCOMPOSE_CREDENTIALS_FILE:-$credentialsFile} 
kafkaLocation=${KCOMPOSE_KAFKA_LOCATION:-$kafkaLocation}


# internal variables
zookeeperFull="$zookeeper$zookeeperPath"
kafkaBinaries="$kafkaLocation/bin"
programName=`basename $0`

# functions
doc(){
    if [ -z $2 ] 
    then
        echo -e "Usage: $programName $1"
        exit
    fi
}

invalid() {
    echo "Invalid command!"
}

escapeStar() {
    commands=`sed 's/\*/\\\*/g' <<< """$*"""`
    eval "$commands"
}
ask() {
    local result
    local question
    local default
    local answer
    local options
    result=$1
    question=$2
    default=$3

    echo -ne "$question\t($default): "
    read answer
    answer="${answer:-$default}"
    eval "$result=\"$answer\""
}

saveConfigs() {
    mkdir -p `dirname $configFile`
    cat > $configFile <<EOF
KCOMPOSE_ZOOKEEPER=$zookeeper
KCOMPOSE_ZOOKEEPER_PATH=$zookeeperPath
KCOMPOSE_BROKER=$broker
KCOMPOSE_CREDENTIALS_FILE=$credentialsFile
KCOMPOSE_KAFKA_LOCATION=$kafkaLocation
EOF
    echo
    echo "Config files saved on $configFile"
    if [ "$configFile" != "$defaultConfigFile" ]; then 
        echo
        echo "Warning! Config files saved on non-default location. Remember to set the environment variable:"
        echo
        echo "export KCOMPOSE_CONFIG_FILE=$configFile"

    fi
}

login() {
    echo """
Authentication type must be one of:
- NONE
- SASL/SCRAM256
- SASL/PLAIN
"""
    ask authType "Authentication type" SASL/PLAIN
    case $authType in 
    "NONE")
        credentialsFile=""
    ;;
    "SASL/SCRAM256")
        ask credentialsFile "Credentials File" $HOME/.kcompose/credentials
        mkdir -p `dirname $credentialsFile`
        ask username "Username" ""
        ask password "Password" ""
        cat > $credentialsFile <<EOF
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
        username="$username" \
        password="$password";
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
EOF
    echo
    echo "Credentials saved on $credentialsFile"

    ;;
    "SASL/PLAIN")
        ask credentialsFile "Credentials File" $HOME/.kcompose/credentials
        mkdir -p `dirname $credentialsFile`
        ask username "Username" ""
        ask password "Password" ""
        cat > $credentialsFile <<EOF
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
        username="$username" \
        password="$password";
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
EOF
    echo
    echo "Credentials saved on $credentialsFile"

    ;;
    *)
    echo $authType
    echo "Must be one of:"
    echo " - NONE"
    echo " - SASL/SCRAM256"
    echo " - SASL/PLAIN"
    exit 1
    ;;
    esac
    saveConfigs

}

setup() {
    ask configFile "Configuration file" $configFile
    ask zookeeper "Zoookeeper host:port" $zookeeper
    ask zookeeperPath "Zoookeeper path" $zookeeperPath
    ask broker "kafka brokers" $broker
    ask kafkaLocation "Kafka Location" $kafkaLocation
    
    ask login "login now? (y/n)" "y"

    if [ "$login" = "y" ]; then
        login
    else 
        saveConfigs
    fi
}

# commands
doc "[topic, acl, auth, produce, consume, group, env, config, login]" $1
case $1 in 
"topic")
    doc "topic [list, describe, alter, remove, create]" $2
    case $2 in 
    "list")
    ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker --command-config $credentialsFile --list
    ;;
    "describe")
    doc "topic describe TOPIC" $3
    topic=$3
    shift 3
    ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker --command-config $credentialsFile --describe --topic $topic $*
    ;;
    "alter")
    doc "topic alter TOPIC" $3
    topic=$3
    shift 3
    options=$*
    ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker --command-config $credentialsFile --alter --topic $topic $options
    ;;
    "remove")
    doc "topic remove TOPIC" $3
    ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker --command-config $credentialsFile --delete --topic $3
    ;;
    "create")
    doc "topic create TOPIC [options]" $3
    topic=$3
    shift 3
    options=$*
    ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker --command-config $credentialsFile --create --topic $topic $options
    ;;
    *)
      invalid
    ;;
    esac
;;
"acl") 
    aclHelp="""Usage:
acl [
        ([add, remove] RULE), 
        list
]

RULE:
    [ --user USER ]\t\tUser target for this rule
    [ --host HOST ]\t\tHost target for this rule (Default: '*' when --user is set)
    [ --allow / --deny]\t\tIf this describe an 'allow' or 'deny' rule (Default: Allow)
    [ --literal / --prefixed ]\tIndicates how the resource is described (Default: literal)
    [ --topic TOPIC ]\t\tTopic Resource
    [ --group GROUP ]\t\tGroup Resource
    [ --cluster ]\t\tGroup Resource
    [ --transaction ]\t\tTransactional Id Resource
    [ --operation OPERATION ]\tWhat kind of operation is allowed in this resource (Default: all)
    [ --consumer ]\t\tConvenience method for consumer
    [ --producer ]\t\tConvenience method for producer
Examples:
\$ $progName acl list # Lists all ACLs
\$ $progName acl add --user user1 --topic mytopic --producer # Allows user1 to produce on mytopic
\$ $progName acl add --host 192.168.0.100 --topic '*' --group '*' --consumer # Allows host 192.168.0.100 to read from all topics on all groups
\$ $progName acl remove --user user2 --topic 'test' --producer # Removes rule 'user2 can produce on topic test'
"""
    error() {
        echo $1
        echo -e "$aclHelp"
        exit 1
    }
    doc "$aclHelp" $2
    shift
    # base="${kafkaBinaries}/kafka-acls.sh --authorizer-properties zookeeper.connect=$zookeeperFull"
    case $1 in 
    "add"|"remove")
        acl_command="--$1"
        acl_user=""
        acl_host=""
        acl_allow="--allow"
        acl_literal="--literal"
        acl_topic=""
        acl_group=""
        acl_cluster=""
        acl_operation=""
        acl_transaction=""
        acl_convenience=""
        shift
        while [ $# \> 0 ]; do
            case $1 in
            "--consumer"|"--producer")
                acl_convenience=$1   
            ;;
            "--user")
                shift
                acl_user=$1
            ;;
            "--host")
                shift
                acl_host="$1"
            ;;
            "--allow"|"--deny")
                shift
                acl_allow=$1
            ;;
            "--literal"|"--prefixed")
                acl_literal=$1
            ;;
            "--topic")
                shift
                acl_topic="$1"
            ;;
            "--group")
                shift
                acl_group="$1"
            ;;
            "--transaction")
                shift
                acl_transaction="$1"
            ;;
            "--cluster")
                acl_cluster="$1"
            ;;
            "--operation")
                shift
                acl_operation=$1
            ;;
            *)
                echo "Unexpected token: $1"
                exit 1
            ;;
            esac
            shift
        done
        # Validation
        if [ -z "$acl_user" ] && [ -z "$acl_host"]; then
            error "At least one target must be specified (user/host)"
        fi

        if [ -z "$acl_topic" ] && [ -z "$acl_group" ] && [ -z "$acl_cluster" ] && [ -z "$acl_transaction" ]; then
            error "At least one resource must be specified (topic/group/cluster/transaction)"
        fi

        if [ "$acl_convenience" = "--producer" ] && [ -z "$acl_topic" ]; then
            error "'--producer' must specify a topic"
        fi

        if [ "$acl_convenience" = "--consumer" ] && `[ -z "$acl_topic" ] || [ -z "$acl_group" ]`; then
            error "'--consumer' must specify a topic and group"
        fi

        # Build command
        if [ "$acl_allow" = "--allow" ]; then
            user_command="${acl_user:+--allow-principal User:$acl_user} ${acl_host:+--allow-host $acl_host}"
        else
            user_command="${acl_user:+--deny-principal User:$acl_user} ${acl_host:+--deny-host $acl_host}"
        fi

        if [ "$acl_literal" = "--literal" ]; then
            resource_command="--resource-pattern-type literal"
        else
            resource_command="--resource-pattern-type prefixed"
        fi

        acl_command="$acl_command $user_command $resource_command \
        ${acl_topic:+--topic $acl_topic} ${acl_group:+--group $acl_group} \
        ${acl_transaction:+--transactional-id $acl_transaction} $acl_cluster \
        ${acl_operation:+--operation $acl_operation} $acl_convenience"

        # Execute command
        ${kafkaBinaries}/kafka-acls.sh --authorizer-properties zookeeper.connect=$zookeeperFull $acl_command
    ;;
    "list")
        shift
        ${kafkaBinaries}/kafka-acls.sh --authorizer-properties zookeeper.connect=$zookeeperFull --list
    ;;
    *)
        invalid
    ;;
    esac
    
;;
"auth")
    doc "auth [remove, create, update]" $2
    case $2 in
    "update"|"create")
        user=$3
        password=$4
        doc "auth $2 USER PASSWORD" $user
        doc "auth $2 USER PASSWORD" $password
        ${kafkaBinaries}/kafka-configs.sh --zookeeper $zookeeperFull --alter --add-config "SCRAM-SHA-256=[iterations=8192,password=$password],SCRAM-SHA-512=[password=$password]" --entity-type users --entity-name $user
    ;;
    "remove")
        doc "auth remove USER" $3
        ${kafkaBinaries}/kafka-configs.sh --zookeeper $zookeeperFull --alter --entity-name $3 --entity-type users --delete-config "SCRAM-SHA-256,SCRAM-SHA-512"
    ;;
    *)
        invalid
    ;;
    esac
;;
"produce")
    doc "produce TOPIC [options]" $2
    topic=$2
    shift 2
    options=$*
    ${kafkaBinaries}/kafka-console-producer.sh --broker-list $broker --topic $topic --producer.config $credentialsFile $options
;;
"consume")
    doc "consume TOPIC [options]" $2
    topic=$2
    shift 2
    options=$*
    ${kafkaBinaries}/kafka-console-consumer.sh --bootstrap-server $broker --topic $topic --consumer.config $credentialsFile $options
;;
"group")
    doc "group [list, describe, remove]" $2
    case $2 in
    "list")
        ${kafkaBinaries}/kafka-consumer-groups.sh  --bootstrap-server $broker --command-config $credentialsFile --list
    ;;
    "describe")
        doc "group describe GROUP" $3
        ${kafkaBinaries}/kafka-consumer-groups.sh  --bootstrap-server $broker --command-config $credentialsFile --describe --group $3
    ;;
    "remove")
        doc "group remove GROUP" $3
        ${kafkaBinaries}/kafka-consumer-groups.sh  --bootstrap-server $broker --command-config $credentialsFile --delete --group $3
    ;;
    "reset")
        doc "group reset GROUP [options]" $3
        group=$3
        shift 2
        ${kafkaBinaries}/kafka-consumer-groups.sh  --bootstrap-server $broker --command-config $credentialsFile --reset-offsets --group $group $*
    ;;
    esac
;;
"env")
    if [ -f $configFile ]; then
    echo "Config file location: $configFile"
    fi
    echo "Zookeeper connection: $zookeeperFull"
    echo "Kafka connection: $broker"
    echo "Kafka location: $kafkaLocation"
    echo "Credentials file: ${credentialsFile:-None}"

    if [ "$2" =  "credentials" ]; then
        echo
        cat $credentialsFile
    else
        if [ ! -z $credentialsFile ]; then
            echo
            echo "Use \"$programName env credentials\" to show credentials info"
        fi
    fi 
    
;;
"config")
    setup
;;
"login")
    login
;;
*)
    invalid
;;
esac
