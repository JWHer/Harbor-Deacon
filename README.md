# Deacon

docker private registry helper  
![alt](deacon.png)  
*Deacon help you with a short command for docker private registry*

# usage
./deacon.sh [push/pull] [ImageName] [Flags]  
`--user`       `-u`: User ID  
`--password`   `-p`: password  
`--repository` `-r`: repository URL  
`--config`     `-c`: `.config` location  
`--help`       `-h`: help  

# 디콘

도커 프라이빗 레지스트리 도우미  
docker wrapper shell로 짧은 명령어와 일반 사용자가 실수하기 쉬운 부분을 도와줍니다.  

# 사용법
./deacon.sh [push/pull] [ImageName] [Flags]  
`--user`       `-u`: 사용자 아이디  
`--password`   `-p`: 비밀번호  
`--repository` `-r`: 레포지토리 URL  
`--config`     `-c`: `.config` 위치  
`--help`       `-h`: 도움말  

# Update log
latest version: v1  
## v1
Harbor로 테스트 하였습니다.  
WSL도 지원하나 오류가 있습니다.  
