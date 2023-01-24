#
# Ce Makefile est destiné à être utilisé par GNU make
#

CFLAGS = -g -Wall -Wextra -Werror

all:	doublons

test:	doublons
	sh test.sh

#
# Règles spéciales pour utiliser l'image Docker de référence
# Utiliser avec :
#	make build-in-docker
#	make test-in-docker
#

build-in-docker:	doublons.c
	docker run --rm \
		--volume "$$PWD":/mnt --workdir /mnt -u 1000:1000 \
		pdagog/refc \
		make doublons

# comme les fichiers dans /tmp sont perdus lorsque le conteneur Docker
# se termine, on place tout dans le répertoire courant (./dock-test*)
test-in-docker:		doublons
	docker run --rm \
		--volume "$$PWD":/mnt --workdir /mnt -u 1000:1000 \
		pdagog/refc \
		sh -c "TMP=./dock-test make test"

clean::
	rm -f *.o
	rm -f doublons
