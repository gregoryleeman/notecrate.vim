HEADER="$(dirname ${0})/header.html";
for MARKDOWN in ./*.md; do
	CONVERT=0;
	TITLE=$(grep '^# \S' ${MARKDOWN} | gsed 's/# //g');
	HTML="${MARKDOWN%.*}.html";
	if [ ! -f ${HTML} ]; then
		CONVERT=1;
	elif [[ $(date -r ${MARKDOWN} +%s) > $(date -r ${HTML} +%s) ]]; then
		CONVERT=1;
	fi;
	if [[ $CONVERT -eq 1 ]]; then
		echo "Converting ${TITLE}";
		`which pandoc` -s ${MARKDOWN} -H ${HEADER} -f markdown-task_lists --metadata pagetitle="${TITLE}" -o ${HTML};
	fi;
done;

for HTML in ./*.html; do
	HTML="${HTML/_p./}";
	MARKDOWN="${HTML%.*}.md";
	if [ ! -f ${MARKDOWN} ]; then
		echo "Removing ${HTML}";
		rm "${HTML}";
	fi;
done;

gsed -i ./*html -e 's/\.md/.html/g';
