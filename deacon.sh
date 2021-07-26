#!/bin/bash
# Copyright (C) 2021 JWHer

echo "Deacon v1";

function usage {
    echo "USAGE: $0 [push/pull] [ImageName] [Flags]";
    echo "# --user       -u: 도커 아이디";
    echo "# --password   -p: 도커 패스워드";
    echo "# --repository -r: 레포지토리";
    echo "# --config     -c: 설정위치";
    echo "# --help       -h: 도움말";
    exit 0;
}

function checkOS {
    if grep -q Microsoft /proc/version; then
        #echo "Ubuntu on Windows";
        return 1;
    else
        #echo "native Linux";
        return 0;
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

    docker login $HARBOR_REPO $ARG
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

# push or pull
CMD=$1;
shift;
#echo $@;
if [ $CMD != 'push' ] && [ $CMD != 'pull' ]; then
    echo "Only support push or pull, Given $CMD";
    usage;
    exit 1;
fi

IMG_NAME=$1;
#[ -z $IMG_NAME ] && echo invalid;
shift;

# check image name
if ! [[ $IMG_NAME =~  ^([^\/]+)\/([^\/:]+)\/([^\/:]+):([^\/:\n]+) ]] &&
   ! [[ $IMG_NAME =~  ^([^\/:]+):([^\/:\n]+) ]]; then
    echo 'Image name validation failed';
    usage;
    exit 1;
fi

if [ -z $CMD ] || [ -z $IMG_NAME ]; then
    echo "Give Command and Image name, Given: $CMD, $IMG_NAME";
    usage;
    exit 1;
fi

# --user u
# --password p
# --repository r
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
        -r|--repository)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                HARBOR_REPO=$2;
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
            usage;
            ;;
        *)
            # default
            usage;
            exist 1;
    esac
done

# check CONF parameter
if [ -z $CONF ]; then
    #echo "parm config not set";
    CONF=".conf";
fi

# check .conf exist
if [ -f $CONF ];then
    HARBOR_REPO=$( jq '.harbor_repo' $CONF | sed -e 's/^"//' -e 's/"$//' );
    #echo $HARBOR_REPO;
else
    echo "creating new '$CONF' file";

    # check HARBOR_REPO parameter
    if [ -z $HARBOR_REPO ]; then
        HARBOR_REPO="core.harbor.192.168.1.161.nip.io:30604"
    fi

    echo "set default registry: $HARBOR_REPO";
    echo "{\"harbor_repo\": \"$HARBOR_REPO\"}">$CONF;
fi

# check image name
if [[ $IMG_NAME =~  ^([^\/]+)\/([^\/:]+)\/([^\/:]+):([^\/:\n]+) ]]; then
    # 잘 짜여진 이름일 때
    # 레포지토리 확인
    if [ "${BASH_REMATCH[1]}" != "$HARBOR_REPO" ]; then
        echo 'Repository mismatch';
        echo "${BASH_REMATCH[1]} != $HARBOR_REPO";
        exit 1;
    fi

elif [[ $IMG_NAME =~  ^([^\/:]+):([^\/:\n]+) ]]; then
    # 단순 이미지 이름일 때
    if ! [ -z $ID ]; then
        LIB=$ID
    else
        LIB='library'
    fi

    if [ $CMD = 'push' ]; then
        docker tag $IMG_NAME "$HARBOR_REPO/$LIB/$IMG_NAME";
        if ! [ $? -eq 0 ]; then
            echo 'Image tag failed';
            exit 1;
        fi
    fi
    IMG_NAME="$HARBOR_REPO/$LIB/$IMG_NAME";

else
    echo 'Image name validation failed';
    exit 1;
fi

# debug
echo "u: $ID p: $PW r: $HARBOR_REPO c: $CONF cmd: $CMD img: $IMG_NAME";

login;
# login fail
if ! [ $? -eq 0 ]; then
    # get daemon.json path
    # todo: wsl 감지를 잘 못함(Microsoft 파일이 존재x)
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
    
    DAEMON_EXIST=$(jq ".[\"insecure-registries\"] | contains([\"$HARBOR_REPO\"])" $DAEMON)
    if [ $DAEMON_EXIST -eq 'true' ]; then
        echo 'login failed';
        exit 1;
    else
        echo 'insecure registries detected';
        echo "add $HARBOR_REPO";
        jq ".[\"insecure-registries\"] += [\"$HARBOR_REPO\"]" $DAEMON >> $DAEMON

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
docker logout $HARBOR_REPO;