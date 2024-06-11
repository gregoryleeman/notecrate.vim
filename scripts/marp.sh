SOURCE=${1};
TARGET="${SOURCE%.*}_p.html";

# sed -n '/---/q;p' ${SOURCE} > temp.md;

docker run \
	--rm \
	-v ${PWD}:/home/marp/app/ \
	-e LANG=${LANG} \
	-e MARP_USER="$(id -u):$(id -g)" \
	marpteam/marp-cli \
		-o ${TARGET} \
		temp.md;
