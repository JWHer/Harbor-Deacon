#!/bin/bash
# Copyright (C) 2021 JWHer

echo "Deacon v1.13";
# set your own default registry here
DEFAULT_REG="core.harbor.192.168.1.161.nip.io:30604"

####################     functions     ####################

function usage {
    echo "Usage: $0 [Command] [Flags]";
    echo "Commands:";
    echo "  pull    Pull an image or a repository from a registry";
    echo "  push    Push an image or a repository to a registry";
    echo "  login   Log in to a Docker registry";
    echo "  logout  Log out from a Docker registry";
}

function usagePushPull {
    echo "Usage: $0 [push/pull] [ImageName] [Flags]";
    echo "--user       -u: 도커 아이디";
    echo "--password   -p: 도커 패스워드";
    echo "--registry   -r: 레지스트리";
    echo "--config     -c: 설정위치";
    echo "--help       -h: 도움말";
    exit 0;
}

function usageAuth {
    echo "Usage: $0 [login/logout]";
    exit 0;
}

function checkOS {
    if grep -q microsoft /proc/version; then
        #echo "Ubuntu on Windows";
        return 1;
    else
        #echo "native Linux";
        return 0;
    fi
}

function isPackageInstalled {
    dpkg --status $1 &> /dev/null;
    if [ $? -eq 0 ]; then
        echo "$1: Already installed";
    else
        echo "Install requirements $1";
        sudo apt-get install -y $1
    fi
}

function login {
    ARG=''
    # insert ID
    if ! [ -z $ID ]; then
        echo 'using given id';
        ARG="-u $ID";
    fi
    # insert PW
    if ! [ -z $PW ]; then
        echo 'using given pw';
        ARG="$ARG -p $PW"
    fi

    docker login $REGISTRY $ARG
}

function loginFix {
    # get daemon.json path
    checkOS;
    if [ $? -eq 0 ]; then
        # linux
        DAEMON='/etc/docker/daemon.json'
    else
        # wsl or...
        DAEMON=$(wslpath "$(wslvar USERPROFILE)")/.docker/daemon.json
    fi

    # file check
    if ! [ -f $DAEMON ]; then
        echo "Cannot find daemon.json"
        echo "It may require root permission"
        exit 1;
    fi
    
    DAEMON_EXIST=$(jq ".[\"insecure-registries\"] | contains([\"$REGISTRY\"])" $DAEMON)
    if [ $DAEMON_EXIST -eq 'true' ]; then
        echo 'login failed';
        exit 1;
    else
        echo 'insecure registries detected';
        echo "add $REGISTRY";
        jq ".[\"insecure-registries\"] += [\"$REGISTRY\"]" $DAEMON >> $DAEMON

        # add registry fail
        if ! [ $? -eq 0 ]; then
            echo 'registry add failed';
            exit 1;
        fi

        # relogin
        login;
        if ! [ $? -eq 0 ]; then
            echo 'login failed';
            exit 1;
        fi
    fi
}

function logout {
    docker logout $REGISTRY
}

# function getParam {
#     echo $#;
#     if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
#         echo $2;
#     else
#         echo "Error: Argument for $1 is missing" >&2
#         exit 1
#     fi
# }

####################     parsing     ####################

# get cmd
CMD=$1;
shift;
#echo $@;
case $CMD in
    'push' | 'pull')
        # push/pull
        IMG_NAME=$1;
        #[ -z $IMG_NAME ] && echo invalid;
        shift;

        # check image name
        if ! [[ $IMG_NAME =~  ^([^\/]+)\/([^\/:]+)\/([^\/:]+):([^\/:\n]+) ]] &&
        ! [[ $IMG_NAME =~  ^([^\/:]+):([^\/:\n]+) ]]; then
            echo 'Image name validation failed';
            echo 'Valid format: ^([^\/]+)\/([^\/:]+)\/([^\/:]+):([^\/:\n]+) or ^([^\/:]+):([^\/:\n]+)';
            usagePushPull;
            exit 1;
        fi

        if [ -z $CMD ] || [ -z $IMG_NAME ]; then
            echo "Give Command and Image name, Given: $CMD, $IMG_NAME";
            usagePushPull;
            exit 1;
        fi
        ;;
    'login')
        # do nothing
        ;;
    'logout')
        ;;
    *)
        echo "Only support push/pull or login/logout, Given $CMD";
        usage;
        exit 1;
        ;;
esac

# --user u
# --password p
# --registry r
# --config c
# --help h
#PARAM="u:p:r:c:h";
while (( "$#" )); do
    case $1 in
        -u|--user)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                ID=$2;
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            shift 2;
            ;;
        -p|--password)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                PW=$2;
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            shift 2;
            ;;
        -r|--registry)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                REGISTRY=$2;
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            shift 2;
            ;;
        -c|--config)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                CONF=$2;
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            shift 2;
            ;;
        h)
            usagePushPull;
            ;;
        *)
            # default
            usagePushPull;
            exist 1;
    esac
done

####################     global verification     ####################

# check CONF parameter
# TODO: working directory check
if [ -z $CONF ]; then
    #echo "parm config not set";
    CONF=".conf";
fi

# check .conf exist
if [ -f $CONF ];then
    REGISTRY=$( jq '.registry' $CONF | sed -e 's/^"//' -e 's/"$//' );
    #echo $REGISTRY;
else
    # check requirements
    isPackageInstalled jq;

    echo "creating new '$CONF' file";

    # check REGISTRY parameter
    if [ -z $REGISTRY ]; then
        REGISTRY=$DEFAULT_REG;
    fi

    echo "set default registry: $REGISTRY";
    echo "{\"registry\": \"$REGISTRY\"}">$CONF;
fi

####################     execution & local verification     ####################

# login
if [ $CMD == 'login' ]; then
    login;
    # login fail
    if ! [ $? -eq 0 ]; then
        loginFix;
    fi
    exit $?;
fi

# logout
if [ $CMD == 'logout' ]; then
    logout;
    exit $?;
fi

# push/pull

# check image name
if [[ $IMG_NAME =~  ^([^\/]+)\/([^\/:]+)\/([^\/:]+):([^\/:\n]+) ]]; then
    # 잘 짜여진 이름일 때
    # 레지스트리 확인
    if [ "${BASH_REMATCH[1]}" != "$REGISTRY" ]; then
        echo 'Registry mismatch';
        echo "${BASH_REMATCH[1]} != $REGISTRY";
        exit 1;
    fi

elif [[ $IMG_NAME =~  ^([^\/:]+):([^\/:\n]+) ]]; then
    # # 단순 이미지 이름일 때
    # if ! [ -z $ID ]; then
    #     LIB=$ID
    # else
    #     LIB='library'
    # fi
    LIB='library';

    if [ $CMD = 'push' ]; then
        docker tag $IMG_NAME "$REGISTRY/$LIB/$IMG_NAME";
        if ! [ $? -eq 0 ]; then
            echo 'Image tag failed';
            exit 1;
        fi
    fi
    IMG_NAME="$REGISTRY/$LIB/$IMG_NAME";

else
    echo 'Image name validation failed';
    exit 1;
fi

# debug
#echo "u: $ID p: $PW r: $REGISTRY c: $CONF cmd: $CMD img: $IMG_NAME";

login;
# login fail
if ! [ $? -eq 0 ]; then
    loginFix;
fi

# echo "hear my roar";

# push/pull
if [ $CMD = 'push' ]; then
    echo "Pushing image $IMG_NAME";
    docker push $IMG_NAME;
    if [ $? -eq 0 ]; then
        echo 'Image push success';
    else
        echo 'Image push failed';
    fi
elif [ $CMD = 'pull' ]; then
    echo "Pulling image $IMG_NAME";
    docker pull $IMG_NAME;
    if [ $? -eq 0 ]; then
        echo 'Image pull success';
    else
        echo 'Image pull failed';
    fi
fi

# logout
logout;
