MSYS_NO_PATHCONV=1 docker run -t --rm \
-v "$PWD":/usr/src/app \
-p "80:4000" \
starefossen/github-pages
