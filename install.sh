#!/bin/sh

set -e

SCRIPT_DIRECTORY="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

if [ -z "$VERSION" ]; then
	VERSION=dev-master
fi

if [ -z "$SSH_KEY" ]; then
	SSH_KEY=id_rsa
fi

DOCKER_IMAGE=norsys/rothenberg
COMPOSER_VCS=
DOCKER_VCS=
INSTALL_DIRECTORY=.

while [ "$1" != "" ]; do
	PARAM=`echo $1 | awk -F= '{print $1}'`
	VALUE=`echo $1 | sed 's/^[^=]*=//g'`

	case $PARAM in
		--build-docker-image)
			DOCKER_ACTION=build
			;;
		--pull-docker-image)
			DOCKER_ACTION=pull
			;;
		--vcs)
			COMPOSER_VCS="-v $SCRIPT_DIRECTORY:$VALUE"
			DOCKER_VCS=$VALUE
			;;
		--image)
			DOCKER_IMAGE=$VALUE
			;;
		--directory)
			INSTALL_DIRECTORY=$VALUE
			;;
		--target)
			TARGET=$VALUE
			;;
		--symfony-version)
			SYMFONY_VERSION=$VALUE
			;;
		*)
			echo "ERROR: unknown parameter \"$PARAM\""
			exit 1
			;;
	esac

	shift
done

if [ -z "$SYMFONY_VERSION" ]; then
	SYMFONY_VERSION="^3.4"
elif [[ $(echo "$SYMFONY_VERSION" | grep -E '^[0-9]+(.[0-9]+)*$' | grep -vE '^([456789][0-9]*|[1-9][0-9]+|[0-2]).?') != "$SYMFONY_VERSION" ]]; then
	echo "Symfony version lesser or greater than 3 is not currently supported."
	exit
fi

if [ -z "$TARGET" ]; then
	TARGET=app
fi

case $DOCKER_ACTION in
	build)
		docker build -t $DOCKER_IMAGE $SCRIPT_DIRECTORY/docker
		;;
	pull)
		docker pull $DOCKER_IMAGE
		;;
	"")
		;;
	*)
		echo "ERROR: unknown docker command \"$DOCKER_ACTION\""
		exit 2
		;;
esac

trap 'rm -f $(pwd)/passwd' 0 1 2 3 15

mkdir -p $INSTALL_DIRECTORY

cd $INSTALL_DIRECTORY

echo "root:x:$(id -u):0:root:$HOME:/bin/sh" > $(pwd)/passwd

docker run --rm -v $(pwd):/src -v $HOME/.ssh:$HOME/.ssh -v $HOME/.composer:/.composer -v $(pwd)/passwd:/etc/passwd $COMPOSER_VCS -u $(id -u) -e TARGET=$TARGET -e VERSION=$VERSION -e SSH_KEY=$SSH_KEY -e DOCKER_VCS=$DOCKER_VCS -e SYMFONY_VERSION=$SYMFONY_VERSION -e WITH_DEBUG=$WITH_DEBUG $DOCKER_IMAGE
