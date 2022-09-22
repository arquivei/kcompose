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
configPath=$HOME/.kcompose/

defaultConfigPath=${configPath}default/
defaultConfigFile=${defaultConfigPath}config

defaultCredentialsPath=${configPath}default/
defaultCredentialsFile=${defaultCredentialsPath}credentials

if [ ! -f ${configPath}context ]; then
    touch ${configPath}context
fi

source ${configPath}context
currentContext=${KCOMPOSE_CONTEXT:-"default"}

if [ -z "$KCOMPOSE_CONFIG_FILE" ]; then
    if [ ! -d "${configPath}${currentContext}" ]; then
        echo -e "WARNING: Context ${currentContext} not found\n\n"
        echo -e "Please, set a valid context using the command:"
        echo -e "kcompose context set <context>\n"
    fi
fi

# Config chain
# Defaults
broker="localhost:9092"
kafkaLocation="/usr/share/kcompose/kafka"
credentialsFile=""
configFile=${KCOMPOSE_CONFIG_FILE:-$defaultConfigFile}

# Config file
readConfig() {
    local KCOMPOSE_BROKER
    local KCOMPOSE_CREDENTIALS_FILE
    local KCOMPOSE_KAFKA_LOCATION
    source $configFile
    broker=${KCOMPOSE_BROKER:-$broker}
    credentialsFile=${KCOMPOSE_CREDENTIALS_FILE:-$credentialsFile}
    kafkaLocation=${KCOMPOSE_KAFKA_LOCATION:-$kafkaLocation}
}
if [ -f $configFile ]; then
    readConfig
fi

# Environment variables
broker=${KCOMPOSE_BROKER:-$broker}
credentialsFile=${KCOMPOSE_CREDENTIALS_FILE:-$credentialsFile}
kafkaLocation=${KCOMPOSE_KAFKA_LOCATION:-$kafkaLocation}

# internal variables
kafkaBinaries="$kafkaLocation/bin"
programName=$(basename $0)
commandConfig=""
producerConfig=""
consumerConfig=""

if [ ! -z "$credentialsFile" ]; then
    commandConfig="--command-config $credentialsFile"
    producerConfig="--producer.config $credentialsFile"
    consumerConfig="--consumer.config $credentialsFile"
fi

# functions
usage() {
    echo -e "$helpText"
    exit
}

checkNArgs() {
    if [ -z "$1" ]; then
        usage
    fi
}

escapeStar() {
    commands=$(sed 's/\*/\\\*/g' <<<"""$*""")
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

saveContext() {
    if [ -f ${configPath}context ]; then
        echo "KCOMPOSE_CONTEXT=$1" > ${configPath}context
    fi
}

saveConfigs() {
    mkdir -p $(dirname $configFile)
    cat >$configFile <<EOF
KCOMPOSE_BROKER=$broker
KCOMPOSE_CREDENTIALS_FILE=$credentialsFile
KCOMPOSE_KAFKA_LOCATION=$kafkaLocation
EOF
    echo
    echo "Config files saved on $configFile"
    echo
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
        if [ -z "$KCOMPOSE_CONFIG_FILE" ]; then
            credentialsFile=${configPath}$currentContext/credentials
        else
            credentialsFile=${configPath}credentials
        fi
        mkdir -p $(dirname $credentialsFile)
        ask username "Username" ""
        ask password "Password" ""
        cat >$credentialsFile <<EOF
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
        if [ -z "$KCOMPOSE_CONFIG_FILE" ]; then
            credentialsFile=${configPath}$currentContext/credentials
        else
            credentialsFile=${configPath}credentials
        fi
        mkdir -p $(dirname $credentialsFile)
        ask username "Username" ""
        ask password "Password" ""
        cat >$credentialsFile <<EOF
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
    if [ -z "$1" ]; then
        ask setupConfig "Configuration name" "default"
    else
        setupConfig=$1
        validate_name $setupConfig
    fi
        configFile=${configPath}$setupConfig/config

    if [ -f $configFile ]; then
        ask overwrite "Configuration \"$setupConfig\" already exist, do you want overwrite it? [y/N]" "n"
        if [ "$overwrite" != "y" ]; then
            exit
        fi
    fi

    currentContext=$setupConfig
    saveContext $currentContext

    ask broker "Kafka brokers" $broker
    ask kafkaLocation "Kafka Location" $kafkaLocation

    ask login "Login now? (y/n)" "y"

    if [ "$login" = "y" ]; then
        login
    else
        saveConfigs
    fi
}

# context is a function that manages the context of the config and credentials files
context() {

    if [ ! -z "$KCOMPOSE_CONFIG_FILE" ]; then
        echo "Contexts are only available when KCOMPOSE_CONFIG_FILE is not set"
        exit 1
    fi

    helpText="Usage: $programName context [new, set, list, delete, show] [contextName]\n"
    helpText+="\tnew\t\tCreate a new context\n"
    helpText+="\tset\t\tSet the current context\n"
    helpText+="\tlist\t\tList all contexts\n"
    helpText+="\tdelete\t\tDelete a context\n"
    helpText+="\tshow\t\tShow the current context\n"
    helpText+="\tcontextName\tName of the context\n"

    # checkNArgs $1
    case $1 in
    "new")
        checkNArgs $2
        context_new $2
        ;;
    "set")
        checkNArgs $2
        context_set $2
        ;;
    "list")
        context_list
        ;;
    "delete")
        checkNArgs $2
        context_delete $2
        ;;
    "show")
        context_show
        ;;
    *)
        usage
        ;;
    esac
}

# context_new creates a new context
context_new() {
    helpText="Usage: $programName context new [contextName]\n"
    checkNArgs $1

    setup $1
    echo "Context \"$1\" was created"
}

# context_set sets the current context
context_set() {
    helpText="Usage: $programName context set [contextName]\n"
    checkNArgs $1

    if [ ! -f ${configPath}$1/config ]; then
        echo "Context \"$1\" does not exist"
        exit 1
    fi
    configFile=${configPath}$1/config
    currentContext=$1
    readConfig
    echo "Context set to \"$1\""
    saveContext $currentContext
}

# context_list lists all contexts
context_list() {
    current=""
    echo "Contexts:"
    for context in $(ls $configPath); do
        if [ -f ${configPath}$context/config ]; then
            if [ "$context" = "$currentContext" ]; then
                current="*"
            else
                current=""
            fi
            echo -e "\t$context$current"
        fi
    done
}

# context_delete deletes a context
context_delete() {
    helpText="Usage: $programName context delete [contextName]\n"
    checkNArgs $1

    if [ ! -f ${configPath}$1/config ]; then
        echo "Context \"$1\" does not exist"
        exit 1
    fi
    rm -rf ${configPath}$1 && echo "Context \"$1\" was deleted"
    currentContext="default"
    saveContext $currentContext
    echo -e "Current context is \"$currentContext\"\n"
    echo "If you want to change it, use the command:"
    echo "$programName context set [contextName]"
}

# context_show shows the current context
context_show() {
    if [ ! -d "${configPath}${currentContext}" ]; then
        echo "Context \"$currentContext\" does not exist"
        echo "Please, set a valid context"
        echo "Use the command:"
        echo "$programName context set [contextName]"
        exit 1
    fi
    echo -e "Current context: $currentContext\n"
    echo -e - "Config file: $configFile\n"
    cat $configFile
    echo ""
    echo -e - "Credentials file: $credentialsFile\n"
    cat $credentialsFile
}

# validate_name checks if the filename is valid
validate_name() {
    __name=$1
    val=$(echo "${#__name}")

    if [[ $__name == "default" ]]; then
        echo "Context name cannot be 'default'"
        exit
    fi

    if [[ $__name == "" ]]; then
        echo "Filename: $__name cannot be empty"
        exit
    fi

    if [[ $__name == "." ]] || [[ $__name == ".." ]]; then
        # "." and ".." are added automatically and always exist, so you can't have a
        # file named . or .. // https://askubuntu.com/a/416508/660555
        echo "Filename: $__name is not valid"
        exit
    fi

    if [ $val -gt 255 ]; then
        # String's length check
        echo "Filename: $__name has more than 255 characters"
        exit
    fi

    if ! [[ $__name =~ ^[0-9a-zA-Z._-]+$ ]]; then
        # Checks whether valid characters exist
        echo "Filename: $__name has invalid characters"
        exit
    fi

    ___name=$(echo $__name | cut -c1-1)
    if ! [[ $___name =~ ^[0-9a-zA-Z.]+$ ]]; then
        # Checks the first character
        echo "Filename: $__name has invalid first character"
        exit
    fi
}

# commands
helpText="Usage: $programName [topic, acl, produce, consume, group, env, config, setup, login, user]\n"
helpText+="\ttopic\t\tTopic management\n"
helpText+="\tacl\t\tACL management\n"
helpText+="\tproduce\t\tProduce messages to a topic\n"
helpText+="\tconsume\t\tConsume messages from a topic\n"
helpText+="\tgroup\t\tGroup Management\n"
helpText+="\tenv\t\tShows the current kcompose connection configs\n"
helpText+="\tconfig\t\tDEPRECATED: Initial kcompose configuration\n"
helpText+="\tsetup\t\tInitial kcompose configuration\n"
helpText+="\tlogin\t\tChanges the kcompose credentials\n"
helpText+="\tuser\t\tUser Management"
checkNArgs $1
case $1 in
"topic")
    helpText="Usage: $programName topic [list, describe, alter, remove, create, acl]"
    checkNArgs $2
    case $2 in
    "list")
        ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker $commandConfig --list
        ;;
    "describe")
        helpText="Usage: $programName topic describe TOPIC"
        checkNArgs $3
        topic=$3
        shift 3
        ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker $commandConfig --describe --topic $topic $*
        ;;
    "alter")
        helpText="Usage: $programName topic alter TOPIC [options]"
        checkNArgs $3
        topic=$3
        shift 3
        options=$*
        ${kafkaBinaries}/kafka-configs.sh --bootstrap-server $broker $commandConfig --alter --topic $topic $options
        ;;
    "remove")
        helpText="Usage: $programName topic remove TOPIC"
        checkNArgs $3
        ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker $commandConfig --delete --topic $3
        ;;
    "create")
        helpText="Usage: $programName topic create TOPIC [options]"
        checkNArgs $3
        topic=$3
        shift 3
        options=$*
        ${kafkaBinaries}/kafka-topics.sh --bootstrap-server $broker $commandConfig --create --topic $topic $options
        ;;
    "acl")
        helpText="Usage: $programName topic acl [list]"
        checkNArgs $3
        case $3 in
        "list")
            helpText="Usage: $programName topic acl TOPIC [options]"
            checkNArgs $4
            topic=$4
            shift 4
            options=$*
            ${kafkaBinaries}/kafka-acls.sh --bootstrap-server $broker $commandConfig --list --topic $topic --resource-pattern-type MATCH $options
            ;;
        *)
            usage
            ;;
        esac
        ;;
    *)
        usage
        ;;
    esac
    ;;
"acl")
    helpText="""Usage:
$programName acl [
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
        echo -e "$helpText"
        exit 1
    }
    helpText="$helpText"
    checkNArgs $2
    shift
    case $1 in
    "add" | "remove")
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
            "--consumer" | "--producer")
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
            "--allow" | "--deny")
                shift
                acl_allow=$1
                ;;
            "--literal" | "--prefixed")
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

        if [ "$acl_convenience" = "--consumer" ] && $([ -z "$acl_topic" ] || [ -z "$acl_group" ]); then
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
        ${kafkaBinaries}/kafka-acls.sh --bootstrap-server $broker $commandConfig $acl_command
        ;;
    "list")
        shift
        options=$*
        ${kafkaBinaries}/kafka-acls.sh --bootstrap-server $broker $commandConfig --list $options
        ;;
    *)
        usage
        ;;
    esac

    ;;
"produce")
    helpText="Usage: $programName produce TOPIC [options]"
    checkNArgs $2
    case $2 in
    "-h" | "--help")
        ${kafkaBinaries}/kafka-console-producer.sh -h
        ;;
    *)
        topic=$2
        shift 2
        options=$*
        ${kafkaBinaries}/kafka-console-producer.sh --broker-list $broker --topic $topic $producerConfig $options
        ;;
    esac
    ;;
"consume")
    helpText="Usage: $programName consume TOPIC [options]"
    checkNArgs $2
    case $2 in
    "-h" | "--help")
        ${kafkaBinaries}/kafka-console-consumer.sh -h
        ;;
    *)
        topic=$2
        shift 2
        options=$*
        ${kafkaBinaries}/kafka-console-consumer.sh --bootstrap-server $broker --topic $topic $consumerConfig $options
        ;;
    esac
    ;;
"group")
    helpText="Usage: $programName group [list, describe, remove, acl]"
    checkNArgs $2
    case $2 in
    "list")
        ${kafkaBinaries}/kafka-consumer-groups.sh --bootstrap-server $broker $commandConfig --list
        ;;
    "describe")
        helpText="Usage: $programName group describe GROUP"
        checkNArgs $3
        ${kafkaBinaries}/kafka-consumer-groups.sh --bootstrap-server $broker $commandConfig --describe --group $3
        ;;
    "remove")
        helpText="Usage: $programName group remove GROUP"
        checkNArgs $3
        ${kafkaBinaries}/kafka-consumer-groups.sh --bootstrap-server $broker $commandConfig --delete --group $3
        ;;
    "reset")
        helpText="Usage: $programName group reset GROUP [options]"
        checkNArgs $3
        group=$3
        shift 2
        ${kafkaBinaries}/kafka-consumer-groups.sh --bootstrap-server $broker $commandConfig --reset-offsets --group $group $*
        ;;
    "acl")
        helpText="Usage: $programName group acl [list]"
        checkNArgs $3
        case $3 in
        "list")
            helpText="Usage: $programName group acl GROUP [options]"
            checkNArgs $4
            group=$4
            shift 4
            options=$*
            ${kafkaBinaries}/kafka-acls.sh --bootstrap-server $broker $commandConfig --list --group $group --resource-pattern-type MATCH $options
            ;;
        *)
            usage
            ;;
        esac
        ;;
    *)
        usage
        ;;
    esac
    ;;
"env")
    if [ -f $configFile ]; then
        echo "Config file location: $configFile"
    fi
    echo "Kafka connection: $broker"
    echo "Kafka location: $kafkaLocation"
    echo "Credentials file: ${credentialsFile:-None}"

    if [ "$2" = "credentials" ] && [ ! -z "$credentialsFile" ]; then
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
    echo -e "DEPRECATED: Use '$programName setup' instead\n"
    setup
    ;;
"setup")
    setup
    ;;
"login")
    login
    ;;
"user")
    helpText="Usage: $programName user [acl]"
    checkNArgs $2
    case $2 in
    "acl")
        helpText="Usage: $programName user acl [list]"
        checkNArgs $3
        case $3 in
        "list")
            helpText="Usage: $programName user acl list USER [options]"
            checkNArgs $4
            user=$4
            shift 2
            ${kafkaBinaries}/kafka-acls.sh --bootstrap-server $broker $commandConfig --list --principal User:$user $*
            ;;
        *)
            usage
            ;;
        esac
        ;;
    *)
        usage
        ;;
    esac
    ;;
"context")
    context $2 $3
    ;;
*)
    usage
    ;;
esac
