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

defaultConfigFile=$HOME/.kcompose/config

# Config chain
# Defaults
zookeeper="localhost:2181"
zookeeperPath="/kafka"
broker="localhost:9092"
credentialsFile=""
kafkaLocation="/usr/share/kcompose/kafka"
configFile=$KCOMPOSE_CONFIG_FILE
if [ -z "$configFile"]; then
    configFile=$defaultConfigFile
fi

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
        echo "Usage: $programName $1"
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
    ask authType "Authentication type" SASL/SCRAM256
    case $authType in 
    "PLAINTEXT")
        credentialsFile=""
    ;;
    "SASL/SCRAM256")
        ask credentialsFile "Credentials File" $HOME/.kcompose/credentials
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
    *)
    echo $authType
        echo "Must be one of:"
        echo " - PLAINTEXT"
        echo " - SASL/SCRAM256"
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
doc "[topic, acl, auth, produce, consume, group, env, config]" $1
case $1 in 
"topic")
    doc "topic [list,describe,alter,remove,create]" $2
    case $2 in 
    "list")
    ${kafkaBinaries}/kafka-topics.sh --zookeeper $zookeeperFull --list
    ;;
    "describe")
    doc "topic describe TOPIC" $3
    topic=$3
    shift 3
    ${kafkaBinaries}/kafka-topics.sh --zookeeper $zookeeperFull --describe --topic $topic $*
    ;;
    "alter")
    doc "topic alter TOPIC" $3
    topic=$3
    shift 3
    options=$*
    ${kafkaBinaries}/kafka-topics.sh --zookeeper $zookeeperFull --alter --topic $topic $options
    ;;
    "remove")
    doc "topic remove TOPIC" $3
    ${kafkaBinaries}/kafka-topics.sh --zookeeper $zookeeperFull --delete --topic $3
    ;;
    "create")
    doc "topic create TOPIC [options]" $3
    topic=$3
    shift 3
    options=$*
    ${kafkaBinaries}/kafka-topics.sh --zookeeper $zookeeperFull --create --topic $topic $options
    ;;
    *)
      invalid
    ;;
    esac
;;
"acl") 
    shift
    base="${kafkaBinaries}/kafka-acls.sh --authorizer-properties zookeeper.connect=$zookeeperFull"
    case $1 in 
    "user")
        doc "acl user USER [allow,deny] [options]" $2
        doc "acl user USER [allow,deny] [options]" $3
        user=$2
        principal=""
        case $3 in
        "allow")
            principal="--allow-principal User:$user"
        ;;
        "deny")
            principal="--deny-principal User:$user"
        ;;
        *)
            invalid
        ;;
        esac
        shift 3
        escapeStar "$base $principal $*"
    ;;
    "list")
    shift
    escapeStar "$base --list $*"
    ;;
    *)
        escapeStar "$base $*"
    ;;
    esac
    
;;
"auth")
    doc "auth [remove,update]" $2
    case $2 in
    "update")
        user=$3
        password=$4
        doc "auth update USER PASSWORD" $user
        doc "auth update USER PASSWORD" $password
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
